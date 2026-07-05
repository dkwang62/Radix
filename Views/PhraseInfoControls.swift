import SwiftUI

extension PhraseInfoCard {
    var practiceSentenceToolbar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                scriptSegment
                phraseLookupButton
                sentenceReadButton
                Spacer(minLength: 0)
                favoriteTargetButton
                if !isEditingNotes {
                    editNotesButton
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    scriptSegment
                    phraseLookupButton
                }

                HStack(spacing: 8) {
                    sentenceReadButton
                    favoriteTargetButton
                    if !isEditingNotes {
                        editNotesButton
                    }
                }
            }
        }
    }

    var sentenceReadButton: some View {
        Button {
            store.readPhraseAloud(phrase)
        } label: {
            Image(systemName: "speaker.wave.2")
                .font(ResponsiveFont.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
                .background(RadixTheme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Read sentence aloud")
        .help("Read sentence aloud")
    }

    var animationScriptToggle: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                scriptSegment
                Spacer(minLength: 0)
                phraseLookupButton
            }

            VStack(alignment: .leading, spacing: 10) {
                scriptSegment
                phraseLookupButton
            }
        }
    }

    var scriptSegment: some View {
        CompactScriptToggle(
            isTraditional: animationScript == "traditional",
            accessibilityLabel: "Phrase animation script",
            minWidth: 42,
            height: 30
        ) {
            animationScript = animationScript == "traditional" ? "simplified" : "traditional"
        }
    }

    @ViewBuilder
    var phraseLookupButton: some View {
        if shouldShowPhraseLookupButton {
            Button {
                showPhraseTableSheet = true
            } label: {
                InfoCardActionPill(title: "Phrase", textIcon: "词", verticalPadding: 8)
            }
            .buttonStyle(.plain)
            .help("Show phrases")
        }
    }

    var shouldShowPhraseLookupButton: Bool {
        if let phraseLookupOverride {
            return !phraseLookupOverride.isEmpty
        }
        return phraseCharacters.count > 1
    }
}
