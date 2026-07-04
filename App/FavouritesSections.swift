import SwiftUI

private struct StudySummaryControl: Identifiable {
    let title: String
    let systemImage: String
    let tint: Color
    var isSelected = false
    var isDisabled = false
    let action: () -> Void

    var id: String { title }
}

extension FavouritesTab {
    var favouritesScrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if isShowingConversationPractice {
                    conversationPracticeStudyScreen
                } else {
                    studyMainContent
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
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

    private var studySummaryControls: [StudySummaryControl] {
        var controls = [
            StudySummaryControl(
                title: "Recent",
                systemImage: RadixGlossaryIcon.systemImage(for: RadixTerm.recent),
                tint: .blue,
                isSelected: studyGridScope == .all,
                action: {
                    withAnimation {
                        studyGridScope = .all
                    }
                }
            ),
            StudySummaryControl(
                title: "Favorites",
                systemImage: RadixIcon.saved,
                tint: .yellow,
                isSelected: studyGridScope == .favorites,
                action: {
                    withAnimation {
                        studyGridScope = .favorites
                    }
                }
            ),
            StudySummaryControl(
                title: "Added Phrases",
                systemImage: "text.quote",
                tint: .green,
                action: {
                    presentAddedPhraseReview()
                }
            ),
            StudySummaryControl(
                title: RadixCopy.savedPages,
                systemImage: RadixGlossaryIcon.systemImage(for: RadixTerm.savedPage),
                tint: .purple,
                isSelected: studyGridScope == .savedPages,
                action: {
                    withAnimation {
                        studyGridScope = .savedPages
                    }
                }
            ),
            StudySummaryControl(
                title: "Favorite Sentences",
                systemImage: "star.bubble",
                tint: .orange,
                isDisabled: favoriteSentenceRecords.isEmpty,
                action: {
                    guard !favoriteSentenceRecords.isEmpty else { return }
                    withAnimation(.snappy(duration: 0.18)) {
                        isShowingConversationPractice = true
                    }
                    selectConversationPracticeTopic(.favoriteSentences(count: favoriteSentenceRecords.count))
                }
            ),
            StudySummaryControl(
                title: "Conversation Practices",
                systemImage: "bubble.left.and.bubble.right",
                tint: .teal,
                isSelected: isShowingConversationPractice,
                action: {
                    withAnimation(.snappy(duration: 0.18)) {
                        isShowingConversationPractice = true
                    }
                }
            )
        ]

        if isPhone {
            controls.append(
                StudySummaryControl(
                    title: "Checkpoints",
                    systemImage: "clock.arrow.circlepath",
                    tint: .gray,
                    isSelected: showStudyCheckpoints,
                    action: {
                        showStudyCheckpoints = true
                    }
                )
            )
        }

        return controls
    }

    @ViewBuilder
    var studyDashboardSummary: some View {
        if isNarrowStudyLayout {
            HStack(spacing: 6) {
                ForEach(studySummaryControls) { control in
                    studySummaryIconButton(control)
                }
            }
            .padding(.top, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            LazyVGrid(columns: studySummaryColumns, spacing: 8) {
                ForEach(studySummaryControls) { control in
                    studySummaryLabeledButton(control)
                }
            }
            .padding(.top, 2)
        }
    }

    private var studySummaryColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
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

    private func studySummaryIconButton(
        _ control: StudySummaryControl
    ) -> some View {
        studySummaryIconButton(
            title: control.title,
            systemImage: control.systemImage,
            tint: control.tint,
            isSelected: control.isSelected,
            isDisabled: control.isDisabled,
            action: control.action
        )
    }

    func studySummaryIconButton(
        title: String,
        systemImage: String,
        tint: Color,
        isSelected: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 34)
                .background(tint.opacity(isSelected ? 0.18 : 0.09))
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(tint.opacity(isSelected ? 0.42 : 0.18), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .opacity(isDisabled ? 0.45 : 1)
        .accessibilityLabel(title)
        .help(title)
    }

    private func studySummaryLabeledButton(_ control: StudySummaryControl) -> some View {
        Button(action: control.action) {
            Label {
                Text(control.title)
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } icon: {
                Image(systemName: control.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(control.tint)
            }
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
            .background(control.tint.opacity(control.isSelected ? 0.16 : 0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(control.tint.opacity(control.isSelected ? 0.38 : 0.16), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .opacity(control.isDisabled ? 0.45 : 1)
        .accessibilityLabel(control.title)
        .help(control.title)
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
