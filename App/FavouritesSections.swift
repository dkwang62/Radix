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
            } else if isShowingSentenceExamples {
                sentenceExamplesStudyScreen
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

    var sentenceExamplesStudyScreen: some View {
        VStack(alignment: .leading, spacing: 10) {
            sentenceExamplesBackButton
                .padding(.horizontal)
                .padding(.top, 8)

            sentenceExamplesControls
                .padding(.horizontal)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if filteredSentenceExamples.isEmpty {
                        ContentUnavailableView(
                            "No Sentences",
                            systemImage: RadixGlossaryIcon.systemImage(for: "Sentence"),
                            description: Text("Extract page sentences or import practice to fill the sentence database.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 240)
                    } else {
                        ForEach(filteredSentenceExamples) { example in
                            sentenceExampleRow(example)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
    }

    var sentenceExamplesBackButton: some View {
        Button {
            withAnimation(.snappy(duration: 0.18)) {
                isShowingSentenceExamples = false
            }
        } label: {
            Label("Back to Study", systemImage: "chevron.left")
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

    var sentenceExamplesControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label("\(filteredSentenceExamples.count)/\(allSentenceExamples.count)", systemImage: RadixGlossaryIcon.systemImage(for: "Sentence"))
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                conversationPracticeSentenceDisplayToggle

                if let message = sentenceExampleStatusMessage {
                    Text(message)
                        .font(ResponsiveFont.caption2.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            TextField("Search sentences", text: $sentenceExampleSearchText)
                .textFieldStyle(.roundedBorder)
                .font(ResponsiveFont.body)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(SentenceExampleStudyFilter.allCases) { filter in
                        Button {
                            sentenceExampleFilter = filter
                        } label: {
                            Label(filter.rawValue, systemImage: filter.systemImage)
                                .font(ResponsiveFont.caption.weight(.semibold))
                                .labelStyle(.titleAndIcon)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(sentenceExampleFilter == filter ? Color.accentColor : RadixTheme.secondaryBackground)
                                .foregroundStyle(sentenceExampleFilter == filter ? Color.white : Color.primary.opacity(0.72))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .help(filter.rawValue)
                    }
                }
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    var allSentenceExamples: [SentenceExampleRecord] {
        _ = sentenceExampleRevision
        return SentenceExampleRecord.ranked(RadixStudyPreferences.currentSentenceExamples)
    }

    var filteredSentenceExamples: [SentenceExampleRecord] {
        let filtered = allSentenceExamples.filter { example in
            guard sentenceExampleMatchesFilter(example) else { return false }
            return sentenceExampleMatchesSearch(example)
        }
        return filtered
    }

    func sentenceExampleMatchesFilter(_ example: SentenceExampleRecord) -> Bool {
        switch sentenceExampleFilter {
        case .all:
            return !example.isHidden
        case .favorites:
            return example.isFavorited && !example.isHidden
        case .pageLinked:
            return example.sources.contains { $0.sourcePageID != nil } && !example.isHidden
        case .conversation:
            return (example.hasSourceType(.conversationPractice) || example.hasSourceType(.sentencePractice)) && !example.isHidden
        case .ocr:
            return example.hasSourceType(.ocrSource) && !example.isHidden
        case .hidden:
            return example.isHidden
        }
    }

    func sentenceExampleMatchesSearch(_ example: SentenceExampleRecord) -> Bool {
        let query = sentenceExampleSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        let haystack = [
            example.chinese,
            example.pinyin ?? "",
            example.english ?? "",
            example.sources.compactMap(\.sourceTitle).joined(separator: " "),
            example.tags.joined(separator: " ")
        ]
            .joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return haystack.contains(query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current))
    }

    func sentenceExampleRow(_ example: SentenceExampleRecord) -> some View {
        let item = sentenceExamplePracticeItem(example)
        let isSelected = selectedConversationPracticeItemID == item.id
        return HStack(alignment: .center, spacing: 6) {
            Button {
                presentConversationPracticePhrase(item)
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
            .accessibilityLabel("Open sentence \(studyGridDisplayText(item.simplified))")
            .accessibilityHint("Opens the sentence info card.")

            sentenceExampleFavoriteButton(example)
            sentenceExampleActions(example)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        .background(conversationPracticeSentenceBackground(isSelected: isSelected))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(conversationPracticeSentenceBorder(isSelected: isSelected, cornerRadius: 8))
    }

    func sentenceExamplePracticeItem(_ example: SentenceExampleRecord) -> ConversationPracticeItem {
        let rank = (filteredSentenceExamples.firstIndex(where: { $0.id == example.id }) ?? 0) + 1
        return ConversationPracticeItem(sentenceExample: example, rank: rank)
    }

    func sentenceExampleFavoriteButton(_ example: SentenceExampleRecord) -> some View {
        Button {
            toggleSentenceExampleFavorite(example)
        } label: {
            Image(systemName: example.isFavorited ? "star.fill" : "star")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .foregroundStyle(example.isFavorited ? Color.yellow : .secondary)
        .accessibilityLabel(example.isFavorited ? "Remove favorite sentence" : "Save favorite sentence")
    }

    func sentenceExampleActions(_ example: SentenceExampleRecord) -> some View {
        Menu {
            Button {} label: {
                Label(sentenceExampleSourceLabel(example), systemImage: sentenceExampleSourceIcon(example))
            }
            .disabled(true)

            if example.isHidden {
                Button {} label: {
                    Label("Hidden", systemImage: "eye.slash")
                }
                .disabled(true)
            }

            Divider()

            Button {
                toggleSentenceExampleFavorite(example)
            } label: {
                Label(example.isFavorited ? "Remove Favorite" : "Favorite", systemImage: RadixIcon.saved)
            }

            Button {
                RadixPlatform.copyToPasteboard(example.chinese)
                sentenceExampleStatusMessage = "Copied"
            } label: {
                Label("Copy Chinese", systemImage: RadixIcon.copy)
            }

            if let pageID = sentenceExampleSourcePageID(example),
               store.collection(id: pageID) != nil {
                Button {
                    store.goToBrowseCollection(id: pageID, preservingOrigin: true)
                } label: {
                    Label("Open Source Page", systemImage: RadixGlossaryIcon.systemImage(for: RadixTerm.savedPage))
                }
            }

            Divider()

            Button {
                RadixStudyPreferences.setSentenceExampleHidden(id: example.id, isHidden: !example.isHidden)
                sentenceExampleRevision += 1
                sentenceExampleStatusMessage = example.isHidden ? "Restored" : "Hidden"
            } label: {
                Label(example.isHidden ? "Restore" : "Hide", systemImage: example.isHidden ? "eye" : "eye.slash")
            }

            Button(role: .destructive) {
                RadixStudyPreferences.deleteSentenceExample(id: example.id)
                sentenceExampleRevision += 1
                sentenceExampleStatusMessage = "Deleted"
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(RadixTheme.systemGray5)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .accessibilityLabel("Sentence actions")
    }

    func toggleSentenceExampleFavorite(_ example: SentenceExampleRecord) {
        RadixStudyPreferences.setSentenceExampleFavorite(id: example.id, isFavorited: !example.isFavorited)
        sentenceExampleRevision += 1
        sentenceExampleStatusMessage = example.isFavorited ? "Removed favorite" : "Favorited"
        loadFavoriteSentences()
    }

    func sentenceExampleSourcePageID(_ example: SentenceExampleRecord) -> UUID? {
        example.sources.first(where: { $0.sourcePageID != nil })?.sourcePageID
    }

    func sentenceExampleSourceLabel(_ example: SentenceExampleRecord) -> String {
        if let title = example.sources.compactMap(\.sourceTitle).first, !title.isEmpty {
            return title
        }
        if example.hasSourceType(.ocrSource) { return "OCR" }
        if example.hasSourceType(.sentencePractice) { return "Page Sentences" }
        if example.hasSourceType(.conversationPractice) { return "Conversation Practice" }
        if example.hasSourceType(.favoriteSentence) { return "Favorite Sentence" }
        return "Sentence Example"
    }

    func sentenceExampleSourceIcon(_ example: SentenceExampleRecord) -> String {
        if example.hasSourceType(.ocrSource) { return "doc.text.viewfinder" }
        if example.hasSourceType(.sentencePractice) { return RadixGlossaryIcon.systemImage(for: RadixTerm.savedPage) }
        if example.hasSourceType(.conversationPractice) { return "bubble.left.and.bubble.right" }
        if example.hasSourceType(.favoriteSentence) { return RadixIcon.saved }
        return RadixGlossaryIcon.systemImage(for: "Sentence")
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
            ),
            StudyActionShortcut(
                title: "Sentences",
                systemImage: RadixGlossaryIcon.systemImage(for: "Sentence"),
                fill: .indigo,
                action: {
                    presentSentenceExamples()
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
                Text("\(checkpoints.count)/\(LocalDataSnapshotStore.maximumSnapshotCount)")
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
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
