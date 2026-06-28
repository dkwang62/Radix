import SwiftUI

struct AddedPhraseReviewSheet: View {
    @EnvironmentObject var store: RadixStore
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State var filter: AddedPhraseReviewFilter = .all
    @State var selectedTool: PhraseReviewStatusTool?
    @State var reviewCycle = PhraseReviewStatusCycleState()
    @State var selectedPhrase: PhraseItem?
    @State var pageIndex = 0
    @State var message: String?
    @State var showsFilterPicker = false
    @State var showsReviewHelp = false
    @State var phrasePendingDeletion: PhraseItem?
    @State var showsDeleteRejectedConfirmation = false
    @State var showsDeleteNewConfirmation = false
    @State var adaptivePageSize: Int?

    let detailTextMaxWidth: CGFloat = 640
    let phraseTileHeight: CGFloat = 34
    let phraseGridSpacing: CGFloat = 5
    let phraseGridVerticalPadding: CGFloat = 4

    var pageSize: Int {
        adaptivePageSize ?? fallbackPageSize
    }

    var fallbackPageSize: Int {
        if RadixPlatform.isPhone { return 30 }
        if RadixPlatform.isDesktop { return 50 }
        return 36
    }

    var usesRegularReviewLayout: Bool {
        !RadixPlatform.isPhone
    }

    var phraseReviewColumnCount: Int {
        if !usesRegularReviewLayout { return 3 }
        return RadixPlatform.isDesktop ? 5 : 4
    }

    var reviewControlFont: Font {
        .system(size: usesRegularReviewLayout ? 15 : 13, weight: .semibold)
    }

    var reviewCaptionFont: Font {
        .system(size: usesRegularReviewLayout ? 14 : 12)
    }

    var addedPhrases: [PhraseItem] {
        store.addedPhrases.filter { $0.word.count >= 2 && !store.isPhraseInBase($0.word) }
    }

    var filteredPhrases: [PhraseItem] {
        AddedPhraseReviewRules.sortedByPinyin(
            addedPhrases.filter { filter.includes($0) }
        )
    }

    var newPhrases: [PhraseItem] {
        addedPhrases.filter { $0.reviewStatus == nil }
    }

    var rejectedPhrases: [PhraseItem] {
        addedPhrases.filter { $0.reviewStatus == .removed }
    }

    // Layout guardrails for this sheet:
    // - Keep the filter row, status tool row, Done button, and page controls fully inside the sheet.
    // - Classification is a paint-style flow: choose a status tool, then tap tiles to apply it.
    // - Keep the selected phrase preview compact so the grid stays useful for fast classification.
    // - Default to All so review can begin from the complete set before switching to a status filter.
    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                VStack(alignment: .leading, spacing: 6) {
                    topControlRow
                    toolRow
                    selectedPhraseDetailCard

                    if filteredPhrases.isEmpty {
                        emptyStateView
                    } else {
                        phraseGrid
                    }
                }
                .padding(.horizontal, usesRegularReviewLayout ? 20 : 12)
                .padding(.bottom, 8)
                .padding(.top, 18)
                .frame(
                    width: proxy.size.width,
                    height: proxy.size.height,
                    alignment: .top
                )
                .toolbar(.hidden, for: .navigationBar)
                .onAppear {
                    store.refreshAddedPhrases()
                }
                .sheet(isPresented: $showsReviewHelp) {
                    AddedPhraseReviewHelpSheet()
                }
                .alert("Delete Phrase?", isPresented: deleteConfirmationBinding) {
                    Button("Delete", role: .destructive) {
                        deletePendingPhrase()
                    }
                    Button("Cancel", role: .cancel) {
                        phrasePendingDeletion = nil
                    }
                } message: {
                    Text(deleteConfirmationMessage)
                }
                .alert("Remove Rejected Phrases?", isPresented: $showsDeleteRejectedConfirmation) {
                    Button("Remove", role: .destructive) {
                        deleteRejectedPhrases()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text(deleteRejectedConfirmationMessage)
                }
                .alert("Remove Unreviewed Phrases?", isPresented: $showsDeleteNewConfirmation) {
                    Button("Remove", role: .destructive) {
                        deleteNewPhrases()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text(deleteNewConfirmationMessage)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

extension AddedPhraseReviewSheet {
    var pageCount: Int {
        max(1, Int(ceil(Double(filteredPhrases.count) / Double(pageSize))))
    }

    var visibleMessage: String? {
        message
    }

    var currentPageIndex: Int {
        min(max(pageIndex, 0), pageCount - 1)
    }

    var pagedPhrases: [PhraseItem] {
        let start = currentPageIndex * pageSize
        guard filteredPhrases.indices.contains(start) else { return [] }
        return Array(filteredPhrases.dropFirst(start).prefix(pageSize))
    }

    var pageRangeLabel: String {
        let count = filteredPhrases.count
        let phraseCount = "\(count) phrase\(count == 1 ? "" : "s")"
        let range = AddedPhraseReviewRules.pinyinRangeLabel(for: pagedPhrases)
        return range.isEmpty ? phraseCount : "\(range) · \(phraseCount)"
    }

    func setStatus(
        _ status: PhraseReviewStatus?,
        for phrase: PhraseItem,
        closeSelection: Bool = false
    ) {
        do {
            try store.updateAddedPhraseReviewStatus(word: phrase.word, status: status)
            let updatedPhrase = store.addedPhrases.first { $0.word == phrase.word } ?? phrase
            selectedPhrase = closeSelection || !filter.includes(updatedPhrase) ? nil : updatedPhrase
            selectedTool = PhraseReviewStatusTool.tool(for: status)
            reviewCycle.setActiveTool(selectedTool)
            if filter != .all {
                filter = AddedPhraseReviewFilter.filter(for: status)
            }
            clampPage()
            message = AddedPhraseReviewRules.statusMessage(status, word: phrase.word)
        } catch {
            message = "Could not update \(phrase.word): \(error.localizedDescription)"
        }
    }

    func applySelectedTool(to phrase: PhraseItem) {
        store.speakPhrase(phrase)

        let action = reviewCycle.action(
            for: store.normalizedPhraseWord(phrase.word),
            currentStatus: phrase.reviewStatus,
            selectedTool: selectedTool
        )

        guard case let .apply(status) = action else {
            selectedPhrase = phrase
            message = nil
            return
        }
        setStatus(status, for: phrase)
    }

    func toggleTool(_ tool: PhraseReviewStatusTool) {
        if selectedTool == tool {
            selectedTool = nil
            reviewCycle.setActiveTool(nil)
        } else {
            selectedTool = tool
            reviewCycle.setActiveTool(tool)
        }
        resetPageAndSelection()
    }

    func resetPageAndSelection() {
        pageIndex = 0
        selectedPhrase = nil
        reviewCycle.resetPreview()
        message = nil
    }

    func clampPage() {
        pageIndex = currentPageIndex
    }

    func previousPage() {
        pageIndex = max(0, currentPageIndex - 1)
    }

    func nextPage() {
        pageIndex = min(pageCount - 1, currentPageIndex + 1)
    }

    func updateAdaptivePageSize(for availableGridHeight: CGFloat) {
        let usableHeight = max(0, availableGridHeight - phraseGridVerticalPadding)
        let rowStride = phraseTileHeight + phraseGridSpacing
        let rows = max(1, Int(floor((usableHeight + phraseGridSpacing) / rowStride)))
        let proposedPageSize = max(phraseReviewColumnCount, rows * phraseReviewColumnCount)

        guard proposedPageSize != adaptivePageSize else { return }

        DispatchQueue.main.async {
            adaptivePageSize = proposedPageSize
            let adjustedPageCount = max(
                1,
                Int(ceil(Double(filteredPhrases.count) / Double(proposedPageSize)))
            )
            pageIndex = min(max(pageIndex, 0), adjustedPageCount - 1)
        }
    }

    func checkNewPhrases() {
        let phrasesToCheck = newPhrases
        guard !phrasesToCheck.isEmpty else { return }

        var checkedCount = 0
        for phrase in phrasesToCheck {
            do {
                try store.updateAddedPhraseReviewStatus(word: phrase.word, status: .checked)
                checkedCount += 1
            } catch {
                message = "Could not accept \(phrase.word): \(error.localizedDescription)"
                break
            }
        }

        selectedPhrase = nil
        reviewCycle.resetPreview()
        clampPage()
        message = "Accepted \(checkedCount) unreviewed phrase\(checkedCount == 1 ? "" : "s")."
    }

    func createAIReviewPage() {
        guard let collection = store.createUnreviewedPhraseReviewCollection() else {
            message = "No unreviewed phrases are available for an AI review page."
            return
        }

        dismiss()
        DispatchQueue.main.async {
            store.goToBrowsePages(selectLatest: false, preservingOrigin: true)
            store.selectBrowseCollection(id: collection.id)
        }
    }

    var deleteNewConfirmationMessage: String {
        let count = newPhrases.count
        return "Delete \(count) unreviewed phrase\(count == 1 ? "" : "s") from your added phrases?"
    }

    func deleteNewPhrases() {
        let phrasesToDelete = newPhrases
        guard !phrasesToDelete.isEmpty else { return }

        do {
            let count = try store.removeAddedPhrases(words: phrasesToDelete.map(\.word))
            selectedPhrase = nil
            resetPageAndSelection()
            message = "Deleted \(count) unreviewed phrase\(count == 1 ? "" : "s")."
        } catch {
            message = "Could not delete unreviewed phrases: \(error.localizedDescription)"
        }
    }

    var deleteRejectedConfirmationMessage: String {
        let count = rejectedPhrases.count
        return "Delete \(count) rejected phrase\(count == 1 ? "" : "s") from your added phrases?"
    }

    func deleteRejectedPhrases() {
        let phrasesToDelete = rejectedPhrases
        guard !phrasesToDelete.isEmpty else { return }

        do {
            let count = try store.removeAddedPhrases(words: phrasesToDelete.map(\.word))
            selectedPhrase = nil
            resetPageAndSelection()
            message = "Deleted \(count) rejected phrase\(count == 1 ? "" : "s")."
        } catch {
            message = "Could not delete rejected phrases: \(error.localizedDescription)"
        }
    }

    var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { phrasePendingDeletion != nil },
            set: { if !$0 { phrasePendingDeletion = nil } }
        )
    }

    var deleteConfirmationMessage: String {
        guard let phrasePendingDeletion else {
            return "This removes the phrase from your added phrases."
        }
        return "Delete \(phrasePendingDeletion.word)? This removes it from your added phrases."
    }

    func deletePendingPhrase() {
        guard let phrase = phrasePendingDeletion else { return }
        phrasePendingDeletion = nil
        do {
            _ = try store.removeAddedPhrases(words: [phrase.word])
            selectedPhrase = nil
            resetPageAndSelection()
            message = "\(phrase.word) deleted."
        } catch {
            message = "Could not delete \(phrase.word): \(error.localizedDescription)"
        }
    }

}
