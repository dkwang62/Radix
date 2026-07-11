import SwiftUI

extension AddedPhraseReviewSheet {
    var topControlRow: some View {
        HStack(spacing: 8) {
            filterRow

            addPhraseButton

            actionsMenu

            Spacer(minLength: 0)

            Button { closeReview() } label: {
                Label(isWorkspace ? "Back to Study" : "Done", systemImage: isWorkspace ? "chevron.left" : "xmark")
                    .font(reviewControlFont)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel(isWorkspace ? "Back to Study" : "Close phrase classification")
        }
        .frame(maxWidth: .infinity)
    }

    var addPhraseButton: some View {
        Button {
            store.openNewPhraseEditor()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .bold))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .tint(RadixAccent.primary)
        .accessibilityLabel("Add new phrase")
        .help("Add a new phrase")
    }

    var filterRow: some View {
        HStack(spacing: 8) {
            Button {
                showsFilterPicker.toggle()
            } label: {
                RadixCompactChevronLabel(
                    title: filter.title,
                    systemImage: filter.icon,
                    font: reviewControlFont,
                    chevronFont: .system(size: 8, weight: .bold),
                    spacing: 7,
                    minWidth: usesTouchReviewControls ? 86 : 108,
                    usesHierarchicalSymbol: true
                )
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

    var filterPickerPopover: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(AddedPhraseReviewFilter.menuCases) { option in
                Button {
                    filter = option
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
                    .font(reviewControlFont)
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

    func filterPill(for option: AddedPhraseReviewFilter) -> some View {
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

    var toolRow: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(spacing: 7) {
                ForEach(Array(reviewToolRows.enumerated()), id: \.offset) { _, rowTools in
                    HStack(spacing: 7) {
                        ForEach(rowTools) { option in
                            reviewToolButton(option)
                        }

                        ForEach(0..<reviewToolPlaceholderCount(for: rowTools), id: \.self) { _ in
                            Color.clear
                                .frame(maxWidth: .infinity, minHeight: reviewToolButtonMinHeight)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)

            if selectedTool != nil {
                Button {
                    selectedTool = nil
                    reviewCycle.setActiveTool(nil)
                    resetPageAndSelection()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Stop marking phrases")
                .help("Stop applying the selected status tool.")
            }
        }
    }

    func reviewToolButton(_ option: PhraseReviewStatusTool) -> some View {
        Button {
            toggleTool(option)
        } label: {
            Label(option.title, systemImage: option.icon)
                .font(reviewControlFont)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: reviewToolButtonMinHeight)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .tint(selectedTool == option ? option.color : RadixTheme.systemGray5)
        .foregroundStyle(selectedTool == option ? Color.white : Color.primary)
        .accessibilityLabel("Mark as \(option.title)")
        .help("Select this tool, then choose phrases to mark them as \(option.title).")
    }

    var reviewToolButtonMinHeight: CGFloat {
        RadixPlatform.isDesktop ? 34 : (usesRegularReviewLayout ? 30 : 26)
    }

    var reviewToolColumnCount: Int {
        usesRegularReviewLayout ? 4 : 2
    }

    var reviewToolRows: [[PhraseReviewStatusTool]] {
        let tools = PhraseReviewStatusTool.allCases
        return stride(from: 0, to: tools.count, by: reviewToolColumnCount).map { start in
            let end = min(start + reviewToolColumnCount, tools.count)
            return Array(tools[start..<end])
        }
    }

    func reviewToolPlaceholderCount(for row: [PhraseReviewStatusTool]) -> Int {
        max(0, reviewToolColumnCount - row.count)
    }

    var actionsMenu: some View {
        Menu {
            if !newPhrases.isEmpty {
                Button {
                    createAIReviewPage()
                } label: {
                    Label("Create AI Review Page (\(newPhrases.count))", systemImage: "sparkles")
                }

                Divider()
            }

            if !newPhrases.isEmpty {
                Button {
                    checkNewPhrases()
                } label: {
                    Label("Accept Unreviewed (\(newPhrases.count))", systemImage: "checkmark.circle.fill")
                }
            }

            if !rejectedPhrases.isEmpty {
                Button(role: .destructive) {
                    showsDeleteRejectedConfirmation = true
                } label: {
                    Label("Remove Rejected (\(rejectedPhrases.count))", systemImage: "trash.fill")
                }
            }

            if !newPhrases.isEmpty {
                Button(role: .destructive) {
                    showsDeleteNewConfirmation = true
                } label: {
                    Label("Remove Unreviewed (\(newPhrases.count))", systemImage: "trash")
                }
            }

            if !newPhrases.isEmpty || !rejectedPhrases.isEmpty {
                Divider()
            }

            Button {
                showsReviewHelp = true
            } label: {
                RadixHelpLabel()
            }
        } label: {
            RadixCompactChevronLabel(
                title: actionsMenuTitle,
                systemImage: "ellipsis.circle",
                font: reviewControlFont,
                chevronFont: .system(size: 8, weight: .bold),
                spacing: 7
            )
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .tint(RadixTheme.systemGray5)
        .foregroundStyle(Color.primary)
        .help("Actions and help for added phrase review.")
    }

    var actionsMenuTitle: String {
        newPhrases.isEmpty ? "Actions" : "Actions (\(newPhrases.count))"
    }

    var pageFooter: some View {
        HStack(spacing: 10) {
            pageButton(systemImage: "chevron.left", action: previousPage, isEnabled: currentPageIndex > 0)

            pageJumpControl

            pageButton(systemImage: "chevron.right", action: nextPage, isEnabled: currentPageIndex < pageCount - 1)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    var pageJumpControl: some View {
        if pageCount > 1 {
            Menu {
                ForEach(0..<pageCount, id: \.self) { index in
                    Button {
                        pageIndex = index
                    } label: {
                        if index == currentPageIndex {
                            Label(pageMenuLabel(for: index), systemImage: "checkmark")
                        } else {
                            Text(pageMenuLabel(for: index))
                        }
                    }
                }
            } label: {
                RadixCompactChevronLabel(
                    title: pageRangeLabel,
                    chevronSystemName: "chevron.up.chevron.down",
                    font: reviewCaptionFont,
                    chevronFont: .system(size: 9, weight: .bold),
                    spacing: 4,
                    minWidth: 150
                )
                .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Jump to phrase review page")
        } else {
            Text(pageRangeLabel)
                .font(reviewCaptionFont)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(minWidth: 150)
        }
    }

    func pageMenuLabel(for index: Int) -> String {
        let start = index * pageSize
        guard filteredPhrases.indices.contains(start) else { return "Page \(index + 1)" }
        let slice = Array(filteredPhrases.dropFirst(start).prefix(pageSize))
        let range = AddedPhraseReviewRules.pinyinRangeLabel(for: slice)
        return range.isEmpty ? "Page \(index + 1)" : "Page \(index + 1) · \(range)"
    }

    func pageButton(systemImage: String, action: @escaping () -> Void, isEnabled: Bool) -> some View {
        Button(action: action) {
            RadixCompactChevronLabel(
                chevronSystemName: systemImage,
                chevronFont: .system(size: 12, weight: .semibold),
                chevronOpacity: 1,
                width: 30,
                height: 24
            )
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.25)
        .accessibilityLabel(systemImage.contains("left") ? "Previous page" : "Next page")
    }
}

struct AddedPhraseReviewHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Review") {
                    Label("Choose a status tool, then tap phrases to mark them quickly.", systemImage: "hand.tap")
                    Label("Tap a phrase once without a status tool to preview details.", systemImage: "text.magnifyingglass")
                    Label("Tap the same phrase again to cycle through statuses.", systemImage: "arrow.triangle.2.circlepath")
                }

                Section("Statuses") {
                    Label("Accepted: useful phrase.", systemImage: "checkmark.circle.fill")
                    Label("Hidden: page context only.", systemImage: "eye.slash.fill")
                    Label("Rejected: not a phrase.", systemImage: "xmark.circle.fill")
                    Label("Unreviewed: decide later.", systemImage: "circle")
                }

                Section("AI Review") {
                    Label("Actions can create one Browse page from all unreviewed phrases without changing their statuses.", systemImage: "sparkles")
                }
            }
            .navigationTitle("Added Phrases Help")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
