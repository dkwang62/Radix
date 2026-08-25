import SwiftUI

struct PhoneContextPreview: View {
    @EnvironmentObject private var store: RadixStore
    let phrase: PhraseItem?
    let character: String?
    var listReturnTitle: String? = nil
    let onReturn: () -> Void
    @State private var phraseReturnTarget: PhraseItem?
    @State private var phraseReturnLookupOverride: [PhraseItem]?
    @State private var phraseReturnPracticeItem: ConversationPracticeItem?
    @State private var phraseReturnLookupDepth: PhraseLookupDepth = .topLevel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let listReturnTitle {
                listReturnButton(title: listReturnTitle)
            }

            if let phrase {
                PhraseInfoCard(
                    phrase: phrase,
                    phraseLookupOverride: store.sidebarPhraseLookupOverride,
                    favoriteTarget: store.activePracticeSentenceItem.map(PhraseInfoFavoriteTarget.sentence) ?? .phrase,
                    phraseLookupDepth: store.sidebarPhraseLookupDepth,
                    onSelectCharacter: { character in
                        phraseReturnTarget = phrase
                        phraseReturnPracticeItem = store.activePracticeSentenceItem
                        phraseReturnLookupDepth = store.sidebarPhraseLookupDepth
                        store.previewPhraseCardCharacter(character, in: phrase, announce: false)
                    },
                    onDone: onReturn
                )
                .environmentObject(store)
            } else if let character {
                if let phraseReturnTarget {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if let phraseReturnLookupOverride {
                                store.presentPracticeSentenceInSidebar(
                                    phraseReturnTarget,
                                    sentencePhrases: phraseReturnLookupOverride,
                                    practiceItem: phraseReturnPracticeItem
                                )
                            } else {
                                store.presentPhraseInSidebar(
                                    phraseReturnTarget,
                                    lookupDepth: phraseReturnLookupDepth
                                )
                            }
                        }
                    } label: {
                        Label(phraseReturnLookupOverride == nil ? "Phrase" : "Sentence", systemImage: "chevron.backward")
                            .font(ResponsiveFont.subheadline.weight(.semibold))
                            .foregroundStyle(RadixAccent.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .radixSurface(RadixTheme.secondaryBackground, radius: 10)
                    }
                    .buttonStyle(.plain)
                }

                standardPhoneCharacterPreview(
                    character: character,
                    showAddToMemoryButton: false,
                    onClear: onReturn
                )
            }
        }
        .onAppear {
            if let phrase {
                phraseReturnTarget = phrase
                phraseReturnLookupOverride = store.sidebarPhraseLookupOverride
                phraseReturnPracticeItem = store.activePracticeSentenceItem
                phraseReturnLookupDepth = store.sidebarPhraseLookupDepth
            }
        }
        .onChange(of: phrase) { _, newValue in
            if let newValue {
                phraseReturnTarget = newValue
                phraseReturnLookupOverride = store.sidebarPhraseLookupOverride
                phraseReturnPracticeItem = store.activePracticeSentenceItem
                phraseReturnLookupDepth = store.sidebarPhraseLookupDepth
            }
        }
    }

    func listReturnButton(title: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                onReturn()
            }
        } label: {
            Label("Back to \(title)", systemImage: "chevron.backward")
                .font(ResponsiveFont.subheadline.weight(.semibold))
                .foregroundStyle(RadixAccent.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .radixSurface(RadixTheme.secondaryBackground, radius: 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back to \(title)")
    }
}
