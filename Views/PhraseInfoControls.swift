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
        HStack(spacing: 4) {
            scriptButton("简", value: "simplified")
            scriptButton("繁", value: "traditional")
        }
        .padding(4)
        .background(RadixTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    var phraseLookupButton: some View {
        if phraseCharacters.count > 1 {
            Button {
                showPhraseTableSheet = true
            } label: {
                Label {
                    Text("Phrase")
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

    func scriptButton(_ label: String, value: String) -> some View {
        Button {
            animationScript = value
        } label: {
            Text(label)
                .font(ResponsiveFont.subheadline.weight(.bold))
                .foregroundStyle(animationScript == value ? Color.white : Color.accentColor)
                .frame(minWidth: 42, minHeight: 30)
                .background(animationScript == value ? Color.accentColor : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
