import SwiftUI

extension PhraseInfoCard {
    var animationScriptToggle: some View {
        HStack(spacing: 8) {
            scriptButton("简", value: "simplified")
            scriptButton("繁", value: "traditional")

            Spacer(minLength: 0)

            if phraseCharacters.count > 1 {
                Button {
                    showPhraseTableSheet = true
                } label: {
                    PhraseActionPill()
                }
                .buttonStyle(.plain)
                .help("Show phrases containing \(phraseCharacters.joined())")
            }
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
                .background(animationScript == value ? Color.accentColor : Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(animationScript == value ? 0 : 0.45), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
