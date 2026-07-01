import SwiftUI

struct PhoneContextPreview: View {
    @EnvironmentObject private var store: RadixStore
    let returnTitle: String
    let returnSystemImage: String
    let phrase: PhraseItem?
    let character: String?
    let onReturn: () -> Void
    @State private var phraseReturnTarget: PhraseItem?
    @State private var phraseReturnLookupOverride: [PhraseItem]?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            previewNavigationRow

            if let phrase {
                PhraseInfoCard(
                    phrase: phrase,
                    phraseLookupOverride: store.sidebarPhraseLookupOverride,
                    onSelectCharacter: { character in
                        if store.isPracticeSidebarInspectionActive {
                            store.presentPracticeSidebarCharacter(character, in: phrase, announce: false)
                        } else {
                            phraseReturnTarget = phrase
                            store.previewPhraseCardCharacter(character, in: phrase, announce: false)
                        }
                    },
                    onDone: returnFromPreview
                )
                .environmentObject(store)
            } else if let character {
                if let phraseReturnTarget, !store.hasPracticeSidebarReturnTarget {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if let phraseReturnLookupOverride {
                                store.presentPracticeSentenceInSidebar(
                                    phraseReturnTarget,
                                    sentencePhrases: phraseReturnLookupOverride
                                )
                            } else {
                                store.presentPhraseInSidebar(phraseReturnTarget)
                            }
                        }
                    } label: {
                        Label("Phrase", systemImage: "chevron.backward")
                            .font(ResponsiveFont.subheadline.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
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
                    onClear: returnFromPreview
                )
            }
        }
        .onAppear {
            if let phrase {
                phraseReturnTarget = phrase
                phraseReturnLookupOverride = store.sidebarPhraseLookupOverride
            }
        }
        .onChange(of: phrase) { _, newValue in
            if let newValue {
                phraseReturnTarget = newValue
                phraseReturnLookupOverride = store.sidebarPhraseLookupOverride
            }
        }
    }

    private var previewNavigationRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                returnButton
                browseShortcutButton
            }

            VStack(alignment: .leading, spacing: 8) {
                returnButton
                browseShortcutButton
            }
        }
    }

    private var returnButton: some View {
        Button(action: returnFromPreview) {
            Label(returnTitle, systemImage: returnSystemImage)
                .font(ResponsiveFont.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RadixTheme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func returnFromPreview() {
        if store.returnFromPracticeSidebarPreview() {
            return
        }
        onReturn()
    }

    @ViewBuilder
    private var browseShortcutButton: some View {
        if returnTitle != "Browse" {
            Button(action: openCurrentPreviewInBrowse) {
                Label("Browse", systemImage: "square.grid.2x2")
                    .font(ResponsiveFont.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RadixTheme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }

    private func openCurrentPreviewInBrowse() {
        let targetPhrase = phrase ?? phraseReturnTarget
        let targetCharacter = character ?? targetPhrase?.word.first.map(String.init)

        onReturn()
        store.goToBrowse()

        if let targetPhrase {
            store.presentPhraseInSidebar(targetPhrase)
        } else if let targetCharacter {
            store.browsePreview(character: targetCharacter, announce: false)
        }
    }
}
