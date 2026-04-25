import SwiftUI
import PhotosUI
import UIKit

struct CaptureTab: View {
    @EnvironmentObject private var store: RadixStore
    @Environment(\.openURL) private var openURL
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isProcessing = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var gridPage = 0
    @State private var showCamera = false
    @State private var capturePreviewCharacter: String?
    @State private var captureDetailPreviewCharacter: String?

    private var characters: [String] {
        CaptureTextExtractor.uniqueCharacters(in: store.activeCaptureDraft.charactersText)
    }

    private var phraseCandidates: [String] {
        CaptureTextExtractor.uniquePhrases(from: store.activeCaptureDraft.phrasesText.split(separator: "\n").map(String.init))
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
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Color.clear.frame(height: 0).id("captureTop")
                    header

                    #if !targetEnvironment(macCatalyst)
                    if UIDevice.current.userInterfaceIdiom == .phone,
                       let current = captureDetailPreviewCharacter ?? capturePreviewCharacter,
                       store.item(for: current) != nil {
                        standardPhoneCharacterPreview(
                            character: current,
                            selectedCharacter: store.selectedCharacter,
                            onClear: {
                                capturePreviewCharacter = nil
                                captureDetailPreviewCharacter = nil
                                store.previewCharacter = nil
                            }
                        )
                    }
                    #endif

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
                    } else if store.activeCaptureDraft.rawText.isEmpty {
                        emptyState
                    } else {
                        captureResults(scrollToTop: {
                            withAnimation { proxy.scrollTo("captureTop", anchor: .top) }
                        })
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            Task { await loadAndRecognize(item) }
        }
        .sheet(isPresented: $showCamera) {
            CameraCaptureView { image in
                showCamera = false
                Task { await recognize(image) }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Camera")
                    .font(ResponsiveFont.title3.bold())
                Text("Image to Radix results")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    showCamera = true
                } label: {
                    Text("Camera")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing)
            }
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Text("Album")
            }
            .buttonStyle(.bordered)
            .disabled(isProcessing)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Choose an Image",
            systemImage: "camera",
            description: Text("Radix will extract Chinese text using Apple Vision, then let you review the characters and phrases in place.")
        )
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private func captureResults(scrollToTop: @escaping () -> Void) -> some View {
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
                            capturePreviewCharacter = character
                            captureDetailPreviewCharacter = character
                            store.refreshPhrases(for: character)
                        },
                        onSelect: {
                            scrollToTop()
                        }
                    )
                }

                TextEditor(text: $store.activeCaptureDraft.charactersText)
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

                TextEditor(text: $store.activeCaptureDraft.phrasesText)
                    .font(ResponsiveFont.body)
                    .frame(minHeight: 86)
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
            }
        }
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
            Button {
                openNewPhraseInChatGPT(phrase)
            } label: {
                Label("ChatGPT", systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .font(ResponsiveFont.caption2.weight(.semibold))

            Button("Notes") {
                store.openQuickPhraseEditor(word: phrase)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .font(ResponsiveFont.caption2.weight(.semibold))
        }
        .padding(10)
    }

    private func openNewPhraseInChatGPT(_ phrase: String) {
        let prompt = """
        For "\(phrase)", return only three lines:
        line 1: Hanyu Pinyin with tone marks
        line 2: concise English meaning
        line 3: one simple Chinese example sentence using the phrase, followed by pinyin and English translation
        Do not include labels, headings, numbering, bullets, explanations, or any extra words.
        """

        #if canImport(UIKit)
        UIPasteboard.general.string = prompt
        #endif

        if let url = chatGPTURL(prompt: prompt) {
            openURL(url)
        }
    }

    private func chatGPTURL(prompt: String) -> URL? {
        var components = URLComponents(string: "https://chatgpt.com/")
        components?.queryItems = [
            URLQueryItem(name: "q", value: prompt)
        ]
        return components?.url
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
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                throw NSError(domain: "Radix", code: 3002, userInfo: [NSLocalizedDescriptionKey: "The selected image could not be loaded."])
            }
            await recognize(image)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func recognize(_ image: UIImage) async {
        isProcessing = true
        errorMessage = nil
        statusMessage = nil
        defer { isProcessing = false }

        do {
            selectedImage = image
            let text = try await CaptureOCRService().recognizeText(in: image)
            let foundCharacters = CaptureTextExtractor.uniqueCharacters(in: text)
            let foundPhrases = CaptureTextExtractor.uniquePhrases(in: text)
            store.activeCaptureDraft = CaptureDraft(
                rawText: text,
                charactersText: foundCharacters.joined(separator: " "),
                phrasesText: foundPhrases.joined(separator: "\n")
            )
            gridPage = 0
            capturePreviewCharacter = nil
            captureDetailPreviewCharacter = nil
            statusMessage = foundCharacters.isEmpty ? "No Chinese characters found. You can edit the fields manually." : "Review, edit, then save what matters."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

}

private struct CameraCaptureView: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onImage: (UIImage) -> Void
        private let dismiss: DismissAction

        init(onImage: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImage = onImage
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
