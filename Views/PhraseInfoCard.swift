import SwiftUI

struct PhraseInfoCard: View {
    @EnvironmentObject private var store: RadixStore
    let phrase: PhraseItem
    var onSelectCharacter: ((String) -> Void)?
    var onDone: (() -> Void)?
    @AppStorage("phraseInfoAnimationScript") private var animationScript = "simplified"
    @State private var isEditingNotes = false
    @State private var editableNotes = ""
    @State private var hasLocalNotes = false
    @State private var editStatus: String?
    @State private var showAddPhraseSheet = false

    private var phraseCharacters: [String] {
        phrase.word.map(String.init).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        phraseContent
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.separator), lineWidth: 1)
            )
            .sheet(isPresented: $showAddPhraseSheet) {
                AddPhraseSheet()
                    .environmentObject(store)
            }
            .onChange(of: phrase.word) { _, _ in
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text(phrase.word)
                    .font(.system(size: 28, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .phraseContextMenu(phrase)

                Spacer(minLength: 0)

                Button {
                    store.togglePhraseFavorite(phrase.word)
                } label: {
                    Image(systemName: store.isPhraseFavorite(phrase.word) ? "star.fill" : "star")
                        .font(ResponsiveFont.body)
                        .foregroundStyle(store.isPhraseFavorite(phrase.word) ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
                .help(store.isPhraseFavorite(phrase.word) ? "Remove from favorites" : "Add to favorites")

                if !isEditingNotes {
                    Button {
                        editableNotes = phrase.notes
                        editStatus = nil
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isEditingNotes = true
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(ResponsiveFont.body)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Edit notes")
                }
            }

            HStack(alignment: .center, spacing: 8) {
                let trimmedPinyin = phrase.pinyin.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedPinyin.isEmpty {
                    Text(trimmedPinyin)
                        .font(ResponsiveFont.headline.weight(.semibold))
                        .foregroundStyle(Color.orange)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: 0)

                if let onDone {
                    Button {
                        onDone()
                    } label: {
                        Text("Done")
                            .font(ResponsiveFont.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(.separator).opacity(0.75), lineWidth: 1)
                    )
                    .accessibilityLabel("Close")
                }
            }

            animationScriptToggle
            animationGrid
            phraseMeaningAndNotes
        }
    }

    private var animationScriptToggle: some View {
        HStack(spacing: 8) {
            scriptButton("简", value: "simplified")
            scriptButton("繁", value: "traditional")

            Spacer(minLength: 0)

            Button {
                showAddPhraseSheet = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus.circle.fill")
                        .font(ResponsiveFont.caption.weight(.bold))
                    Text("Phrase")
                        .font(ResponsiveFont.caption.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add Phrase")
        }
    }

    private func scriptButton(_ label: String, value: String) -> some View {
        Button {
            animationScript = value
        } label: {
            Text(label)
                .font(ResponsiveFont.subheadline.weight(.bold))
                .foregroundStyle(animationScript == value ? Color.white : Color.accentColor)
                .frame(minWidth: 42, minHeight: 30)
                .background(animationScript == value ? Color.accentColor : Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(animationScript == value ? 0 : 0.45), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var animationGrid: some View {
        let characters = Array(phraseCharacters.prefix(12))
        LazyVGrid(columns: phraseGridColumns, spacing: 10) {
            ForEach(Array(characters.enumerated()), id: \.offset) { _, character in
                phraseCharacterTile(character)
            }
        }
    }

    private var phraseGridColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 120), spacing: 10),
            GridItem(.flexible(minimum: 120), spacing: 10)
        ]
    }

    private func phraseCharacterTile(_ character: String) -> some View {
        let animationCharacter = animationCharacter(for: character)
        let strokeText = phraseTileStrokeText(for: animationCharacter)
        return Button {
            selectCharacterFromPhrase(animationCharacter)
        } label: {
            VStack(spacing: 6) {
                StrokeAnimationHeaderLabel(text: strokeText)
                    .frame(maxWidth: .infinity)

                StrokeOrderWebView(
                    character: animationCharacter,
                    reloadToken: StrokeAnimationToken.stable(for: "phrase-card-\(phrase)-\(animationCharacter)"),
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
        .copyCharacterContextMenu(animationCharacter, pinyin: store.item(for: animationCharacter)?.pinyinText)
    }

    private func phraseTileStrokeText(for character: String) -> String {
        guard let strokes = store.item(for: character)?.strokes else { return "" }
        let unit = strokes == 1 ? "stroke" : "strokes"
        return "\(strokes) \(unit)"
    }

    private func animationCharacter(for character: String) -> String {
        let variants = [character] + store.allVariants(for: character).map(\.character)
        let preferred = variants.first { candidate in
            animationScript == "traditional"
                ? store.isTraditional(candidate)
                : store.isSimplified(candidate)
        }
        if let preferred {
            return preferred
        }
        if animationScript == "simplified" {
            let simplified = store.simplifiedText(character).trimmingCharacters(in: .whitespacesAndNewlines)
            if !simplified.isEmpty, store.item(for: simplified) != nil {
                return simplified
            }
        }
        return character
    }

    private func selectCharacterFromPhrase(_ character: String) {
        store.speakCharacter(character)
        if let onSelectCharacter {
            onSelectCharacter(character)
            return
        }

        if store.route == .search && store.homeTab == .filter {
            store.previewPhraseCardCharacter(character, in: phrase, announce: false)
        } else {
            store.preview(character: character, announce: false)
        }
        onDone?()
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
