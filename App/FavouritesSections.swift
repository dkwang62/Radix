import SwiftUI

extension FavouritesTab {
    var favouritesScrollContent: some View {
        Group {
            if studyAICleanedPageCollectionID != nil {
                aiCleanedPageStudyScreen
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    if showsStudyPinnedControls {
                        studyPinnedControls
                    }

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
                        ScrollView {
                            studyReviewScrollContent
                                .padding(.horizontal)
                                .padding(.bottom, 20)
                        }
                    }
                }
            }
        }
    }

    var studyPinnedControls: some View {
        VStack(alignment: .leading, spacing: 10) {
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
            ContentUnavailableView(
                "No Practice Sets",
                systemImage: "bubble.left.and.bubble.right",
                description: Text("Conversation practice sets will appear here when they are available.")
            )
            .frame(maxWidth: .infinity, minHeight: 220)
        } else {
            conversationPracticeSection
        }
    }

    var addedPhraseReviewStudyScreen: some View {
        AddedPhraseReviewSheet(isWorkspace: true, showsWorkspaceCloseButton: false) {
            store.refreshAddedPhrases()
        }
        .environmentObject(store)
    }

    var sentenceExamplesStudyScreen: some View {
        VStack(alignment: .leading, spacing: 10) {
            sentenceExamplesControls
                .padding(.horizontal, isPhone ? 4 : 16)
                .padding(.top, isPhone ? 4 : 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: isPhone ? 2 : 8) {
                    if sentenceExampleResultCount == 0 {
                        ContentUnavailableView(
                            "No Sentences",
                            systemImage: RadixGlossaryIcon.systemImage(for: "Sentence"),
                            description: Text("Import page sentences or practice packs to create saved sentences.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 240)
                    } else {
                        ForEach(pagedSentenceExamples) { example in
                            sentenceExampleRow(example)
                        }
                    }
                }
                .padding(.horizontal, isPhone ? 4 : 16)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            refreshSentenceExampleResults()
        }
    }

    @ViewBuilder
    var aiCleanedPageStudyScreen: some View {
        if let context = studyAICleanedPageContext {
            VStack(alignment: .leading, spacing: 10) {
                focusedStudyBackButton(title: "Back to Study") {
                    withAnimation(.snappy(duration: 0.18)) {
                        studyAICleanedPageCollectionID = nil
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                ScrollView {
                    aiCleanedPageContent(context)
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                focusedStudyBackButton(title: "Back to Study") {
                    studyAICleanedPageCollectionID = nil
                }
                .padding(.horizontal)
                .padding(.top, 8)

                ContentUnavailableView(
                    "Page Not Found",
                    systemImage: RadixGlossaryIcon.systemImage(for: RadixTerm.savedPage),
                    description: Text("This saved page is no longer available.")
                )
                .frame(maxWidth: .infinity, minHeight: 260)
            }
        }
    }

    var studyAICleanedPageContext: StudyAICleanedPageContext? {
        guard let studyAICleanedPageCollectionID,
              let collection = store.collection(id: studyAICleanedPageCollectionID)
        else { return nil }
        return StudyAICleanedPageContext(
            collection: collection,
            record: RadixStudyPreferences.aiCleanedPage(for: collection.id)
        )
    }

    func aiCleanedPageContent(_ context: StudyAICleanedPageContext) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            aiCleanedPageHeader(context)

            if let record = context.record {
                aiCleanedPageReader(record, collection: context.collection)
            } else {
                aiCleanedPageEmptyState(context.collection)
            }
        }
        .padding(.top, 8)
    }

    func aiCleanedPageHeader(_ context: StudyAICleanedPageContext) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Extracted Sentences", systemImage: "doc.text.magnifyingglass")
                .font(ResponsiveFont.title3.bold())

            Text(studyGridDisplayText(collectionDisplayName(context.collection)))
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .radixSurface(RadixTheme.secondaryBackground.opacity(0.55))
    }

    func aiCleanedPageReader(_ record: AICleanedPageRecord, collection: CharacterCollection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(studyGridDisplayText(record.cleanedTitle.isEmpty ? collectionDisplayName(collection) : record.cleanedTitle))
                        .font(ResponsiveFont.headline.weight(.semibold))
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    CompactScriptToggle(
                        isTraditional: studyGridUsesTraditionalScript,
                        accessibilityLabel: "Extracted sentences Chinese script",
                        minWidth: 34,
                        height: 28
                    ) {
                        studyGridUsesTraditionalScript.toggle()
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }

                Text("\(record.sentences.count) extracted sentences")
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .radixSurface(RadixTheme.secondaryBackground.opacity(0.48))

            if let englishSummary = record.englishSummary {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Summary")
                        .font(ResponsiveFont.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(englishSummary)
                        .font(ResponsiveFont.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .radixSurface(RadixTheme.secondaryBackground.opacity(0.35))
            }

            let sentenceCount = aiCleanedPageSentenceCount(for: record)
            if sentenceCount > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    practiceSentenceDisplayControls {
                        aiCleanedPageSentenceNavigation(record: record, sentenceCount: sentenceCount)
                    }

                    practiceSentenceList(aiCleanedPageCachedSentenceItems(for: record, sentenceCount: sentenceCount), spacing: 8) { item in
                        aiCleanedPageSentenceRow(item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .radixSurface(RadixTheme.secondaryBackground.opacity(0.35))
                .task(id: aiCleanedPageSentenceCacheTaskID(for: record, sentenceCount: sentenceCount)) {
                    refreshAICleanedPageSentenceCache(for: record, sentenceCount: sentenceCount)
                }
            } else {
                ContentUnavailableView(
                    "No Sentence List",
                    systemImage: RadixGlossaryIcon.systemImage(for: "Sentence"),
                    description: Text("Run Extract Sentences again so Radix can save a paged sentence list for this page.")
                )
                .frame(maxWidth: .infinity, minHeight: 180)
            }

            if !record.repairNotes.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("AI Notes")
                        .font(ResponsiveFont.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(record.repairNotes, id: \.self) { note in
                        Label(studyGridDisplayText(note), systemImage: "checkmark.circle")
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .radixSurface(RadixTheme.secondaryBackground.opacity(0.28))
            }
        }
    }

    func aiCleanedPageSentenceNavigation(record: AICleanedPageRecord, sentenceCount: Int) -> some View {
        practiceSentencePageNavigation(
            label: aiCleanedPageSentencePageLabel(sentenceCount: sentenceCount),
            canMovePrevious: canMoveAICleanedPageSentencePage(by: -1, sentenceCount: sentenceCount),
            canMoveNext: canMoveAICleanedPageSentencePage(by: 1, sentenceCount: sentenceCount)
        ) {
            moveAICleanedPageSentencePage(by: -1, record: record, sentenceCount: sentenceCount)
        } onNext: {
            moveAICleanedPageSentencePage(by: 1, record: record, sentenceCount: sentenceCount)
        }
    }

    func aiCleanedPageSentenceRow(_ item: ConversationPracticeItem) -> some View {
        let isSelected = selectedConversationPracticeItemID == item.id
        return practiceSentenceRow(
            item,
            isSelected: isSelected,
            showsPhoneTrailing: false,
            openAccessibilityLabel: "Open sentence \(studyGridDisplayText(item.simplified))",
            openAccessibilityHint: "Opens the sentence card."
        ) {
            presentConversationPracticePhrase(item)
        } trailing: {
            Button {
                presentConversationPracticePhrase(item)
            } label: {
                Image(systemName: "text.quote")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .foregroundStyle(RadixAccent.primary)
            .accessibilityLabel("Open sentence card")
            .help("Open sentence card")
        }
        .padding(.vertical, 2)
    }

    var aiCleanedPageSentencePageSize: Int {
        conversationPracticePageSize
    }

    func aiCleanedPageSentenceCount(for record: AICleanedPageRecord) -> Int {
        record.sentences.count
    }

    func aiCleanedPageSentencePageCount(sentenceCount: Int) -> Int {
        max(1, Int(ceil(Double(sentenceCount) / Double(aiCleanedPageSentencePageSize))))
    }

    func aiCleanedPageSentenceClampedPageIndex(sentenceCount: Int) -> Int {
        min(max(aiCleanedPageSentencePageIndex, 0), aiCleanedPageSentencePageCount(sentenceCount: sentenceCount) - 1)
    }

    func aiCleanedPageSentencePageLabel(sentenceCount: Int) -> String {
        guard sentenceCount > 0 else { return "0 of 0" }
        let pageIndex = aiCleanedPageSentenceClampedPageIndex(sentenceCount: sentenceCount)
        let startRank = pageIndex * aiCleanedPageSentencePageSize + 1
        let endRank = min(startRank + aiCleanedPageSentencePageSize - 1, sentenceCount)
        return "\(startRank)-\(endRank) of \(sentenceCount)"
    }

    func canMoveAICleanedPageSentencePage(by offset: Int, sentenceCount: Int) -> Bool {
        let nextIndex = aiCleanedPageSentenceClampedPageIndex(sentenceCount: sentenceCount) + offset
        return nextIndex >= 0 && nextIndex < aiCleanedPageSentencePageCount(sentenceCount: sentenceCount)
    }

    func moveAICleanedPageSentencePage(by offset: Int, record: AICleanedPageRecord, sentenceCount: Int) {
        guard canMoveAICleanedPageSentencePage(by: offset, sentenceCount: sentenceCount) else { return }
        withAnimation(.snappy(duration: 0.18)) {
            aiCleanedPageSentencePageIndex = aiCleanedPageSentenceClampedPageIndex(sentenceCount: sentenceCount) + offset
        }
        refreshAICleanedPageSentenceCache(for: record, sentenceCount: sentenceCount)
    }

    func aiCleanedPageCachedSentenceItems(
        for record: AICleanedPageRecord,
        sentenceCount: Int
    ) -> [ConversationPracticeItem] {
        let pageIndex = aiCleanedPageSentenceClampedPageIndex(sentenceCount: sentenceCount)
        let revision = aiCleanedPageRecordRevisionKey(record)
        guard let cache = aiCleanedPageSentencePageCache,
              cache.matches(
                record: record,
                recordRevision: revision,
                pageIndex: pageIndex,
                pageSize: aiCleanedPageSentencePageSize,
                sentenceCount: sentenceCount
              )
        else {
            return []
        }
        return cache.items
    }

    func aiCleanedPageSentenceCacheTaskID(for record: AICleanedPageRecord, sentenceCount: Int) -> String {
        [
            record.sourcePageID.uuidString,
            aiCleanedPageRecordRevisionKey(record),
            "\(aiCleanedPageSentenceClampedPageIndex(sentenceCount: sentenceCount))",
            "\(aiCleanedPageSentencePageSize)",
            "\(sentenceCount)"
        ].joined(separator: "|")
    }

    func refreshAICleanedPageSentenceCache(for record: AICleanedPageRecord, sentenceCount: Int? = nil) {
        let sentenceCount = sentenceCount ?? aiCleanedPageSentenceCount(for: record)
        let pageIndex = aiCleanedPageSentenceClampedPageIndex(sentenceCount: sentenceCount)
        if aiCleanedPageSentencePageIndex != pageIndex {
            aiCleanedPageSentencePageIndex = pageIndex
        }
        let revision = aiCleanedPageRecordRevisionKey(record)
        if let cache = aiCleanedPageSentencePageCache,
           cache.matches(
            record: record,
            recordRevision: revision,
            pageIndex: pageIndex,
            pageSize: aiCleanedPageSentencePageSize,
            sentenceCount: sentenceCount
           ) {
            return
        }
        let items = buildAICleanedPageVisibleSentenceItems(for: record, sentenceCount: sentenceCount, pageIndex: pageIndex)
        aiCleanedPageSentencePageCache = StudyAICleanedSentencePageCache(
            sourcePageID: record.sourcePageID,
            recordRevision: revision,
            pageIndex: pageIndex,
            pageSize: aiCleanedPageSentencePageSize,
            sentenceCount: sentenceCount,
            items: items
        )
    }

    func buildAICleanedPageVisibleSentenceItems(
        for record: AICleanedPageRecord,
        sentenceCount: Int,
        pageIndex: Int
    ) -> [ConversationPracticeItem] {
        let startIndex = pageIndex * aiCleanedPageSentencePageSize
        let sourceSentences = aiCleanedPageVisibleSentences(for: record, startIndex: startIndex)
        let keyedSentences = sourceSentences.enumerated().compactMap { localIndex, sentence -> (rank: Int, sentence: AICleanedPageSentence, key: String)? in
            let key = SentenceExampleRecord.normalizedChineseKey(sentence.chinese)
            guard !key.isEmpty else { return nil }
            return (startIndex + localIndex + 1, sentence, key)
        }
        let storedExamples = RadixStudyPreferences.sentenceExamples(normalizedKeys: keyedSentences.map(\.key))

        return keyedSentences.map { pair in
            let example = storedExamples[pair.key] ??
                aiCleanedPageFallbackSentenceExample(pair.sentence, record: record)
            return ConversationPracticeItem(sentenceExample: example, rank: pair.rank)
        }
    }

    func aiCleanedPageRecordRevisionKey(_ record: AICleanedPageRecord) -> String {
        [
            "\(record.createdAt.timeIntervalSinceReferenceDate)",
            "\(record.sentences.count)",
            "\(record.cleanedChineseText.count)",
            record.sentences.first?.id ?? "",
            record.sentences.last?.id ?? ""
        ].joined(separator: ":")
    }

    func aiCleanedPageVisibleSentences(
        for record: AICleanedPageRecord,
        startIndex: Int
    ) -> [AICleanedPageSentence] {
        let endIndex = startIndex + aiCleanedPageSentencePageSize
        if !record.sentences.isEmpty {
            let safeStart = min(max(0, startIndex), record.sentences.count)
            let safeEnd = min(max(safeStart, endIndex), record.sentences.count)
            return Array(record.sentences[safeStart..<safeEnd])
        }

        return []
    }

    func aiCleanedPageFallbackSentenceExample(
        _ sentence: AICleanedPageSentence,
        record: AICleanedPageRecord
    ) -> SentenceExampleRecord {
        SentenceExampleRecord(
            chinese: sentence.chinese,
            pinyin: sentence.pinyin,
            english: sentence.english,
            sources: [
                SentenceExampleSourceReference(
                    sourceType: .aiCleanedPage,
                    sourceID: record.sourcePageID.uuidString,
                    sourceTitle: record.cleanedTitle.isEmpty ? record.sourceTitle : record.cleanedTitle,
                    sourcePageID: record.sourcePageID,
                    practicePackID: nil,
                    practiceItemID: nil
                )
            ],
            targetCharacters: SentenceExampleRecord.detectChineseCharacters(in: sentence.chinese),
            targetPhrases: sentence.phraseHints,
            detectedCharacters: SentenceExampleRecord.detectChineseCharacters(in: sentence.chinese),
            detectedPhrases: sentence.phraseHints,
            createdAt: record.createdAt,
            tags: ["ai-cleaned-page"]
        )
    }

    func aiCleanedPageEmptyState(_ collection: CharacterCollection) -> some View {
        studyEmptyState(
            title: "No Extracted Sentences Yet",
            message: "Extract sentences to turn the original OCR into complete study text and sentence cards.",
            systemImage: "doc.text.magnifyingglass",
            actionTitle: "Extract Sentences",
            actionSystemImage: "sparkles"
        ) {
            beginStudyAILinkPageTask(collection, taskID: AIResultTaskID.createAICleanedPage)
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

    var sentenceExamplePageSize: Int {
        sentenceExampleSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? practiceSentenceDefaultPageSize : 50
    }

    var canBulkDeleteFilteredSentenceExamples: Bool {
        !isSelectingSentenceExamples
            && !sentenceExampleSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && sentenceExampleResultCount > 0
    }

    var sentenceExampleBulkDeleteMessage: String {
        let query = sentenceExampleSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let count = sentenceExampleResultCount
        let filterDescription = sentenceExampleFilter == .all ? "" : " in \(sentenceExampleFilter.rawValue)"
        return "This will permanently delete \(count) sentence\(count == 1 ? "" : "s") matching \"\(query)\"\(filterDescription). This also removes matching extracted-page sentence entries so they do not reappear later."
    }

    var sentenceExampleBulkDeleteConfirmationTitle: String {
        let count = sentenceExampleResultCount
        return "Delete \(count) Sentence\(count == 1 ? "" : "s")"
    }

    var selectedSentenceExamples: [SentenceExampleRecord] {
        sentenceExamplePageRecords.filter { selectedSentenceExampleIDs.contains($0.id) }
    }

    var selectedSentenceExampleCount: Int {
        selectedSentenceExampleIDs.count
    }

    var sentenceExampleSelectedDeleteConfirmationTitle: String {
        let count = selectedSentenceExampleCount
        return "Delete \(count) Sentence\(count == 1 ? "" : "s")"
    }

    var sentenceExamplePageCount: Int {
        max(1, Int(ceil(Double(sentenceExampleResultCount) / Double(sentenceExamplePageSize))))
    }

    var clampedSentenceExamplePageIndex: Int {
        min(max(sentenceExamplePageIndex, 0), sentenceExamplePageCount - 1)
    }

    var pagedSentenceExamples: [SentenceExampleRecord] {
        sentenceExamplePageRecords
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
        guard sentenceExampleResultCount > 0 else { return "0 of 0" }
        let startRank = clampedSentenceExamplePageIndex * sentenceExamplePageSize + 1
        let endRank = min(startRank + sentenceExamplePageRecords.count - 1, sentenceExampleResultCount)
        return "\(startRank)-\(endRank) of \(sentenceExampleResultCount)"
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
        clearSentenceExampleSelection()
        refreshSentenceExampleResults()
    }

    func resetSentenceExamplePage() {
        sentenceExamplePageIndex = 0
    }

    func resetSentenceExampleResultsContext() {
        resetSentenceExamplePage()
        clearSentenceExampleSelection()
        refreshSentenceExampleResults()
    }

    var sentenceExampleQuery: SentenceExampleQuery {
        SentenceExampleQuery(
            scope: sentenceExampleFilter.queryScope,
            searchText: sentenceExampleSearchText,
            minimumCharacterCount: sentenceExampleMinimumCharacterFilter,
            offset: clampedSentenceExamplePageIndex * sentenceExamplePageSize,
            limit: sentenceExamplePageSize
        )
    }

    var allMatchingSentenceExampleQuery: SentenceExampleQuery {
        SentenceExampleQuery(
            scope: sentenceExampleFilter.queryScope,
            searchText: sentenceExampleSearchText,
            minimumCharacterCount: sentenceExampleMinimumCharacterFilter,
            offset: 0,
            limit: nil
        )
    }

    func refreshSentenceExampleResults() {
        _ = sentenceExampleRevision
        let result = RadixStudyPreferences.querySentenceExamples(sentenceExampleQuery)
        sentenceExampleResultCount = result.totalCount
        sentenceExamplePageRecords = result.records
        let visibleIDs = Set(result.records.map(\.id))
        selectedSentenceExampleIDs = selectedSentenceExampleIDs.intersection(visibleIDs)
        if sentenceExamplePageIndex != clampedSentenceExamplePageIndex {
            sentenceExamplePageIndex = clampedSentenceExamplePageIndex
        }
    }

    func refreshSentenceExamplesAfterMutation(statusMessage: String) {
        sentenceExampleRevision += 1
        sentenceExampleStatusMessage = statusMessage
        loadFavoriteSentences()
        refreshSentenceExampleResults()
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
        RadixStudyPreferences.sentenceExample(example, matchesSearchText: sentenceExampleSearchText)
    }

    func clearFocusedStudySections() {
        focusedStudySection = nil
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
            }

            checkpointActionRow

            latestCheckpointRows
        }
        .radixCard(padding: 10, background: RadixTheme.secondaryBackground.opacity(0.52))
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
                .radixIconButtonSurface(
                    size: 24,
                    background: RadixAccent.primary.opacity(0.1)
                )

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
                .radixIconButtonSurface(
                    size: 28,
                    background: tint.opacity(0.12)
                )

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
