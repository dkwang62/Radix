import SwiftUI

extension FavouritesTab {
    var practiceSentenceDefaultPageSize: Int {
        10
    }

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
        Button {
            conversationPracticeSentenceDisplay.toggle()
        } label: {
            Label(conversationPracticeSentenceDisplay.rawValue, systemImage: conversationPracticeSentenceDisplay.systemImage)
                .font(ResponsiveFont.caption.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .radixPill(
                    horizontal: 9,
                    vertical: 6,
                    background: RadixTheme.secondaryBackground
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(RadixAccent.primary)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel("Sentence language")
        .accessibilityValue(conversationPracticeSentenceDisplay.rawValue)
        .help("Switch between Chinese and English")
    }

    var practiceSentenceModeControls: some View {
        HStack(spacing: 8) {
            studyScriptToggle
            conversationPracticeSentenceDisplayToggle
        }
    }

    @ViewBuilder
    func practiceSentenceDisplayControls<Navigation: View>(
        @ViewBuilder navigation: () -> Navigation
    ) -> some View {
        practiceSentenceControlRow {
            navigation()
        } trailing: {
            practiceSentenceModeControls
        }
        .padding(.bottom, 2)
    }

    func practiceSentenceControlRow<Leading: View, Center: View, Trailing: View>(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder center: () -> Center,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                leading()
                    .fixedSize(horizontal: true, vertical: false)

                Spacer(minLength: 8)

                center()
                    .fixedSize(horizontal: true, vertical: false)

                Spacer(minLength: 8)

                trailing()
                    .fixedSize(horizontal: true, vertical: false)
            }

            HStack(spacing: 8) {
                leading()
                    .fixedSize(horizontal: true, vertical: false)

                Spacer(minLength: 6)

                trailing()
                    .fixedSize(horizontal: true, vertical: false)

                center()
                    .fixedSize(horizontal: true, vertical: false)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    leading()
                        .fixedSize(horizontal: true, vertical: false)

                    Spacer(minLength: 0)

                    trailing()
                        .fixedSize(horizontal: true, vertical: false)
                }

                center()
            }
        }
    }

    func practiceSentenceControlRow<Leading: View, Trailing: View>(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        practiceSentenceControlRow {
            leading()
        } center: {
            EmptyView()
        } trailing: {
            trailing()
        }
    }

    func practiceSentenceList<Row: View>(
        _ items: [ConversationPracticeItem],
        spacing: CGFloat = 4,
        @ViewBuilder row: @escaping (ConversationPracticeItem) -> Row
    ) -> some View {
        LazyVStack(alignment: .leading, spacing: spacing) {
            ForEach(items) { item in
                row(item)
            }
        }
    }

    @ViewBuilder
    func practiceSentenceRow<Trailing: View>(
        _ item: ConversationPracticeItem,
        isSelected: Bool,
        showsPhoneTrailing: Bool = true,
        openAccessibilityLabel: String,
        openAccessibilityHint: String,
        onOpen: @escaping () -> Void,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        if isPhone {
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    onOpen()
                } label: {
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(item.rank)")
                            .font(ResponsiveFont.caption2.weight(.semibold))
                            .foregroundStyle(isSelected ? Color.white : RadixAccent.primary)
                            .frame(width: 26, height: 26)
                            .radixSurface(isSelected ? RadixAccent.primary : RadixAccent.primary.opacity(0.1))

                        conversationPracticeSentenceRowText(item)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(openAccessibilityLabel)
                .accessibilityHint(openAccessibilityHint)

                if showsPhoneTrailing {
                    HStack {
                        Spacer(minLength: 0)
                        trailing()
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .radixSurface(
                conversationPracticeSentenceBackground(isSelected: isSelected),
                border: conversationPracticeSentenceBorderColor(isSelected: isSelected),
                borderWidth: 1.4
            )
        } else {
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
    }

    @ViewBuilder
    func conversationPracticeSentenceRowText(_ item: ConversationPracticeItem) -> some View {
        if isPhone {
            practiceSentencePrimaryText(item)
                .font(ResponsiveFont.subheadline.weight(.semibold))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(2)
        } else {
            VStack(alignment: .leading, spacing: 1) {
                switch conversationPracticeSentenceDisplay {
                case .chinese:
                    practiceSentencePrimaryText(item)
                        .font(ResponsiveFont.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(item.pinyin)
                        .font(ResponsiveFont.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                case .english:
                    practiceSentencePrimaryText(item)
                        .font(ResponsiveFont.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
            }
            .layoutPriority(1)
        }
    }

    func practiceSentencePrimaryText(_ item: ConversationPracticeItem) -> Text {
        switch conversationPracticeSentenceDisplay {
        case .chinese:
            return Text(practiceSentenceDisplayText(item.simplified))
        case .english:
            return Text(item.english)
        }
    }

    func practiceSentenceDisplayText(_ text: String) -> String {
        studyGridUsesTraditionalScript ? store.traditionalText(text) : text
    }

    func conversationPracticeSentenceBackground(isSelected: Bool) -> Color {
        isSelected ? RadixAccent.primary.opacity(0.12) : RadixTheme.background
    }

    func conversationPracticeSentenceBorderColor(isSelected: Bool) -> Color {
        isSelected ? RadixAccent.primary.opacity(0.75) : Color.clear
    }
}
