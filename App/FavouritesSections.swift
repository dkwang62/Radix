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
        focusedStudyBackButton(title: conversationPracticeBackButtonTitle) {
            withAnimation(.snappy(duration: 0.18)) {
                isShowingConversationPractice = false
            }
            if store.rootsReturnContext != nil {
                store.returnFromRoots()
            }
        }
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
                            description: Text("Import page sentences or practice packs to fill the sentence database.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 240)
                    } else {
                        ForEach(pagedSentenceExamples) { example in
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
        focusedStudyBackButton(title: "Back to Study") {
            withAnimation(.snappy(duration: 0.18)) {
                isShowingSentenceExamples = false
            }
        }
    }

    func focusedStudyBackButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: "chevron.left")
                .font(ResponsiveFont.caption.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .radixPill(horizontal: 10, vertical: 7, background: RadixAccent.primary.opacity(0.1))
        }
        .buttonStyle(.plain)
        .foregroundStyle(RadixAccent.primary)
    }

    var sentenceExamplesControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                sentenceExamplePageNavigation
                    .fixedSize(horizontal: true, vertical: false)

                Spacer(minLength: 8)

                practiceSentenceModeControls
            }

            if let message = sentenceExampleStatusMessage {
                Text(message)
                    .font(ResponsiveFont.caption2.weight(.semibold))
                    .foregroundStyle(RadixAccent.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextField("Search sentences", text: $sentenceExampleSearchText)
                .textFieldStyle(.roundedBorder)
                .font(ResponsiveFont.body)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(SentenceExampleStudyFilter.allCases) { filter in
                        Button {
                            sentenceExampleFilter = filter
                            resetSentenceExamplePage()
                        } label: {
                            Label(filter.rawValue, systemImage: filter.systemImage)
                                .font(ResponsiveFont.caption.weight(.semibold))
                                .labelStyle(.titleAndIcon)
                                .radixPill(
                                    horizontal: 9,
                                    vertical: 6,
                                    background: sentenceExampleFilter == filter ? RadixAccent.primary : RadixTheme.secondaryBackground
                                )
                                .foregroundStyle(sentenceExampleFilter == filter ? Color.white : Color.primary.opacity(0.72))
                        }
                        .buttonStyle(.plain)
                        .help(filter.rawValue)
                    }
                }
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: RadixRadius.medium))
        .onChange(of: sentenceExampleSearchText) { _, _ in
            resetSentenceExamplePage()
        }
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

    var sentenceExamplePageSize: Int { 10 }

    var sentenceExamplePageCount: Int {
        max(1, Int(ceil(Double(filteredSentenceExamples.count) / Double(sentenceExamplePageSize))))
    }

    var clampedSentenceExamplePageIndex: Int {
        min(max(sentenceExamplePageIndex, 0), sentenceExamplePageCount - 1)
    }

    var pagedSentenceExamples: [SentenceExampleRecord] {
        let pageIndex = clampedSentenceExamplePageIndex
        let startIndex = pageIndex * sentenceExamplePageSize
        let endIndex = min(startIndex + sentenceExamplePageSize, filteredSentenceExamples.count)
        guard startIndex < endIndex else { return [] }
        return Array(filteredSentenceExamples[startIndex..<endIndex])
    }

    var sentenceExamplePageNavigation: some View {
        practiceSentencePageNavigation(
            label: sentenceExamplePageLabel,
            canMovePrevious: canMoveSentenceExamplePage(by: -1),
            canMoveNext: canMoveSentenceExamplePage(by: 1)
        ) {
            moveSentenceExamplePage(by: -1)
        } onNext: {
            moveSentenceExamplePage(by: 1)
        }
    }

    var sentenceExamplePageLabel: String {
        guard !filteredSentenceExamples.isEmpty else { return "0 of 0" }
        let startRank = clampedSentenceExamplePageIndex * sentenceExamplePageSize + 1
        let endRank = min(startRank + sentenceExamplePageSize - 1, filteredSentenceExamples.count)
        return "\(startRank)-\(endRank) of \(filteredSentenceExamples.count)"
    }

    func canMoveSentenceExamplePage(by offset: Int) -> Bool {
        let nextIndex = clampedSentenceExamplePageIndex + offset
        return nextIndex >= 0 && nextIndex < sentenceExamplePageCount
    }

    func moveSentenceExamplePage(by offset: Int) {
        guard canMoveSentenceExamplePage(by: offset) else { return }
        withAnimation(.snappy(duration: 0.18)) {
            sentenceExamplePageIndex = clampedSentenceExamplePageIndex + offset
        }
    }

    func resetSentenceExamplePage() {
        sentenceExamplePageIndex = 0
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
        return practiceSentenceRow(
            item,
            isSelected: isSelected,
            openAccessibilityLabel: "Open sentence \(studyGridDisplayText(item.simplified))",
            openAccessibilityHint: "Opens the sentence info card."
        ) {
            presentConversationPracticePhrase(item)
        } trailing: {
            sentenceExampleFavoriteButton(example)
            sentenceExampleActions(example)
        }
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

            Divider()

            Button {
                toggleSentenceExampleFavorite(example)
            } label: {
                Label(example.isFavorited ? "Remove Favorite" : "Favorite", systemImage: RadixIcon.saved)
            }

            Button {
                presentSentenceExamplePracticeAgain(example)
            } label: {
                Label("Practice Again", systemImage: "rectangle.stack")
            }

            Button {
                presentSentenceExampleEditor(example)
            } label: {
                Label("Edit", systemImage: "pencil")
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

    func presentSentenceExamplePracticeAgain(_ example: SentenceExampleRecord) {
        guard let library = ConversationPracticeLibrary.sentenceExamplesLibrary(
            from: [example],
            title: "Practice Again"
        ) else { return }
        presentConversationPracticeReview(library)
    }

    func presentSentenceExampleEditor(_ example: SentenceExampleRecord) {
        sentenceExampleEditDraft = SentenceExampleEditDraft(record: example)
    }

    func sentenceExampleSourcePageID(_ example: SentenceExampleRecord) -> UUID? {
        example.sources.first(where: { $0.sourcePageID != nil })?.sourcePageID
    }

    func sentenceExampleSourceLabel(_ example: SentenceExampleRecord) -> String {
        if let title = example.sources.compactMap(\.sourceTitle).first, !title.isEmpty {
            return title
        }
        if example.hasSourceType(.ocrSource) { return "Captured Text" }
        if example.hasSourceType(.sentencePractice) { return "Page Sentences" }
        if example.hasSourceType(.conversationPractice) { return "Conversation Practice" }
        if example.hasSourceType(.favoriteSentence) { return "Favorite Sentence" }
        return "Sentence Example"
    }

    func sentenceExampleSourceIcon(_ example: SentenceExampleRecord) -> String {
        if example.hasSourceType(.ocrSource) { return "doc.text" }
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
                .radixSurface(isSelected ? RadixAccent.primary : Color.clear)
                .accessibilityLabel(control.title)
                .accessibilityValue(isSelected ? "Selected" : "")
                .help(control.title)
            }
        }
        .radixCard(padding: 3, background: RadixTheme.secondaryBackground.opacity(0.55))
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
            .radixSurface(
                fill.opacity(isActive ? 1 : 0.35),
                border: shortcut.isDisabled ? RadixTheme.separator.opacity(0.45) : fill.opacity(0.95)
            )
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
        .radixCard(padding: 10, background: RadixTheme.secondaryBackground.opacity(0.52))
    }

    var backupFilesLink: some View {
        Button(action: onOpenProtectRecover) {
            RadixTermLabel("Backup files", term: RadixTerm.backup)
                .font(ResponsiveFont.caption.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .radixPill(horizontal: 8, vertical: 5, background: RadixAccent.primary.opacity(0.1))
        }
        .buttonStyle(.plain)
        .foregroundStyle(RadixAccent.primary)
    }

    var checkpointActionRow: some View {
        checkpointActionButton(
            title: isCreatingCheckpoint ? "Creating…" : RadixCopy.createCheckpoint,
            subtitle: "Save this moment",
            systemImage: "clock.badge.checkmark",
            tint: RadixAccent.primary,
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
                .radixSurface(RadixTheme.background)
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
                .font(.system(size: RadixIconSize.standard, weight: .semibold))
                .foregroundStyle(RadixAccent.primary)
                .frame(width: 24, height: 24)
                .radixSurface(RadixAccent.primary.opacity(0.1))

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
                .font(.system(size: RadixIconSize.small, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .radixSurface(RadixTheme.background)
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
                .font(.system(size: RadixIconSize.standard, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .radixSurface(tint.opacity(0.12))

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
        .radixSurface(tint.opacity(0.08), border: tint.opacity(0.25))
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

struct SentenceExampleEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let record: SentenceExampleRecord
    let onSave: (SentenceExampleRecord) -> Void

    @State private var chinese: String
    @State private var pinyin: String
    @State private var english: String
    @State private var targetCharacters: String
    @State private var targetPhrases: String
    @State private var tags: String
    @State private var notes: String

    init(record: SentenceExampleRecord, onSave: @escaping (SentenceExampleRecord) -> Void) {
        self.record = record
        self.onSave = onSave
        _chinese = State(initialValue: record.chinese)
        _pinyin = State(initialValue: record.pinyin ?? "")
        _english = State(initialValue: record.english ?? "")
        _targetCharacters = State(initialValue: record.targetCharacters.joined(separator: ", "))
        _targetPhrases = State(initialValue: record.targetPhrases.joined(separator: ", "))
        _tags = State(initialValue: record.tags.joined(separator: ", "))
        _notes = State(initialValue: record.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Sentence") {
                    TextEditor(text: $chinese)
                        .frame(minHeight: 72)
                    TextField("Pinyin", text: $pinyin, axis: .vertical)
                    TextField("English", text: $english, axis: .vertical)
                }

                Section("Learning Hints") {
                    TextField("Characters", text: $targetCharacters, axis: .vertical)
                    TextField("Phrases", text: $targetPhrases, axis: .vertical)
                    TextField("Tags", text: $tags, axis: .vertical)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 82)
                }
            }
            .navigationTitle("Edit Sentence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !trimmed(chinese).isEmpty
    }

    private func save() {
        var updated = record
        updated.chinese = trimmed(chinese)
        updated.pinyin = cleanOptional(pinyin)
        updated.english = cleanOptional(english)
        updated.targetCharacters = splitCharacters(targetCharacters)
        updated.targetPhrases = splitList(targetPhrases)
        updated.detectedCharacters = SentenceExampleRecord.detectChineseCharacters(in: updated.chinese)
        updated.tags = splitList(tags)
        updated.notes = trimmed(notes)
        onSave(updated)
        dismiss()
    }

    private func splitList(_ value: String) -> [String] {
        deduplicated(
            value.split { character in
                character == "," || character == ";" || character.isNewline
            }.map { trimmed(String($0)) }
        )
    }

    private func splitCharacters(_ value: String) -> [String] {
        let hasSeparators = value.contains(",") || value.contains(";") || value.contains { $0.isNewline }
        if hasSeparators {
            return splitList(value)
        }
        return deduplicated(
            value.map(String.init).map(trimmed).filter { !$0.isEmpty }
        )
    }

    private func cleanOptional(_ value: String) -> String? {
        let cleaned = trimmed(value)
        return cleaned.isEmpty ? nil : cleaned
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func deduplicated(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { value in
            guard !value.isEmpty else { return false }
            return seen.insert(value).inserted
        }
    }
}
