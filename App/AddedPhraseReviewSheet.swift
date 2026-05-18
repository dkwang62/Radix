import SwiftUI

struct AddedPhraseReviewSheet: View {
    @EnvironmentObject private var store: RadixStore
    @Environment(\.dismiss) private var dismiss
    @State private var filter: AddedPhraseReviewFilter = .new
    @State private var searchText = ""
    @State private var editorWord: IdentifiedString?
    @State private var message: String?

    private var addedPhrases: [PhraseItem] {
        store.addedPhrases.filter { !store.isPhraseInBase($0.word) }
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
            VStack(alignment: .leading, spacing: 12) {
                header
                filterRow
                searchField

                if let message {
                    Text(message)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }

                if filteredPhrases.isEmpty {
                    ContentUnavailableView(
                        emptyTitle,
                        systemImage: "text.badge.checkmark",
                        description: Text(emptyDescription)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    phraseList
                }
            }
            .padding()
            .navigationTitle("Review Added")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editorWord) { word in
                QuickPhraseEditorView(word: word.value, isNew: false)
                    .environmentObject(store)
            }
            .onAppear {
                store.refreshAddedPhrases()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Clean up phrases you added.")
                .font(ResponsiveFont.headline.weight(.semibold))
            Text("Check good phrases, hide page-only phrases, or remove mistakes.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var filterRow: some View {
        Picker("Review Status", selection: $filter) {
            ForEach(AddedPhraseReviewFilter.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search added phrases", text: $searchText)
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
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var phraseList: some View {
        List {
            ForEach(filteredPhrases) { phrase in
                AddedPhraseReviewRow(
                    phrase: phrase,
                    onPreview: { preview(phrase) },
                    onEdit: { editorWord = IdentifiedString(phrase.word) },
                    onMarkNew: { setStatus(nil, for: phrase) },
                    onCheck: { setStatus(.checked, for: phrase) },
                    onHide: { setStatus(.hidden, for: phrase) },
                    onRemove: { setStatus(.removed, for: phrase) }
                )
            }
        }
        .listStyle(.plain)
    }

    private var emptyTitle: String {
        switch filter {
        case .new: return "No new phrases"
        case .checked: return "No checked phrases"
        case .hidden: return "No hidden phrases"
        case .removed: return "No removed phrases"
        case .all: return "No added phrases"
        }
    }

    private var emptyDescription: String {
        switch filter {
        case .new: return "New means not checked, hidden, or removed."
        case .checked: return "Checked phrases stay visible in normal phrase lists."
        case .hidden: return "Hidden phrases stay useful on pages but stay out of the phrase library."
        case .removed: return "Removed phrases are kept here so you can restore them if needed."
        case .all: return "Added phrases will appear here after you add them."
        }
    }

    private func preview(_ phrase: PhraseItem) {
        store.presentPhraseInSidebar(phrase)
    }

    private func setStatus(_ status: PhraseReviewStatus?, for phrase: PhraseItem) {
        do {
            try store.updateAddedPhraseReviewStatus(word: phrase.word, status: status)
            message = statusMessage(status, phrase: phrase)
        } catch {
            message = "Could not update \(phrase.word): \(error.localizedDescription)"
        }
    }

    private func statusMessage(_ status: PhraseReviewStatus?, phrase: PhraseItem) -> String {
        switch status {
        case .checked: return "\(phrase.word) checked."
        case .hidden: return "\(phrase.word) hidden from phrase lists, still available on pages."
        case .removed: return "\(phrase.word) removed from active phrases."
        case nil: return "\(phrase.word) restored to New."
        }
    }

    private func reviewSort(_ lhs: PhraseItem, _ rhs: PhraseItem) -> Bool {
        switch filter {
        case .new, .all:
            let lhsDate = lhs.addedAt ?? .distantPast
            let rhsDate = rhs.addedAt ?? .distantPast
            if lhsDate != rhsDate { return lhsDate > rhsDate }
        case .checked, .hidden, .removed:
            let lhsDate = lhs.lastReviewedAt ?? .distantPast
            let rhsDate = rhs.lastReviewedAt ?? .distantPast
            if lhsDate != rhsDate { return lhsDate > rhsDate }
        }
        if lhs.word.count != rhs.word.count { return lhs.word.count < rhs.word.count }
        return lhs.pinyin < rhs.pinyin
    }
}

private struct AddedPhraseReviewRow: View {
    let phrase: PhraseItem
    let onPreview: () -> Void
    let onEdit: () -> Void
    let onMarkNew: () -> Void
    let onCheck: () -> Void
    let onHide: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                PhraseSummaryTile(phrase: phrase, onSelect: onPreview)
                    .phraseContextMenu(phrase)

                VStack(alignment: .leading, spacing: 4) {
                    Text(phrase.meanings.isEmpty ? "No meaning yet" : phrase.meanings)
                        .font(ResponsiveFont.body)
                        .foregroundStyle(phrase.meanings.isEmpty ? Color.secondary : Color.primary)
                        .lineLimit(2)
                    Text(reviewDetail)
                        .font(ResponsiveFont.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { actionButtons }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) { actionButtons }
                }
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button("Preview", action: onPreview)
            .buttonStyle(.bordered)
            .controlSize(.small)

        Button("Edit", action: onEdit)
            .buttonStyle(.bordered)
            .controlSize(.small)

        if phrase.reviewStatus != nil {
            Button("New", action: onMarkNew)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }

        Button("Checked", action: onCheck)
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(phrase.reviewStatus == .checked)

        Button("Hide", action: onHide)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(phrase.reviewStatus == .hidden)

        Button("Remove", role: .destructive, action: onRemove)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(phrase.reviewStatus == .removed)
    }

    private var reviewDetail: String {
        let status = phrase.reviewStatus?.title ?? "New"
        if let lastReviewedAt = phrase.lastReviewedAt {
            return "\(status) · reviewed \(lastReviewedAt.formatted(date: .abbreviated, time: .shortened))"
        }
        if let addedAt = phrase.addedAt {
            return "\(status) · added \(addedAt.formatted(date: .abbreviated, time: .shortened))"
        }
        return status
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
        case .removed: return "Removed"
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
