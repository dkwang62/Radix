import SwiftUI

extension PhraseInfoCard {
    var animationScriptToggle: some View {
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
