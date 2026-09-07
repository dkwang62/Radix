import SwiftUI

extension FavouritesTab {
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

    func resetSentenceExampleFilters() {
        sentenceExampleFilter = .all
        sentenceExampleSearchText = ""
        sentenceExampleMinimumCharacterCount = 2
        resetSentenceExampleResultsContext()
    }

    var sentenceExampleNoResultsDescription: String {
        let query = sentenceExampleSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var filters: [String] = []
        if sentenceExampleFilter != .all {
            filters.append(sentenceExampleFilter.rawValue)
        }
        if !query.isEmpty {
            filters.append("\"\(query)\"")
        }
        if sentenceExampleMinimumCharacterFilter > 2 {
            filters.append("at least \(sentenceExampleMinimumCharacterFilter) Chinese characters")
        }
        guard !filters.isEmpty else {
            return "No saved sentences match the current filters."
        }
        return "No saved sentences match \(filters.joined(separator: ", "))."
    }

    var sentenceExampleQuery: SentenceExampleQuery {
        SentenceExampleQuery(
            scope: sentenceExampleFilter.queryScope,
            searchText: sentenceExampleSearchText,
            minimumCharacterCount: sentenceExampleMinimumCharacterFilter,
            offset: 0,
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
        let result = RadixStudyPreferences.querySentenceExamplePage(
            sentenceExampleQuery,
            requestedPageIndex: sentenceExamplePageIndex,
            pageSize: sentenceExamplePageSize
        )
        sentenceExamplePageIndex = result.pageIndex
        sentenceExampleResultCount = result.totalCount
        sentenceExampleLibraryCount = RadixStudyPreferences.sentenceExampleCount()
        sentenceExamplePageRecords = result.records
        let visibleIDs = Set(result.records.map(\.id))
        selectedSentenceExampleIDs = selectedSentenceExampleIDs.intersection(visibleIDs)
    }

    func refreshSentenceExamplesAfterMutation(statusMessage: String) {
        sentenceExampleRevision += 1
        sentenceExampleStatusMessage = statusMessage
        loadFavoriteSentences()
        refreshSentenceExampleResults()
    }
}
