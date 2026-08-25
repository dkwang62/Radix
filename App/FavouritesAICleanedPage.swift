import SwiftUI

extension FavouritesTab {
    @ViewBuilder
    var aiCleanedPageStudyScreen: some View {
        if let context = studyAICleanedPageContext {
            VStack(alignment: .leading, spacing: 10) {
                focusedStudyBackButton(title: "Back to Study Page") {
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
                focusedStudyBackButton(title: "Back to Study Page") {
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
            "\(aiCleanedPageSentenceTextSignature(record.sentences))",
            record.sentences.first?.id ?? "",
            record.sentences.last?.id ?? ""
        ].joined(separator: ":")
    }

    func aiCleanedPageSentenceTextSignature(_ sentences: [AICleanedPageSentence]) -> Int {
        sentences.reduce(0) { partial, sentence in
            sentence.chinese.unicodeScalars.reduce(partial &* 31 &+ sentence.id.count) {
                ($0 &* 31) &+ Int($1.value)
            }
        }
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
            beginStudyAILinkPageTask(collection, taskID: BuiltInPromptTaskID.extractSentences.rawValue)
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
}
