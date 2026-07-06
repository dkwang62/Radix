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
                    onSelectCharacter: { character in
                        phraseReturnTarget = phrase
                        phraseReturnPracticeItem = store.activePracticeSentenceItem
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
                                store.presentPhraseInSidebar(phraseReturnTarget)
                            }
                        }
                    } label: {
                        Label(phraseReturnLookupOverride == nil ? "Phrase" : "Sentence", systemImage: "chevron.backward")
                            .font(ResponsiveFont.subheadline.weight(.semibold))
                            .foregroundStyle(RadixAccent.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(RadixTheme.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
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
            }
        }
        .onChange(of: phrase) { _, newValue in
            if let newValue {
                phraseReturnTarget = newValue
                phraseReturnLookupOverride = store.sidebarPhraseLookupOverride
                phraseReturnPracticeItem = store.activePracticeSentenceItem
            }
        }
    }

    func listReturnButton(title: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                onReturn()
            }
        } label: {
            Label(title, systemImage: "chevron.backward")
                .font(ResponsiveFont.subheadline.weight(.semibold))
                .foregroundStyle(RadixAccent.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RadixTheme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back to \(title)")
    }
}
