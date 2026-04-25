import SwiftUI
import PhotosUI
import UIKit

struct CaptureTab: View {
    @EnvironmentObject private var store: RadixStore
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var rawText = ""
    @State private var charactersText = ""
    @State private var phrasesText = ""
    @State private var notesText = ""
    @State private var isProcessing = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var gridPage = 0

    private var characters: [String] {
        CaptureTextExtractor.uniqueCharacters(in: charactersText)
    }

    private var phraseCandidates: [String] {
        CaptureTextExtractor.uniquePhrases(from: phrasesText.split(separator: "\n").map(String.init))
    }

    private var characterItems: [ComponentItem] {
        store.items(for: characters)
    }

    private var existingPhrases: [PhraseItem] {
        phraseCandidates.compactMap { store.mergedPhrase(for: $0) }
    }

    private var newPhrases: [String] {
        let existing = Set(existingPhrases.map(\.word))
        return phraseCandidates.filter { !existing.contains($0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header

                if let errorMessage {
                    Text(errorMessage)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.red)
                }
                if let statusMessage {
                    Text(statusMessage)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }

                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if isProcessing {
                    ProgressView("Reading image...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                } else if rawText.isEmpty {
                    emptyState
                } else {
                    captureResults
                    savedCaptures
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .onChange(of: selectedPhoto) { _, item in
            Task { await loadAndRecognize(item) }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Capture")
                    .font(ResponsiveFont.title3.bold())
                Text("Image to Radix notes")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("Choose Image", systemImage: "photo")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isProcessing)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Choose an Image",
            systemImage: "text.viewfinder",
            description: Text("Radix will extract Chinese text using Apple Vision, then let you save only the characters, phrases, and notes you want.")
        )
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private var captureResults: some View {
        VStack(alignment: .leading, spacing: 12) {
            captureSection("Characters") {
                if characterItems.isEmpty {
                    Text("No Chinese characters found yet.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                } else {
                    SmartResultsGrid(
                        items: characterItems,
                        currentPage: $gridPage,
                        onPreview: { character in
                            store.refreshPhrases(for: character)
                        }
                    )
                }

                TextEditor(text: $charactersText)
                    .font(ResponsiveFont.body)
                    .frame(minHeight: 70)
                    .padding(6)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            captureSection("Existing Phrases") {
                if existingPhrases.isEmpty {
                    Text("No existing Radix phrases found from this image.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                } else {
                    phraseTable(existingPhrases)
                }
            }

            captureSection("New Phrases") {
                if newPhrases.isEmpty {
                    Text("No new OCR-only phrase candidates.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(newPhrases, id: \.self) { phrase in
                            newPhraseRow(phrase)
                            Divider()
                        }
                    }
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                TextEditor(text: $phrasesText)
                    .font(ResponsiveFont.body)
                    .frame(minHeight: 86)
                    .padding(6)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            captureSection("Capture Notes") {
                TextEditor(text: $notesText)
                    .font(ResponsiveFont.body)
                    .frame(minHeight: 120)
                    .padding(6)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 10) {
                Button("Remember Characters") {
                    for character in characters {
                        store.pushRootBreadcrumb(character)
                    }
                    statusMessage = "Characters added to Remembered."
                }
                .buttonStyle(.bordered)
                .disabled(characters.isEmpty)

                Spacer()

                Button("Save Capture") {
                    store.saveCapture(rawText: rawText, characters: characters, phrases: phraseCandidates, notes: notesText)
                    statusMessage = "Capture saved."
                }
                .buttonStyle(.borderedProminent)
                .disabled(characters.isEmpty && phraseCandidates.isEmpty && notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var savedCaptures: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Saved Captures")
                .font(ResponsiveFont.headline)
            if store.captureItems.isEmpty {
                Text("Saved captures will appear here.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.captureItems) { item in
                    savedCaptureRow(item)
                }
            }
        }
        .padding(.top, 8)
    }

    private func savedCaptureRow(_ item: CaptureItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button {
                    activateCapture(item)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.createdAt, style: .date)
                            .font(ResponsiveFont.caption.bold())
                        Text("\(item.characters.count) characters, \(item.phrases.count) phrases")
                            .font(ResponsiveFont.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                Button(role: .destructive) {
                    store.deleteCapture(id: item.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

            if !item.characters.isEmpty {
                Text(item.characters.joined(separator: " "))
                    .font(ResponsiveFont.body)
            }
            if !item.phrases.isEmpty {
                Text(item.phrases.joined(separator: "  "))
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }
            if !item.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(item.notes)
                    .font(ResponsiveFont.caption)
                    .lineLimit(3)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func phraseTable(_ phrases: [PhraseItem]) -> some View {
        VStack(spacing: 0) {
            ForEach(phrases, id: \.id) { phrase in
                phraseRow(phrase)
                Divider()
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func phraseRow(_ phrase: PhraseItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(phrase.word)
                    .font(ResponsiveFont.body.bold())
                Text(phrase.pinyin.isEmpty ? "-" : phrase.pinyin)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 120, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(phrase.meanings.isEmpty ? "No meaning" : phrase.meanings)
                    .font(ResponsiveFont.body)
                if !phrase.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(phrase.notes)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .contentShape(Rectangle())
        .phraseContextMenu(phrase)
    }

    private func newPhraseRow(_ phrase: String) -> some View {
        HStack(spacing: 8) {
            Text(phrase)
                .font(ResponsiveFont.body.bold())
            Spacer()
            Button("Add Notes") {
                store.openQuickPhraseEditor(word: phrase)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
        .padding(10)
    }

    private func captureSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(ResponsiveFont.caption.bold())
                .foregroundStyle(.secondary)
            content()
        }
    }

    @MainActor
    private func loadAndRecognize(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isProcessing = true
        errorMessage = nil
        statusMessage = nil
        defer { isProcessing = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                throw NSError(domain: "Radix", code: 3002, userInfo: [NSLocalizedDescriptionKey: "The selected image could not be loaded."])
            }
            selectedImage = image
            let text = try await CaptureOCRService().recognizeText(in: image)
            rawText = text
            let foundCharacters = CaptureTextExtractor.uniqueCharacters(in: text)
            let foundPhrases = CaptureTextExtractor.uniquePhrases(in: text)
            charactersText = foundCharacters.joined(separator: " ")
            phrasesText = foundPhrases.joined(separator: "\n")
            notesText = ""
            gridPage = 0
            statusMessage = foundCharacters.isEmpty ? "No Chinese characters found. You can edit the fields manually." : "Review, edit, then save what matters."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func activateCapture(_ item: CaptureItem) {
        selectedImage = nil
        rawText = item.rawText
        charactersText = item.characters.joined(separator: " ")
        phrasesText = item.phrases.joined(separator: "\n")
        notesText = item.notes
        gridPage = 0
        statusMessage = "Saved capture activated."
        errorMessage = nil
    }
}
