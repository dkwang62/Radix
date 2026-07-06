import SwiftUI

extension FavouritesTab {
    func practiceSentencePageNavigation(
        label: String,
        canMovePrevious: Bool,
        canMoveNext: Bool,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 6) {
            Button(action: onPrevious) {
                RadixCompactChevronLabel(
                    chevronSystemName: "chevron.left",
                    chevronFont: .system(size: RadixIconSize.small, weight: .bold),
                    chevronOpacity: 1,
                    width: 26,
                    height: 26
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(canMovePrevious ? RadixAccent.primary : .secondary)
            .disabled(!canMovePrevious)
            .accessibilityLabel("Previous sentence page")

            Text(label)
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Button(action: onNext) {
                RadixCompactChevronLabel(
                    chevronSystemName: "chevron.right",
                    chevronFont: .system(size: RadixIconSize.small, weight: .bold),
                    chevronOpacity: 1,
                    width: 26,
                    height: 26
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(canMoveNext ? RadixAccent.primary : .secondary)
            .disabled(!canMoveNext)
            .accessibilityLabel("Next sentence page")
        }
    }

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
                        .foregroundStyle(isSelected ? Color.white : RadixAccent.primary)
                        .frame(width: 28, height: 28)
                        .radixSurface(isSelected ? RadixAccent.primary : RadixAccent.primary.opacity(0.1))

                    conversationPracticeSentenceRowText(item)

                    RadixCompactChevronLabel(
                        chevronSystemName: "chevron.right",
                        chevronFont: .system(size: RadixIconSize.small, weight: .semibold),
                        chevronForegroundStyle: isSelected ? RadixAccent.primary : .secondary,
                        chevronOpacity: 1
                    )
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
        .radixSurface(
            conversationPracticeSentenceBackground(isSelected: isSelected),
            border: conversationPracticeSentenceBorderColor(isSelected: isSelected),
            borderWidth: 1.4
        )
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
        isSelected ? RadixAccent.primary.opacity(0.12) : RadixTheme.background
    }

    func conversationPracticeSentenceBorderColor(isSelected: Bool) -> Color {
        isSelected ? RadixAccent.primary.opacity(0.75) : Color.clear
    }
}
