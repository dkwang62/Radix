import SwiftUI

private struct StudyScopeControl: Identifiable {
    let title: String
    let scope: StudyGridScope
    let systemImage: String

    var id: String { scope.id }
}

private struct StudyActionShortcut: Identifiable {
    let title: String
    let systemImage: String
    let fill: Color
    var isSelected = false
    var isDisabled = false
    let action: () -> Void

    var id: String { title }
}

extension FavouritesTab {
    var favouritesScrollContent: some View {
        Group {
            if isShowingConversationPractice {
                ScrollView {
                    conversationPracticeStudyScreen
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                }
            } else if isShowingAddedPhraseReview {
                addedPhraseReviewStudyScreen
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    studyPinnedControls

                    ScrollView {
                        studyReviewScrollContent
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsConversationPracticeFloatingControls,
               let conversationPracticeLibrary {
                conversationPracticeFloatingBottomActions(conversationPracticeLibrary)
            }
        }
    }

    @ViewBuilder
    var studyMainContent: some View {
        studyDashboardSummary

        if hasStudyGridItems {
            recentStudySection
        }
    }

    var studyPinnedControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            studyDashboardSummary
            recentStudyHeader
        }
        .padding(.horizontal)
        .padding(.top, 2)
        .padding(.bottom, 8)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(RadixTheme.separator.opacity(0.72))
                .frame(height: 0.5)
        }
    }

    var studyReviewScrollContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            studyReviewContent
        }
        .padding(.top, 10)
    }

    @ViewBuilder
    var conversationPracticeStudyScreen: some View {
        if conversationPracticeTopics.isEmpty {
            conversationPracticeBackButton
            ContentUnavailableView(
                "No Practice Sets",
                systemImage: "bubble.left.and.bubble.right",
                description: Text("Conversation practice sets will appear here when they are available.")
            )
            .frame(maxWidth: .infinity, minHeight: 220)
        } else {
            conversationPracticeBackButton
            conversationPracticeSection
        }
    }

    var conversationPracticeBackButton: some View {
        Button {
            withAnimation(.snappy(duration: 0.18)) {
                isShowingConversationPractice = false
            }
            if store.rootsReturnContext != nil {
                store.returnFromRoots()
            }
        } label: {
            Label(conversationPracticeBackButtonTitle, systemImage: "chevron.left")
                .font(ResponsiveFont.caption.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
    }

    var conversationPracticeBackButtonTitle: String {
        store.rootsReturnContext == nil ? "Back to Study" : store.rootsReturnButtonTitle
    }

    var addedPhraseReviewStudyScreen: some View {
        AddedPhraseReviewSheet(isWorkspace: true) {
            withAnimation(.snappy(duration: 0.18)) {
                isShowingAddedPhraseReview = false
            }
            store.refreshAddedPhrases()
        }
        .environmentObject(store)
    }

    private var studyScopeControls: [StudyScopeControl] {
        [
            StudyScopeControl(
                title: "Recent",
                scope: .all,
                systemImage: RadixGlossaryIcon.systemImage(for: RadixTerm.recent)
            ),
            StudyScopeControl(
                title: "Favorites",
                scope: .favorites,
                systemImage: RadixIcon.saved
            ),
            StudyScopeControl(
                title: RadixCopy.savedPages,
                scope: .savedPages,
                systemImage: RadixGlossaryIcon.systemImage(for: RadixTerm.savedPage)
            )
        ]
    }

    private var studyActionShortcuts: [StudyActionShortcut] {
        var shortcuts = [
            StudyActionShortcut(
                title: "Added Phrases",
                systemImage: "text.quote",
                fill: .green,
                action: {
                    presentAddedPhraseReview()
                }
            ),
            StudyActionShortcut(
                title: "Conversation Practices",
                systemImage: "bubble.left.and.bubble.right",
                fill: .teal,
                action: {
                    presentConversationPractice()
                }
            )
        ]

        if isPhone {
            shortcuts.append(
                StudyActionShortcut(
                    title: "Checkpoints",
                    systemImage: "clock.arrow.circlepath",
                    fill: .gray,
                    isSelected: showStudyCheckpoints,
                    action: {
                        showStudyCheckpoints = true
                    }
                )
            )
        }

        return shortcuts
    }

    var studyDashboardSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            studyScopeSwitcher

            LazyVGrid(columns: studyActionShortcutColumns, spacing: 8) {
                ForEach(studyActionShortcuts) { shortcut in
                    studyActionShortcutButton(shortcut)
                }
            }
        }
        .padding(.top, 2)
    }

    private var studyScopeSwitcher: some View {
        HStack(spacing: 3) {
            ForEach(studyScopeControls) { control in
                let isSelected = studyGridScope == control.scope
                Button {
                    withAnimation {
                        studyGridScope = control.scope
                    }
                } label: {
                    Label {
                        Text(control.title)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    } icon: {
                        Image(systemName: control.systemImage)
                    }
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .labelStyle(.titleAndIcon)
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .padding(.horizontal, 6)
                }
                .buttonStyle(.plain)
                .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.68))
                .background(isSelected ? Color.accentColor : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel(control.title)
                .accessibilityValue(isSelected ? "Selected" : "")
                .help(control.title)
            }
        }
        .padding(3)
        .background(RadixTheme.secondaryBackground.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var studyActionShortcutColumns: [GridItem] {
        let count = isNarrowStudyLayout ? 2 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: count)
    }

    private func studyActionShortcutButton(_ shortcut: StudyActionShortcut) -> some View {
        let isActive = shortcut.isSelected || !shortcut.isDisabled
        let fill = shortcut.isDisabled ? RadixTheme.systemGray5 : shortcut.fill
        let foreground = shortcut.isDisabled ? Color.secondary : Color.white

        return Button(action: shortcut.action) {
            Label {
                Text(shortcut.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            } icon: {
                Image(systemName: shortcut.systemImage)
            }
            .font(ResponsiveFont.caption.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            .foregroundStyle(foreground)
            .background(fill.opacity(isActive ? 1 : 0.35))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(shortcut.isDisabled ? RadixTheme.separator.opacity(0.45) : fill.opacity(0.95), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .opacity(shortcut.isDisabled ? 0.45 : 1)
        .accessibilityLabel(shortcut.title)
        .help(shortcut.title)
    }

    var studyCheckpointsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label("Checkpoints", systemImage: "clock.arrow.circlepath")
                    .font(ResponsiveFont.headline)
                Spacer()
                backupFilesLink
            }

            checkpointActionRow

            latestCheckpointRows
        }
        .padding(10)
        .background(RadixTheme.secondaryBackground.opacity(0.52))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    var backupFilesLink: some View {
        Button(action: onOpenProtectRecover) {
            RadixTermLabel("Backup files", term: RadixTerm.backup)
                .font(ResponsiveFont.caption.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
    }

    var checkpointActionRow: some View {
        checkpointActionButton(
            title: isCreatingCheckpoint ? "Creating…" : RadixCopy.createCheckpoint,
            subtitle: "Save this moment",
            systemImage: "clock.badge.checkmark",
            tint: Color.accentColor,
            isLocked: entitlement.requiresPro(.datedCopies),
            action: {
                if entitlement.requiresPro(.datedCopies) {
                    onRequirePro(.datedCopies)
                } else {
                    onCreateCheckpoint()
                }
            }
        )
    }

    @ViewBuilder
    var latestCheckpointRows: some View {
        if checkpoints.isEmpty {
            Text("No checkpoints created yet.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RadixTheme.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            ScrollView(.vertical, showsIndicators: checkpoints.count > 3) {
                VStack(spacing: 6) {
                    ForEach(checkpoints) { checkpoint in
                        Button {
                            pendingCheckpointReturn = checkpoint
                        } label: {
                            checkpointListRow(checkpoint)
                        }
                        .buttonStyle(.plain)
                        .disabled(isCreatingCheckpoint || isReturningToCheckpoint)
                    }
                }
            }
            .frame(maxHeight: checkpointListMaxHeight)
        }
    }

    func checkpointListRow(_ checkpoint: LocalDataSnapshot) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, height: 24)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 1) {
                Text(checkpoint.title)
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .lineLimit(1)
                Text("\(checkpoint.relativeSavedText) · \(checkpoint.subtitle)")
                    .font(ResponsiveFont.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RadixTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    func checkpointActionButton(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        isLocked: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            checkpointActionButtonContent(
                title: title,
                subtitle: subtitle,
                systemImage: systemImage,
                tint: tint,
                isLocked: isLocked
            )
        }
        .buttonStyle(.plain)
        .disabled(isCreatingCheckpoint || isReturningToCheckpoint)
    }

    func checkpointActionButtonContent(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        isLocked: Bool
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isLocked ? "lock.fill" : systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(ResponsiveFont.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(ResponsiveFont.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }

    var checkpointListMaxHeight: CGFloat {
        162
    }

    func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(ResponsiveFont.caption.bold())
            .foregroundStyle(.secondary)
    }

    func collectionDisplayName(_ collection: CharacterCollection) -> String {
        let name = collection.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? RadixCopy.savedPage : name
    }
}
