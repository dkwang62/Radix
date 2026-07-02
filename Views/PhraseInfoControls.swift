import SwiftUI

extension PhraseInfoCard {
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
                Label {
                    Text(isPracticeSentence ? "Phrases" : "Phrase")
                } icon: {
                    Text("词")
                        .font(ResponsiveFont.caption.weight(.bold))
                }
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(RadixTheme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(RadixTheme.separator, lineWidth: 0.5)
                )
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
