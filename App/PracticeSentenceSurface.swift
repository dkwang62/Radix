import SwiftUI

extension FavouritesTab {
    var conversationPracticeSentenceDisplayToggle: some View {
        Picker("Sentence Display", selection: $conversationPracticeSentenceDisplay) {
            ForEach(ConversationPracticeSentenceDisplay.allCases) { display in
                Text(display.rawValue).tag(display)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 150)
    }

    var practiceSentenceModeControls: some View {
        HStack(spacing: 8) {
            studyScriptToggle
            conversationPracticeSentenceDisplayToggle
        }
    }

    func practiceSentenceRow<Trailing: View>(
        _ item: ConversationPracticeItem,
        isSelected: Bool,
        openAccessibilityLabel: String,
        openAccessibilityHint: String,
        onOpen: @escaping () -> Void,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Button {
                onOpen()
            } label: {
                HStack(alignment: .center, spacing: 8) {
                    Text("\(item.rank)")
                        .font(ResponsiveFont.caption2.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                        .frame(width: 28, height: 28)
                        .background(isSelected ? Color.accentColor : Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 7))

                    conversationPracticeSentenceRowText(item)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(openAccessibilityLabel)
            .accessibilityHint(openAccessibilityHint)

            trailing()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        .background(conversationPracticeSentenceBackground(isSelected: isSelected))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(conversationPracticeSentenceBorder(isSelected: isSelected, cornerRadius: 8))
    }

    @ViewBuilder
    func conversationPracticeSentenceRowText(_ item: ConversationPracticeItem) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            switch conversationPracticeSentenceDisplay {
            case .chinese:
                Text(studyGridDisplayText(item.simplified))
                    .font(ResponsiveFont.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(item.pinyin)
                    .font(ResponsiveFont.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            case .english:
                Text(item.english)
                    .font(ResponsiveFont.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
        }
        .layoutPriority(1)
    }

    func conversationPracticeSentenceBackground(isSelected: Bool) -> Color {
        isSelected ? Color.accentColor.opacity(0.12) : RadixTheme.background
    }

    func conversationPracticeSentenceBorder(isSelected: Bool, cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(isSelected ? Color.accentColor.opacity(0.75) : Color.clear, lineWidth: 1.4)
    }
}
