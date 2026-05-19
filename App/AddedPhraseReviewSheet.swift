import SwiftUI

struct AddedPhraseReviewSheet: View {
    @EnvironmentObject private var store: RadixStore
    @Environment(\.dismiss) private var dismiss
    @State private var filter: AddedPhraseReviewFilter = .new
    @State private var searchText = ""
    @State private var selectedPhrase: PhraseItem?
    @State private var message: String?
    @State private var bulkMessage: String?

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

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 6) {
                topControlRow
                searchField
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
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var topControlRow: some View {
        HStack(spacing: 6) {
            helpMenu
                .buttonStyle(.bordered)
                .controlSize(.small)

            Spacer(minLength: 0)

            filterRow

            Spacer(minLength: 0)

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
    }

    private var helpMenu: some View {
        Menu {
            statusHelpLine(
                title: "Checked",
                detail: "Good phrase. It stays in phrase lists and can appear on pages."
            )
            statusHelpLine(
                title: "Hidden",
                detail: "Page-only phrase. It can help page highlighting but stays out of normal phrase lists."
            )
            statusHelpLine(
                title: "Rejected",
                detail: "Not a phrase. Radix remembers the rejection so it does not quietly come back."
            )
        } label: {
            Image(systemName: RadixIcon.help)
                .accessibilityLabel("Help")
        }
    }

    private func statusHelpLine(title: String, detail: String) -> some View {
        Button {
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ResponsiveFont.caption.weight(.semibold))
                Text(detail)
                    .font(ResponsiveFont.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(true)
    }

    private var filterRow: some View {
        HStack(spacing: 4) {
            ForEach(AddedPhraseReviewFilter.allCases) { option in
                Button {
                    filter = option
                    if let selectedPhrase, !option.includes(selectedPhrase) {
                        self.selectedPhrase = nil
                    }
                } label: {
                    Text(option.title)
                        .font(ResponsiveFont.caption2.weight(.semibold))
                        .lineLimit(1)
                        .frame(width: 66)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(filter == option ? Color.accentColor : Color(.systemGray5))
                .foregroundStyle(filter == option ? Color.white : Color.primary)
            }
        }
        .frame(maxWidth: .infinity)
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
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(112), spacing: 4, alignment: .center), count: 4),
                alignment: .center,
                spacing: 4
            ) {
                ForEach(filteredPhrases) { phrase in
                    AddedPhraseReviewTile(
                        phrase: phrase,
                        isSelected: selectedPhrase?.word == phrase.word,
                        onSelect: { selectedPhrase = phrase },
                        onMarkNew: { setStatus(nil, for: phrase) },
                        onCheck: { setStatus(.checked, for: phrase) },
                        onHide: { setStatus(.hidden, for: phrase) },
                        onReject: { setStatus(.removed, for: phrase) }
                    )
                }
            }
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var selectedPhraseDetailCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let phrase = selectedPhrase {
                phraseDetails(phrase)
            } else {
                Text("Select a phrase to see pinyin, meaning, and classify it.")
                    .font(ResponsiveFont.caption)
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
        VStack(alignment: .center, spacing: 3) {
            HStack(spacing: 8) {
                Text(phrase.word)
                    .font(ResponsiveFont.title2.weight(.semibold))
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

            Text(phrase.meanings.isEmpty ? "No meaning yet" : phrase.meanings)
                .font(ResponsiveFont.caption)
                .foregroundStyle(phrase.meanings.isEmpty ? Color.secondary : Color.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
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
        case nil: return "sparkle"
        }
    }

    private func statusColor(for status: PhraseReviewStatus?) -> Color {
        switch status {
        case .checked: return Color.accentColor
        case .hidden: return Color.orange
        case .removed: return Color.red
        case nil: return Color.secondary
        }
    }

    private var emptyTitle: String {
        switch filter {
        case .new: return "No new phrases"
        case .checked: return "No checked phrases"
        case .hidden: return "No hidden phrases"
        case .removed: return "No rejected phrases"
        case .all: return "No added phrases"
        }
    }

    private var emptyDescription: String {
        switch filter {
        case .new: return "New means not checked, hidden, or rejected."
        case .checked: return "Checked phrases stay visible in normal phrase lists."
        case .hidden: return "Hidden phrases stay useful on pages but stay out of the phrase library."
        case .removed: return "Rejected phrases are remembered as not-a-phrase groupings. Mark one New if you want to restore it."
        case .all: return "Added phrases with two or more characters will appear here after you add them."
        }
    }

    private func setStatus(
        _ status: PhraseReviewStatus?,
        for phrase: PhraseItem,
        closeSelection: Bool = false
    ) {
        do {
            try store.updateAddedPhraseReviewStatus(word: phrase.word, status: status)
            selectedPhrase = closeSelection ? nil : (store.addedPhrases.first { $0.word == phrase.word } ?? phrase)
            message = statusMessage(status, phrase: phrase)
            bulkMessage = nil
        } catch {
            message = "Could not update \(phrase.word): \(error.localizedDescription)"
            bulkMessage = nil
        }
    }

    private func setStatusAndAdvance(_ status: PhraseReviewStatus?, for phrase: PhraseItem) {
        let before = filteredPhrases
        let currentIndex = before.firstIndex { $0.word == phrase.word }
        let laterWords = currentIndex.map { index in
            Array(before.dropFirst(index + 1).map(\.word))
        } ?? []

        do {
            try store.updateAddedPhraseReviewStatus(word: phrase.word, status: status)
            message = statusMessage(status, phrase: phrase)
            bulkMessage = nil
            store.refreshAddedPhrases()

            let after = filteredPhrases
            if after.isEmpty {
                selectedPhrase = nil
            } else if let next = after.first(where: { laterWords.contains($0.word) }) {
                selectedPhrase = next
            } else {
                selectedPhrase = after.first
            }
        } catch {
            message = "Could not update \(phrase.word): \(error.localizedDescription)"
            bulkMessage = nil
        }
    }

    private func setFilteredStatus(_ status: PhraseReviewStatus?) {
        let phrases = filteredPhrases
        guard !phrases.isEmpty else { return }

        var changed = 0
        var failed = 0
        for phrase in phrases {
            do {
                try store.updateAddedPhraseReviewStatus(word: phrase.word, status: status)
                changed += 1
            } catch {
                failed += 1
            }
        }
        bulkMessage = bulkStatusMessage(status, changed: changed, failed: failed)
        message = nil
        store.refreshAddedPhrases()
        if let selectedWord = selectedPhrase?.word {
            selectedPhrase = store.addedPhrases.first { $0.word == selectedWord }
        }
    }

    private func bulkStatusMessage(_ status: PhraseReviewStatus?, changed: Int, failed: Int) -> String {
        let action: String = {
            switch status {
            case .checked: return "checked"
            case .hidden: return "hidden"
            case .removed: return "rejected"
            case nil: return "moved to New"
            }
        }()
        let failureText = failed == 0 ? "" : " \(failed) failed."
        return "\(changed) shown phrase\(changed == 1 ? "" : "s") \(action).\(failureText)"
    }

    private func statusMessage(_ status: PhraseReviewStatus?, phrase: PhraseItem) -> String {
        switch status {
        case .checked: return "\(phrase.word) checked."
        case .hidden: return "\(phrase.word) hidden from phrase lists, still available on pages."
        case .removed: return "\(phrase.word) rejected as not a phrase."
        case nil: return "\(phrase.word) restored to New."
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

    private var visibleMessage: String? {
        bulkMessage ?? message
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
        .accessibilityLabel(accessibilityText)
    }

    private var statusIcon: String {
        switch phrase.reviewStatus {
        case .checked: return "checkmark.circle.fill"
        case .hidden: return "eye.slash.fill"
        case .removed: return "xmark.circle.fill"
        case nil: return "circle.fill"
        }
    }

    private var statusColor: Color {
        switch phrase.reviewStatus {
        case .checked: return Color.accentColor
        case .hidden: return Color.orange
        case .removed: return Color.red
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
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .new: return "New"
        case .checked: return "Checked"
        case .hidden: return "Hidden"
        case .removed: return "Rejected"
        case .all: return "All"
        }
    }

    func includes(_ phrase: PhraseItem) -> Bool {
        switch self {
        case .new: return phrase.reviewStatus == nil
        case .checked: return phrase.reviewStatus == .checked
        case .hidden: return phrase.reviewStatus == .hidden
        case .removed: return phrase.reviewStatus == .removed
        case .all: return true
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
