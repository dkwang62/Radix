import SwiftUI

private func aiTaskMenuTitle(_ task: PromptTask) -> String {
    let trimmedTitle = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
    for separator in [" – ", " - "] {
        let parts = trimmedTitle.components(separatedBy: separator)
        if parts.count > 1,
           parts[0].range(of: "Task ", options: [.anchored, .caseInsensitive]) != nil {
            return parts.dropFirst().joined(separator: separator)
        }
    }
    return trimmedTitle.isEmpty ? "AI Task" : trimmedTitle
}

private struct CopyCharacterContextMenuModifier: ViewModifier {
    @EnvironmentObject private var store: RadixStore
    let character: String
    let pinyin: String?
    let onShowPhrases: (() -> Void)?
    let onAddToHistory: (() -> Void)?

    func body(content: Content) -> some View {
        if character.isSingleChineseCharacter {
            content.contextMenu {
                CharacterActionMenuContent(
                    character: character,
                    pinyin: pinyin,
                    onShowPhrases: onShowPhrases,
                    onAddToHistory: onAddToHistory
                )
            }
        } else {
            content
        }
    }
}

private struct CharacterActionMenuContent: View {
    @EnvironmentObject private var store: RadixStore
    let character: String
    let pinyin: String?
    let onShowPhrases: (() -> Void)?
    let onAddToHistory: (() -> Void)?
    var compact: Bool = false

    private var trimmedPinyin: String? {
        let trimmed = pinyin?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var trimmedMeaning: String? {
        store.meaningText(for: character)
    }

    private var trimmedStructure: String? {
        store.structureText(for: character)
    }

    var body: some View {
        characterActions
    }

    @ViewBuilder
    private var characterActions: some View {
        if let onAddToHistory {
            Button {
                onAddToHistory()
            } label: {
                Label("Add to History", systemImage: RadixGlossaryIcon.systemImage(for: RadixTerm.history))
            }
        }
        Button("Notes") {
            store.openQuickCharacterEditor(character)
        }
        Button {
            if let onShowPhrases {
                onShowPhrases()
            } else {
                showPhraseTable(for: character, using: store)
            }
        } label: {
            Text("词Phrase")
        }
        Button("Components") {
            store.goToRoots(character: character)
        }
        let aiTasks = store.characterPhrasePromptTasks()
        if !aiTasks.isEmpty {
            Menu {
                ForEach(aiTasks) { task in
                    Button {
                        store.goToAILinkCharacterPhraseTask(character, taskID: task.id)
                    } label: {
                        Label(aiTaskMenuTitle(task), systemImage: task.id == store.selectedPromptTaskID ? "checkmark" : RadixIcon.aiLink)
                    }
                }
            } label: {
                Label("AI", systemImage: RadixIcon.aiLink)
            }
        }
        Divider()
        Button("Copy \"\(character)\"") {
            copyToClipboard(character)
        }
        if let trimmedPinyin {
            Button("Copy \"\(trimmedPinyin)\"") {
                copyToClipboard(trimmedPinyin)
            }
        }
        if compact {
            Menu("More") {
                extendedActions
            }
        } else {
            extendedActions
        }
    }

    @ViewBuilder
    private var extendedActions: some View {
        if let trimmedStructure {
            Button("Copy \"\(trimmedStructure)\"") {
                copyToClipboard(trimmedStructure)
            }
        }
        if let trimmedMeaning {
            Button("Copy Meaning") {
                copyToClipboard(trimmedMeaning)
            }
        }
        Divider()
        Button("New Character") {
            store.openNewCharacterEditor()
        }
        if store.addedDictionaryCharacters.contains(character) {
            Button("Delete Character", role: .destructive) {
                store.loadDataEditEntry(for: character)
                try? store.deleteCurrentDataEditEntry()
            }
        } else if store.editedDictionaryCharactersSet.contains(character) {
            Button("Revert Character") {
                store.restoreDictionaryCharacterFromLibrary(character)
            }
        }
        Divider()
        Button(store.isFavorite(character) ? "Remove from Favorites" : "Add to Favorites") {
            store.setFavorite(character: character, isFavorite: !store.isFavorite(character))
        }
    }
}

extension View {
    func copyCharacterContextMenu(
        _ character: String,
        pinyin: String? = nil,
        onShowPhrases: (() -> Void)? = nil,
        onAddToHistory: (() -> Void)? = nil
    ) -> some View {
        modifier(CopyCharacterContextMenuModifier(
            character: character,
            pinyin: pinyin,
            onShowPhrases: onShowPhrases,
            onAddToHistory: onAddToHistory
        ))
    }

    func phraseContextMenu(_ phrase: PhraseItem) -> some View {
        modifier(PhraseContextMenuModifier(phrase: phrase))
    }
}

private struct PhraseContextMenuModifier: ViewModifier {
    @EnvironmentObject private var store: RadixStore
    @State private var deletionError: String?
    let phrase: PhraseItem

    func body(content: Content) -> some View {
        let trimmedWord = phrase.word.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedWord.isEmpty {
            content
        } else {
            content.contextMenu {
                PhraseActionMenuContent(phrase: phrase) {
                    do {
                        try store.removeDataEditPhrase(word: trimmedWord)
                    } catch {
                        deletionError = error.localizedDescription
                    }
                }
            }
            .alert("Delete Failed", isPresented: Binding(
                get: { deletionError != nil },
                set: { if !$0 { deletionError = nil } }
            )) {
                Button("OK") { deletionError = nil }
            } message: {
                Text(deletionError ?? "The phrase could not be deleted.")
            }
        }
    }
}

private struct PhraseActionMenuContent: View {
    @EnvironmentObject private var store: RadixStore
    @Environment(\.dismiss) private var dismiss
    let phrase: PhraseItem
    let onDelete: () -> Void

    private var trimmedWord: String {
        phrase.word.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedPinyin: String? {
        let trimmed = phrase.pinyin.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var trimmedMeaning: String? {
        let trimmed = phrase.meanings.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        phraseActions
    }

    @ViewBuilder
    private var phraseActions: some View {
        Button("Notes") {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                store.openQuickPhraseEditor(word: trimmedWord)
            }
        }
        let aiTasks = store.characterPhrasePromptTasks()
        if !aiTasks.isEmpty {
            Menu {
                ForEach(aiTasks) { task in
                    Button {
                        let taskID = task.id
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            store.goToAILinkCharacterPhraseTask(trimmedWord, taskID: taskID)
                        }
                    } label: {
                        Label(aiTaskMenuTitle(task), systemImage: task.id == store.selectedPromptTaskID ? "checkmark" : RadixIcon.aiLink)
                    }
                }
            } label: {
                Label("AI", systemImage: RadixIcon.aiLink)
            }
        }
        Divider()
        Button("Copy \"\(trimmedWord)\"") {
            copyToClipboard(trimmedWord)
        }
        if let trimmedPinyin {
            Button("Copy \"\(trimmedPinyin)\"") {
                copyToClipboard(trimmedPinyin)
            }
        }
        if let trimmedMeaning {
            Button("Copy Meaning") {
                copyToClipboard(trimmedMeaning)
            }
        }
        Divider()
        let isAdded = store.isPhraseInAdd(trimmedWord)
        let isBuiltIn = store.isPhraseInBase(trimmedWord)
        if isAdded && !isBuiltIn {
            Button("Delete Phrase", role: .destructive) {
                onDelete()
            }
        }
        Divider()
        Button(store.isPhraseFavorite(trimmedWord) ? "Remove from Favorites" : "Add to Favorites") {
            store.togglePhraseFavorite(trimmedWord)
        }
    }
}
