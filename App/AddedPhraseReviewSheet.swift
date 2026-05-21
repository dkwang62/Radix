import SwiftUI

struct AddedPhraseReviewSheet: View {
    @EnvironmentObject private var store: RadixStore
    @Environment(\.dismiss) private var dismiss
    @State private var filter: AddedPhraseReviewFilter = .all
    @State private var selectedTool: PhraseReviewStatusTool?
    @State private var reviewCycle = PhraseReviewStatusCycleState()
    @State private var searchText = ""
    @State private var selectedPhrase: PhraseItem?
    @State private var pageIndex = 0
    @State private var message: String?
    @State private var showsFilterPicker = false
    @State private var phrasePendingDeletion: PhraseItem?

    private let pageSize = 40
    private let detailTextMaxWidth: CGFloat = 640

    private var addedPhrases: [PhraseItem] {
        store.addedPhrases.filter { $0.word.count >= 2 && !store.isPhraseInBase($0.word) }
    }

    private var filteredPhrases: [PhraseItem] {
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

    private var checkedPhrases: [PhraseItem] {
        addedPhrases.filter { $0.reviewStatus == .checked }
    }

    // Layout guardrails for this sheet:
    // - Keep the filter row, status tool row, Done button, and page controls fully inside the sheet.
    //   Past versions clipped "Done", "Clear", and the selected-count text at the left/right edges.
    // - Classification is a paint-style flow: choose a status tool, then tap tiles to apply it.
    // - Keep the selected phrase preview compact. If it becomes too tall, the phrase grid loses the
    //   screen space this workflow needs for fast classification.
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
                    ContentUnavailableView(
                        emptyTitle,
                        systemImage: "text.badge.checkmark",
                        description: Text(emptyDescription)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    phraseGrid
                }
            }
            .padding(8)
            .frame(minWidth: 720, idealWidth: 980, maxWidth: .infinity, minHeight: 680)
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

    private var pageCount: Int {
        max(1, Int(ceil(Double(filteredPhrases.count) / Double(pageSize))))
    }

    private var visibleMessage: String? {
        message
    }

    private var currentPageIndex: Int {
        min(max(pageIndex, 0), pageCount - 1)
    }

    private var pagedPhrases: [PhraseItem] {
        let start = currentPageIndex * pageSize
        guard filteredPhrases.indices.contains(start) else { return [] }
        return Array(filteredPhrases.dropFirst(start).prefix(pageSize))
    }

    private var topControlRow: some View {
        // Keep Done next to the filters, not flush to the far edge, so it remains visible
        // in narrower modal widths and does not repeat the old off-screen Done-button bug.
        HStack(spacing: 6) {
            Spacer(minLength: 0)

            filterRow

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

            Spacer(minLength: 0)
        }
    }

    private var filterRow: some View {
        HStack(spacing: 8) {
            Text("Filter")
                .font(ResponsiveFont.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Button {
                showsFilterPicker.toggle()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: filter.icon)
                        .symbolRenderingMode(.hierarchical)
                    Text(filter.title)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .opacity(0.75)
                }
                .font(ResponsiveFont.caption2.weight(.semibold))
                .lineLimit(1)
                .frame(minWidth: 112)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(filter.color)
            .foregroundStyle(Color.white)
            .popover(isPresented: $showsFilterPicker, arrowEdge: .top) {
                filterPickerPopover
            }
        }
    }

    private var filterPickerPopover: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(AddedPhraseReviewFilter.menuCases) { option in
                Button {
                    filter = option
                    selectedTool = option.tool
                    reviewCycle.setActiveTool(selectedTool)
                    resetPageAndSelection()
                    showsFilterPicker = false
                } label: {
                    HStack(spacing: 12) {
                        filterPill(for: option)

                        Text(option.title)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Group {
                            if filter == option {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(option.color)
                            }
                        }
                        .frame(width: 18)
                    }
                    .font(ResponsiveFont.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .frame(width: 260)
        .presentationCompactAdaptation(.popover)
    }

    private func filterPill(for option: AddedPhraseReviewFilter) -> some View {
        ZStack {
            Capsule()
                .fill(option.color)

            Image(systemName: option.icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 48, height: 24)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var toolRow: some View {
        if filter != .completed {
            HStack(spacing: 4) {
                ForEach(PhraseReviewStatusTool.allCases) { option in
                    Button {
                        toggleTool(option)
                    } label: {
                        Image(systemName: option.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 34, height: 24)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(selectedTool == option ? option.color : Color(.systemGray5))
                    .foregroundStyle(selectedTool == option ? Color.white : Color.primary)
                    .accessibilityLabel("Mark as \(option.title)")
                    .help("Mark as \(option.title)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var promoteCheckedRow: some View {
        HStack(spacing: 8) {
            if filter != .completed, !checkedPhrases.isEmpty {
                Button {
                    completeCheckedPhrases()
                } label: {
                    Label("Complete Checked (\(checkedPhrases.count))", systemImage: "checkmark.seal.fill")
                        .font(ResponsiveFont.caption2.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(Color.accentColor)
                .help("Move checked phrases out of the review pool. Completed phrases can only be deleted from their detail card.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search added phrases", text: $searchText)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var phraseGrid: some View {
        VStack(spacing: 6) {
            phrasePageGrid
            pageFooter
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var phrasePageGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(112), spacing: 4, alignment: .center), count: 4),
            alignment: .center,
            spacing: 4
        ) {
            ForEach(pagedPhrases) { phrase in
                AddedPhraseReviewTile(
                    phrase: phrase,
                    isSelected: selectedPhrase?.word == phrase.word,
                    onSelect: { applySelectedTool(to: phrase) },
                    onMarkNew: { setStatus(nil, for: phrase) },
                    onCheck: { setStatus(.checked, for: phrase) },
                    onHide: { setStatus(.hidden, for: phrase) },
                    onReject: { setStatus(.removed, for: phrase) },
                    showsStatusActions: phrase.reviewStatus != .completed
                )
            }
        }
        .padding(.vertical, 2)
        .frame(width: 460, alignment: .center)
    }

    private var pageFooter: some View {
        HStack(spacing: 10) {
            pageButton(systemImage: "chevron.left", action: previousPage, isEnabled: currentPageIndex > 0)

            Text("Page \(currentPageIndex + 1) of \(pageCount) · \(filteredPhrases.count) phrases")
                .font(ResponsiveFont.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(minWidth: 150)

            pageButton(systemImage: "chevron.right", action: nextPage, isEnabled: currentPageIndex < pageCount - 1)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func pageButton(systemImage: String, action: @escaping () -> Void, isEnabled: Bool) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 30, height: 24)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.25)
        .accessibilityLabel(systemImage.contains("left") ? "Previous page" : "Next page")
    }

    private var selectedPhraseDetailCard: some View {
        // This preview explains the selected tile, but the grid is the main work area.
        // Keep this card compact and centered so it does not push the phrase page down.
        VStack(alignment: .leading, spacing: 8) {
            if let phrase = selectedPhrase {
                phraseDetails(phrase)
            } else {
                PhraseReviewStatusCycleHint()
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if selectedPhrase == nil, selectedTool == nil {
                Text("No status selected. Showing all phrases.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if let visibleMessage {
                Text(visibleMessage)
                    .font(ResponsiveFont.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground).opacity(0.55))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func phraseDetails(_ phrase: PhraseItem) -> some View {
        VStack(alignment: .center, spacing: 2) {
            HStack(spacing: 8) {
                Text(phrase.word)
                    .font(ResponsiveFont.title3.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)

                Label(reviewDetail(for: phrase), systemImage: statusIcon(for: phrase.reviewStatus))
                    .font(ResponsiveFont.caption2.weight(.semibold))
                    .foregroundStyle(statusColor(for: phrase.reviewStatus))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Text(phrase.pinyin.isEmpty ? "No pinyin yet" : phrase.pinyin)
                .font(ResponsiveFont.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .multilineTextAlignment(.center)
                .frame(maxWidth: detailTextMaxWidth, alignment: .center)

            Text(phrase.meanings.isEmpty ? "No meaning yet" : phrase.meanings)
                .font(ResponsiveFont.caption)
                .foregroundStyle(phrase.meanings.isEmpty ? Color.secondary : Color.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .truncationMode(.tail)
                .frame(maxWidth: detailTextMaxWidth, alignment: .center)

            if phrase.reviewStatus == .completed {
                Button(role: .destructive) {
                    phrasePendingDeletion = phrase
                } label: {
                    Label("Delete Phrase", systemImage: RadixIcon.delete)
                        .font(ResponsiveFont.caption2.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func reviewDetail(for phrase: PhraseItem) -> String {
        phrase.reviewStatus?.title ?? "New"
    }

    private func statusIcon(for status: PhraseReviewStatus?) -> String {
        switch status {
        case .checked: return "checkmark.circle.fill"
        case .hidden: return "eye.slash.fill"
        case .removed: return "xmark.circle.fill"
        case .completed: return "checkmark.seal.fill"
        case nil: return "sparkle"
        }
    }

    private func statusColor(for status: PhraseReviewStatus?) -> Color {
        switch status {
        case .checked: return Color.accentColor
        case .hidden: return Color.orange
        case .removed: return Color.red
        case .completed: return Color.purple
        case nil: return Color.secondary
        }
    }

    private var emptyTitle: String {
        switch filter {
        case .new: return "No new phrases"
        case .checked: return "No checked phrases"
        case .hidden: return "No hidden phrases"
        case .removed: return "No rejected phrases"
        case .completed: return "No completed phrases"
        case .all: return "No active added phrases"
        }
    }

    private var emptyDescription: String {
        switch filter {
        case .new: return "New means not checked, hidden, or rejected."
        case .checked: return "Checked phrases stay in review until you complete them."
        case .hidden: return "Hidden phrases stay useful on pages but stay out of the phrase library."
        case .removed: return "Rejected phrases are remembered as not-a-phrase groupings. Mark one New if you want to restore it."
        case .completed: return "Completed phrases are finished. Open one here if you need to delete it."
        case .all: return "Active added phrases with two or more characters appear here. Completed phrases have their own filter."
        }
    }

    private func setStatus(
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
            message = statusMessage(status, phrase: phrase)
        } catch {
            message = "Could not update \(phrase.word): \(error.localizedDescription)"
        }
    }

    private func applySelectedTool(to phrase: PhraseItem) {
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

    private func toggleTool(_ tool: PhraseReviewStatusTool) {
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

    private func resetPageAndSelection() {
        pageIndex = 0
        selectedPhrase = nil
        reviewCycle.resetPreview()
        message = nil
    }

    private func clampPage() {
        pageIndex = currentPageIndex
    }

    private func previousPage() {
        pageIndex = max(0, currentPageIndex - 1)
    }

    private func nextPage() {
        pageIndex = min(pageCount - 1, currentPageIndex + 1)
    }

    private func statusMessage(_ status: PhraseReviewStatus?, phrase: PhraseItem) -> String {
        switch status {
        case .checked: return "\(phrase.word) checked."
        case .hidden: return "\(phrase.word) hidden from phrase lists, still available on pages."
        case .removed: return "\(phrase.word) rejected as not a phrase."
        case .completed: return "\(phrase.word) completed."
        case nil: return "\(phrase.word) restored to New."
        }
    }

    private func completeCheckedPhrases() {
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
        if completedCount > 0 {
            message = "Completed \(completedCount) checked phrase\(completedCount == 1 ? "" : "s")."
        }
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { phrasePendingDeletion != nil },
            set: { if !$0 { phrasePendingDeletion = nil } }
        )
    }

    private var deleteConfirmationMessage: String {
        guard let phrasePendingDeletion else {
            return "This removes the phrase from your added phrases."
        }
        return "Delete \(phrasePendingDeletion.word)? This removes it from your added phrases."
    }

    private func deletePendingCompletedPhrase() {
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

    private func reviewSort(_ lhs: PhraseItem, _ rhs: PhraseItem) -> Bool {
        if lhs.word.count != rhs.word.count { return lhs.word.count < rhs.word.count }
        let leftKey = BackupPreviewSort.key(primary: lhs.pinyin, fallback: lhs.word)
        let rightKey = BackupPreviewSort.key(primary: rhs.pinyin, fallback: rhs.word)
        let pinyinOrder = leftKey.localizedStandardCompare(rightKey)
        if pinyinOrder != .orderedSame { return pinyinOrder == .orderedAscending }

        let lhsDate = lhs.lastReviewedAt ?? lhs.addedAt ?? .distantPast
        let rhsDate = rhs.lastReviewedAt ?? rhs.addedAt ?? .distantPast
        return lhsDate > rhsDate
    }

}

private struct AddedPhraseReviewTile: View {
    let phrase: PhraseItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onMarkNew: () -> Void
    let onCheck: () -> Void
    let onHide: () -> Void
    let onReject: () -> Void
    let showsStatusActions: Bool

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .topTrailing) {
                Text(phrase.word)
                    .font(ResponsiveFont.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .padding(.horizontal, 5)

                Image(systemName: statusIcon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(statusColor)
                    .padding(3)
            }
            .background(tileFill)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(tileStroke, lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if showsStatusActions {
                if phrase.reviewStatus != nil {
                    Button("New", action: onMarkNew)
                }
                Button("Checked", action: onCheck)
                    .disabled(phrase.reviewStatus == .checked)
                Button("Hide", action: onHide)
                    .disabled(phrase.reviewStatus == .hidden)
                Button("Reject", role: .destructive, action: onReject)
                    .disabled(phrase.reviewStatus == .removed)
            }
        }
        .accessibilityLabel(accessibilityText)
    }

    private var statusIcon: String {
        switch phrase.reviewStatus {
        case .checked: return "checkmark.circle.fill"
        case .hidden: return "eye.slash.fill"
        case .removed: return "xmark.circle.fill"
        case .completed: return "checkmark.seal.fill"
        case nil: return "circle.fill"
        }
    }

    private var statusColor: Color {
        switch phrase.reviewStatus {
        case .checked: return Color.accentColor
        case .hidden: return Color.orange
        case .removed: return Color.red
        case .completed: return Color.purple
        case nil: return Color.secondary.opacity(0.45)
        }
    }

    private var tileFill: Color {
        switch phrase.reviewStatus {
        case .checked:
            return Color.accentColor.opacity(0.14)
        case .hidden:
            return Color.orange.opacity(0.13)
        case .removed:
            return Color.red.opacity(0.10)
        case .completed:
            return Color.purple.opacity(0.10)
        case nil:
            return Color(.secondarySystemBackground)
        }
    }

    private var tileStroke: Color {
        if isSelected { return Color.accentColor }
        switch phrase.reviewStatus {
        case .checked:
            return Color.accentColor.opacity(0.45)
        case .hidden:
            return Color.orange.opacity(0.38)
        case .removed:
            return Color.red.opacity(0.34)
        case .completed:
            return Color.purple.opacity(0.38)
        case nil:
            return Color(.separator).opacity(0.35)
        }
    }

    private var accessibilityText: String {
        let status = phrase.reviewStatus?.title ?? "New"
        let meaning = phrase.meanings.isEmpty ? "No meaning" : phrase.meanings
        return "\(phrase.word), \(status), \(meaning)"
    }
}

private enum AddedPhraseReviewFilter: String, CaseIterable, Identifiable {
    case new
    case checked
    case hidden
    case removed
    case completed
    case all

    var id: String { rawValue }

    static let menuCases: [AddedPhraseReviewFilter] = [.removed, .checked, .hidden, .new, .completed, .all]

    var title: String {
        switch self {
        case .new: return "New"
        case .checked: return "Checked"
        case .hidden: return "Hidden"
        case .removed: return "Rejected"
        case .completed: return "Completed"
        case .all: return "All"
        }
    }

    var icon: String {
        switch self {
        case .new: return "sparkle"
        case .checked: return "checkmark.circle.fill"
        case .hidden: return "eye.slash.fill"
        case .removed: return "xmark.circle.fill"
        case .completed: return "checkmark.seal.fill"
        case .all: return "line.3.horizontal.decrease.circle"
        }
    }

    var color: Color {
        switch self {
        case .new: return Color.secondary
        case .checked: return Color.accentColor
        case .hidden: return Color.orange
        case .removed: return Color.red
        case .completed: return Color.purple
        case .all: return Color.accentColor
        }
    }

    func includes(_ phrase: PhraseItem) -> Bool {
        switch self {
        case .new: return phrase.reviewStatus == nil
        case .checked: return phrase.reviewStatus == .checked
        case .hidden: return phrase.reviewStatus == .hidden
        case .removed: return phrase.reviewStatus == .removed
        case .completed: return phrase.reviewStatus == .completed
        case .all: return phrase.reviewStatus != .completed
        }
    }

    static func filter(for status: PhraseReviewStatus?) -> AddedPhraseReviewFilter {
        switch status {
        case .checked: return .checked
        case .hidden: return .hidden
        case .removed: return .removed
        case .completed: return .completed
        case nil: return .new
        }
    }

    var tool: PhraseReviewStatusTool? {
        switch self {
        case .removed: return .removed
        case .checked: return .checked
        case .hidden: return .hidden
        case .new: return .new
        case .completed: return nil
        case .all: return nil
        }
    }
}

private struct IdentifiedString: Identifiable {
    let value: String
    var id: String { value }

    init(_ value: String) {
        self.value = value
    }
}
