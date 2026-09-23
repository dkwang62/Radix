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
            HStack(spacing: 5) {
                Text(conversationPracticeSentenceDisplay.textIcon)
                    .font(ResponsiveFont.caption.weight(.bold))
                Text(conversationPracticeSentenceDisplay.rawValue)
                    .font(ResponsiveFont.caption.weight(.semibold))
            }
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
        Group {
            if isPhone || isNarrowStudyLayout {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        leading()
                            .fixedSize(horizontal: true, vertical: false)

                        Spacer(minLength: 0)

                        trailing()
                            .fixedSize(horizontal: true, vertical: false)
                    }

                    center()
                        .fixedSize(horizontal: false, vertical: false)
                }
            } else {
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
        showsTrailing: Bool = true,
        openAccessibilityLabel: String,
        openAccessibilityHint: String,
        onOpen: @escaping () -> Void,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        practiceSentenceRow(
            item,
            isSelected: isSelected,
            showsPhoneTrailing: showsPhoneTrailing,
            showsTrailing: showsTrailing,
            openAccessibilityLabel: openAccessibilityLabel,
            openAccessibilityHint: openAccessibilityHint,
            onOpen: onOpen,
            trailing: trailing,
            additionalContextMenu: { EmptyView() }
        )
    }

    @ViewBuilder
    func practiceSentenceRow<Trailing: View, AdditionalContextMenu: View>(
        _ item: ConversationPracticeItem,
        isSelected: Bool,
        showsPhoneTrailing: Bool = true,
        showsTrailing: Bool = true,
        openAccessibilityLabel: String,
        openAccessibilityHint: String,
        onOpen: @escaping () -> Void,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder additionalContextMenu: () -> AdditionalContextMenu
    ) -> some View {
        if isPhone {
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    onOpen()
                } label: {
                    HStack(alignment: .top, spacing: 6) {
                        conversationPracticeSentenceRowText(item)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(openAccessibilityLabel)
                .accessibilityHint(openAccessibilityHint)

                if showsPhoneTrailing && showsTrailing {
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
            .contextMenu {
                practiceSentenceAIContextMenu(item)
                additionalContextMenu()
            }
        } else {
            HStack(alignment: .center, spacing: 6) {
                Button {
                    onOpen()
                } label: {
                    HStack(alignment: .center, spacing: 8) {
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

                if showsTrailing {
                    trailing()
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
            .radixSurface(
                conversationPracticeSentenceBackground(isSelected: isSelected),
                border: conversationPracticeSentenceBorderColor(isSelected: isSelected),
                borderWidth: 1.4
            )
            .contextMenu {
                practiceSentenceAIContextMenu(item)
                additionalContextMenu()
            }
        }
    }

    func practiceSentenceAIContextMenu(_ item: ConversationPracticeItem) -> some View {
        SentenceAIContextMenuContent(
            item: item,
            displayChinese: practiceSentenceDisplayText(item.simplified),
            english: item.english,
            isRunningAutomaticAI: isRunningSentenceRowAI,
            onAutomaticExplanation: {
                runAutomaticSentenceRowExplanation(item)
            },
            onAutomaticImprovement: {
                runAutomaticSentenceRowImprovement(item)
            }
        )
    }

    func runAutomaticSentenceRowExplanation(_ item: ConversationPracticeItem) {
        guard store.hasAutomaticAIConfiguration, !isRunningSentenceRowAI else {
            if !store.hasAutomaticAIConfiguration {
                store.goToSettingsForAPIKeySetup()
            }
            return
        }

        isRunningSentenceRowAI = true
        Task { @MainActor in
            defer { isRunningSentenceRowAI = false }
            do {
                let explanation = try await store.runAutomaticSentenceExplanation(for: item)
                store.publishLatestAIResult(
                    taskTitle: "Explain Sentence",
                    subject: item.simplified,
                    body: explanation
                )
                store.showLatestAIResult = true
                RadixHaptics.success()
            } catch {
                sentenceRowAIErrorMessage = error.localizedDescription
                RadixHaptics.error()
            }
        }
    }

    func runAutomaticSentenceRowImprovement(_ item: ConversationPracticeItem) {
        guard store.hasAutomaticAIConfiguration, !isRunningSentenceRowAI else {
            if !store.hasAutomaticAIConfiguration {
                store.goToSettingsForAPIKeySetup()
            }
            return
        }

        isRunningSentenceRowAI = true
        Task { @MainActor in
            defer { isRunningSentenceRowAI = false }
            do {
                _ = try await store.runAutomaticSentenceImprovement(to: item)
                RadixHaptics.success()
            } catch {
                sentenceRowAIErrorMessage = error.localizedDescription
                RadixHaptics.error()
            }
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
            .frame(maxWidth: .infinity, alignment: .leading)
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
        studyGridUsesTraditionalScript ? store.traditionalText(text) : store.simplifiedText(text)
    }

    func conversationPracticeSentenceBackground(isSelected: Bool) -> Color {
        isSelected ? RadixAccent.primary.opacity(0.12) : RadixTheme.background
    }

    func conversationPracticeSentenceBorderColor(isSelected: Bool) -> Color {
        isSelected ? RadixAccent.primary.opacity(0.75) : Color.clear
    }
}
