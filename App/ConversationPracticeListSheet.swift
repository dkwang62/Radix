import SwiftUI

struct ConversationPracticeListPresentation: Identifiable {
    let id = UUID()
    let library: ConversationPracticeLibrary
}

struct ConversationPracticeListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: RadixStore
    let library: ConversationPracticeLibrary
    @Binding var usesTraditionalScript: Bool
    @State private var inspectionPath: [ConversationPracticeInspectionRoute] = []

    var body: some View {
        NavigationStack(path: $inspectionPath) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    scriptPicker
                    ForEach(library.items) { item in
                        sentenceRow(item)
                    }
                }
                .padding()
            }
            .background(RadixTheme.background)
            .navigationTitle(library.set.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(for: ConversationPracticeInspectionRoute.self) { route in
                ConversationPracticeInspectionDestination(
                    route: route,
                    sourceTitle: library.set.title,
                    onOpenCharacter: openCharacter
                )
                .environmentObject(store)
            }
        }
    }

    var scriptPicker: some View {
        Picker("Script", selection: $usesTraditionalScript) {
            Text("Simplified").tag(false)
            Text("Traditional").tag(true)
        }
        .pickerStyle(.segmented)
        .padding(.bottom, 2)
    }

    func sentenceRow(_ item: ConversationPracticeItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                openPhrase(item)
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    Text("\(item.rank)")
                        .font(ResponsiveFont.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 34, height: 34)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayText(item.simplified))
                            .font(ResponsiveFont.body.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(item.pinyin)
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(item.english)
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .layoutPriority(1)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open phrase \(displayText(item.simplified))")

            linkedHintRow(item)
        }
        .padding(12)
        .background(RadixTheme.secondaryBackground.opacity(0.52))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    func linkedHintRow(_ item: ConversationPracticeItem) -> some View {
        let hints = store.linkedPracticeHints(for: item)
        if !hints.phrases.isEmpty || !hints.characters.isEmpty {
            let characters = displayCharacters(for: item, excludingPhrases: hints.phrases)
            if !hints.phrases.isEmpty || !characters.isEmpty {
                RadixTileFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                    ForEach(hints.phrases) { phrase in
                        Button {
                            openPhraseHint(phrase)
                        } label: {
                            Text(displayText(phrase.word))
                                .font(ResponsiveFont.caption.weight(.semibold))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                    }

                    ForEach(characters, id: \.self) { character in
                        Button {
                            openCharacter(character)
                        } label: {
                            Text(character)
                                .font(ResponsiveFont.caption.weight(.semibold))
                                .frame(minWidth: 30, minHeight: 30)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    func openPhrase(_ item: ConversationPracticeItem) {
        let phrase = ConversationPracticeScriptSupport.phraseItem(
            for: item,
            usesTraditionalScript: usesTraditionalScript,
            store: store
        )
        store.pushPhraseBreadcrumb(phrase)
        inspectionPath.append(.phrase(phrase))
    }

    func openPhraseHint(_ phrase: String) {
        guard let phraseItem = store.databasePhrase(for: phrase) else { return }
        openPhraseHint(phraseItem)
    }

    func openPhraseHint(_ phrase: PhraseItem) {
        let displayPhrase = ConversationPracticeScriptSupport.displayPhrase(
            phrase,
            usesTraditionalScript: usesTraditionalScript,
            store: store
        )
        store.pushPhraseBreadcrumb(displayPhrase)
        inspectionPath.append(.phrase(displayPhrase))
    }

    func openCharacter(_ character: String) {
        store.pushRootBreadcrumb(character)
        inspectionPath.append(.character(character))
    }

    func displayText(_ text: String) -> String {
        ConversationPracticeScriptSupport.displayText(
            text,
            usesTraditionalScript: usesTraditionalScript,
            store: store
        )
    }

    func displayCharacters(for item: ConversationPracticeItem, excludingPhrases phrases: [PhraseItem]) -> [String] {
        return ConversationPracticeScriptSupport.displayCharacters(
            for: item,
            excludingPhrases: phrases,
            usesTraditionalScript: usesTraditionalScript,
            store: store
        )
    }
}
