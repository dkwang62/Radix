import SwiftUI

struct AddedPhraseReviewSheet: View {
    @EnvironmentObject var store: RadixStore
    @Environment(\.dismiss) var dismiss
    @State var filter: AddedPhraseReviewFilter = .all
    @State var selectedTool: PhraseReviewStatusTool?
    @State var reviewCycle = PhraseReviewStatusCycleState()
    @State var searchText = ""
    @State var selectedPhrase: PhraseItem?
    @State var pageIndex = 0
    @State var message: String?
    @State var showsFilterPicker = false
    @State var phrasePendingDeletion: PhraseItem?

    let pageSize = 40
    let detailTextMaxWidth: CGFloat = 640

    var addedPhrases: [PhraseItem] {
        store.addedPhrases.filter { $0.word.count >= 2 && !store.isPhraseInBase($0.word) }
    }

    var filteredPhrases: [PhraseItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return addedPhrases
            .filter { filter.includes($0) }
            .filter { phrase in
                guard !query.isEmpty else { return true }
                return phrase.word.localizedCaseInsensitiveContains(query) ||
                    phrase.pinyin.localizedCaseInsensitiveContains(query) ||
                    phrase.meanings.localizedCaseInsensitiveContains(query) ||
                    phrase.notes.localizedCaseInsensitiveContains(query)
            }
            .sorted(by: reviewSort)
    }

    var checkedPhrases: [PhraseItem] {
        addedPhrases.filter { $0.reviewStatus == .checked }
    }

    // Layout guardrails for this sheet:
    // - Keep the filter row, status tool row, Done button, and page controls fully inside the sheet.
    // - Classification is a paint-style flow: choose a status tool, then tap tiles to apply it.
    // - Keep the selected phrase preview compact so the grid stays useful for fast classification.
    // - Default to All so review can begin from the complete set before switching to a status filter.
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 6) {
                topControlRow
                searchField
                toolRow
                promoteCheckedRow
                selectedPhraseDetailCard

                if filteredPhrases.isEmpty {
                    emptyStateView
                } else {
                    phraseGrid
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .padding(.top, 18)
            .frame(idealWidth: 820, maxWidth: 980, minHeight: 680)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                store.refreshAddedPhrases()
            }
            .onChange(of: searchText) { _, _ in
                resetPageAndSelection()
            }
            .alert("Delete Completed Phrase?", isPresented: deleteConfirmationBinding) {
                Button("Delete", role: .destructive) {
                    deletePendingCompletedPhrase()
                }
                Button("Cancel", role: .cancel) {
                    phrasePendingDeletion = nil
                }
            } message: {
                Text(deleteConfirmationMessage)
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
            if filter != .all && filter != .completed {
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
        if phrase.reviewStatus == .completed {
            selectedPhrase = phrase
            message = nil
            return
        }

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
            filter = .all
        } else {
            selectedTool = tool
            reviewCycle.setActiveTool(tool)
            filter = AddedPhraseReviewFilter.filter(for: tool.status)
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

    func completeCheckedPhrases() {
        let phrasesToComplete = checkedPhrases
        guard !phrasesToComplete.isEmpty else { return }

        var completedCount = 0
        for phrase in phrasesToComplete {
            do {
                try store.updateAddedPhraseReviewStatus(word: phrase.word, status: .completed)
                completedCount += 1
            } catch {
                message = "Could not complete \(phrase.word): \(error.localizedDescription)"
                break
            }
        }

        selectedPhrase = nil
        reviewCycle.resetPreview()
        clampPage()
        message = AddedPhraseReviewRules.completionMessage(count: completedCount)
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

    func deletePendingCompletedPhrase() {
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

    func reviewSort(_ lhs: PhraseItem, _ rhs: PhraseItem) -> Bool {
        AddedPhraseReviewRules.reviewSortPredicate(lhs, rhs)
    }
}
