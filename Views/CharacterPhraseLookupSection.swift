import SwiftUI

struct CharacterPhraseLookupSection: View {
    @EnvironmentObject private var store: RadixStore
    @Environment(\.dismiss) private var dismiss
    var onDone: (() -> Void)?
    @State private var selectedPhrase: PhraseItem?

    private let visiblePhraseRows = 6

    private var isRunningOnMac: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        if #available(iOS 14.0, *) {
            return ProcessInfo.processInfo.isiOSAppOnMac
        }
        return false
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("Length", selection: $store.phraseLength) {
                    Text("2-char").tag(2)
                    Text("3-char").tag(3)
                    Text("4-char").tag(4)
                }
                .font(ResponsiveFont.subheadline)
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)
                Spacer()
                Button("Done") {
                    finishLookup()
                }
                .font(ResponsiveFont.subheadline.weight(.semibold))
            }

            copyHintLabel

            if store.phrases.isEmpty {
                Text("No phrases found.")
                    .font(ResponsiveFont.body)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(store.phrases, id: \.id) { phrase in
                                phraseRow(phrase: phrase)
                                Divider()
                            }
                        }
                    }
                    .frame(height: phraseViewportHeight)
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if let selectedPhrase, !isPhone {
                PhraseInfoCard(phrase: selectedPhrase, onDone: finishLookup)
                    .environmentObject(store)
                    .padding(.top, 4)
            }
        }
        .sheet(item: phonePhraseSheetBinding) { phrase in
            NavigationStack {
                PhraseInfoCard(phrase: phrase, onDone: finishLookup)
                    .environmentObject(store)
                    .padding()
                    .navigationTitle(phrase.word)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                finishLookup()
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private var copyHintLabel: some View {
        HStack(spacing: 4) {
            Text(isRunningOnMac ? "Right-click" : "Long-press")
            Image(systemName: "doc.on.doc")
        }
        .font(ResponsiveFont.caption)
        .foregroundStyle(.secondary)
    }

    private func phraseRow(phrase: PhraseItem) -> some View {
        let characterColumnWidth: CGFloat = {
            #if targetEnvironment(macCatalyst)
            return 150
            #else
            return 120
            #endif
        }()

        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(phrase.word)
                    .font(ResponsiveFont.body.bold())
                Text(phrase.pinyin.isEmpty ? "-" : phrase.pinyin)
                    .font(ResponsiveFont.caption)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(.secondary)
            }
            .frame(width: characterColumnWidth, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(phrase.meanings)
                    .font(ResponsiveFont.body)
                if !phrase.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(phrase.notes)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: phraseRowHeight, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            presentPhrase(phrase)
        }
        .phraseContextMenu(phrase)
    }

    private var isPhone: Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        return UIDevice.current.userInterfaceIdiom == .phone
        #endif
    }

    private var phonePhraseSheetBinding: Binding<PhraseItem?> {
        Binding(
            get: { isPhone ? selectedPhrase : nil },
            set: { newValue in
                if isPhone {
                    selectedPhrase = newValue
                }
            }
        )
    }

    private func presentPhrase(_ phrase: PhraseItem) {
        store.speakPhrase(phrase)
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedPhrase = phrase
        }
    }

    private func finishLookup() {
        selectedPhrase = nil
        if let onDone {
            onDone()
        } else {
            dismiss()
        }
    }

    private var phraseRowHeight: CGFloat {
        #if targetEnvironment(macCatalyst)
        return 84
        #else
        return 76
        #endif
    }

    private var phraseViewportHeight: CGFloat {
        (phraseRowHeight * CGFloat(visiblePhraseRows)) + 5
    }
}

struct PhraseInfoCard: View {
    @EnvironmentObject private var store: RadixStore
    let phrase: PhraseItem
    var onSelectCharacter: ((String) -> Void)?
    var onDone: (() -> Void)?
    @State private var drilldownCharacter: String?
    @State private var variantIndex: Int = 0
    @State private var isEditingNotes = false
    @State private var editableNotes = ""
    @State private var hasLocalNotes = false
    @State private var editStatus: String?

    private var phraseCharacters: [String] {
        phrase.word.map(String.init).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var pinyinSyllables: [String] {
        phrase.pinyin
            .replacingOccurrences(of: ",", with: " ")
            .split(whereSeparator: { $0.isWhitespace || $0 == "/" || $0 == ";" })
            .map(String.init)
    }

    var body: some View {
        Group {
            if let drilldownCharacter, let item = store.item(for: drilldownCharacter) {
                characterDrilldown(item)
            } else {
                phraseContent
                    .padding(16)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
            }
        }
        .onChange(of: phrase.word) { _, _ in
            drilldownCharacter = nil
            variantIndex = 0
            editableNotes = phrase.notes
            hasLocalNotes = false
            editStatus = nil
            isEditingNotes = false
        }
        .onAppear {
            if !hasLocalNotes {
                editableNotes = phrase.notes
            }
        }
    }

    private var phraseContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(phrase.word)
                        .font(.system(size: 34, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .phraseContextMenu(phrase)

                    if !phrase.pinyin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(phrase.pinyin)
                            .font(ResponsiveFont.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)

                if let onDone {
                    Button("Done") {
                        onDone()
                    }
                    .font(ResponsiveFont.subheadline.weight(.semibold))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button {
                    store.togglePhraseFavorite(phrase.word)
                } label: {
                    Image(systemName: store.isPhraseFavorite(phrase.word) ? "star.fill" : "star")
                        .foregroundStyle(store.isPhraseFavorite(phrase.word) ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
                .help(store.isPhraseFavorite(phrase.word) ? "Remove from favorites" : "Add to favorites")

                Button {
                    editableNotes = phrase.notes
                    editStatus = nil
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditingNotes.toggle()
                    }
                } label: {
                    Image(systemName: isEditingNotes ? "xmark.circle" : "square.and.pencil")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(isEditingNotes ? "Cancel editing" : "Edit notes")
            }

            animationGrid

            phraseMeaningAndNotes
        }
    }

    @ViewBuilder
    private var animationGrid: some View {
        let characters = Array(phraseCharacters.prefix(4))
        if characters.count == 2 {
            HStack(spacing: 10) {
                ForEach(Array(characters.enumerated()), id: \.offset) { offset, character in
                    phraseCharacterTile(character, pinyin: pinyin(for: character, at: offset))
                }
            }
        } else {
            LazyVGrid(columns: phraseGridColumns, spacing: 10) {
                ForEach(Array(characters.enumerated()), id: \.offset) { offset, character in
                    phraseCharacterTile(character, pinyin: pinyin(for: character, at: offset))
                }
            }
        }
    }

    private var phraseGridColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 120), spacing: 10),
            GridItem(.flexible(minimum: 120), spacing: 10)
        ]
    }

    private func phraseCharacterTile(_ character: String, pinyin: String) -> some View {
        Button {
            store.speakCharacter(character)
            onSelectCharacter?(character)
            withAnimation(.easeInOut(duration: 0.2)) {
                drilldownCharacter = character
                variantIndex = 0
            }
        } label: {
            VStack(spacing: 6) {
                Text(pinyin.isEmpty ? " " : pinyin)
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(Color.orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity)

                StrokeOrderWebView(
                    character: character,
                    reloadToken: UUID(),
                    canvasSize: 110
                )
                .frame(height: 118)
                .frame(maxWidth: .infinity)
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 154)
            .background(Color(.secondarySystemBackground).opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.separator).opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .copyCharacterContextMenu(character, pinyin: store.item(for: character)?.pinyinText)
    }

    private var phraseMeaningAndNotes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(phrase.meanings.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No meaning" : phrase.meanings)
                .font(ResponsiveFont.body)
                .fixedSize(horizontal: false, vertical: true)

            if isEditingNotes {
                TextEditor(text: $editableNotes)
                    .font(ResponsiveFont.body)
                    .frame(minHeight: 96)
                    .padding(6)
                    .background(Color(.secondarySystemBackground).opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack(spacing: 8) {
                    Button("Save Notes") {
                        saveNotes()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button("Cancel") {
                        editableNotes = phrase.notes
                        editStatus = nil
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isEditingNotes = false
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                let noteSource = hasLocalNotes ? editableNotes : phrase.notes
                let trimmedNotes = noteSource.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedNotes.isEmpty {
                    Text(trimmedNotes)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let editStatus {
                Text(editStatus)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func characterDrilldown(_ item: ComponentItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    drilldownCharacter = nil
                    variantIndex = 0
                }
            } label: {
                Label(phrase.word, systemImage: "chevron.backward")
                    .font(ResponsiveFont.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)

            CharacterInfoCard(
                item: item,
                variants: store.allVariants(for: item.character).map(\.character),
                variantIndex: $variantIndex,
                onSelectVariant: { character in
                    store.speakCharacter(character)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        drilldownCharacter = character
                        variantIndex = 0
                    }
                }
            )
        }
    }

    private func pinyin(for character: String, at index: Int) -> String {
        if pinyinSyllables.indices.contains(index) {
            return pinyinSyllables[index]
        }
        return store.item(for: character)?.pinyinText ?? ""
    }

    private func saveNotes() {
        do {
            try store.addCustomPhrase(
                word: phrase.word,
                pinyin: phrase.pinyin,
                meanings: phrase.meanings,
                notes: editableNotes
            )
            hasLocalNotes = true
            editStatus = "Notes saved."
            withAnimation(.easeInOut(duration: 0.2)) {
                isEditingNotes = false
            }
        } catch {
            editStatus = "Save failed: \(error.localizedDescription)"
        }
    }
}

struct PhraseSummaryTile: View {
    let phrase: PhraseItem

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(phrase.word)
                .font(ResponsiveFont.body.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(phrase.pinyin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "-" : phrase.pinyin)
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(Color(.secondarySystemBackground).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.separator).opacity(0.45), lineWidth: 1)
        )
    }
}
