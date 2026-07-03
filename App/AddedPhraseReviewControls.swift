import SwiftUI

extension AddedPhraseReviewSheet {
    var topControlRow: some View {
        HStack(spacing: 8) {
            filterRow

            actionsMenu

            Spacer(minLength: 0)

            Button { dismiss() } label: {
                Label("Done", systemImage: "xmark")
                    .font(reviewControlFont)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Close phrase classification")
        }
        .frame(maxWidth: .infinity)
    }

    var filterRow: some View {
        HStack(spacing: 8) {
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
                .font(reviewControlFont)
                .lineLimit(1)
                .frame(minWidth: usesTouchReviewControls ? 86 : 108)
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
            LazyVGrid(columns: reviewToolColumns, spacing: 7) {
                ForEach(PhraseReviewStatusTool.allCases) { option in
                    Button {
                        toggleTool(option)
                    } label: {
                        Label(option.title, systemImage: option.icon)
                            .font(reviewControlFont)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, minHeight: RadixPlatform.isDesktop ? 34 : (usesRegularReviewLayout ? 30 : 26))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(selectedTool == option ? option.color : RadixTheme.systemGray5)
                    .foregroundStyle(selectedTool == option ? Color.white : Color.primary)
                    .accessibilityLabel("Mark as \(option.title)")
                    .help("Select this tool, then choose phrases to mark them as \(option.title).")
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

    var reviewToolColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 7),
            count: usesRegularReviewLayout ? 4 : 2
        )
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
                Label("Help", systemImage: RadixIcon.help)
            }
        } label: {
            Label(actionsMenuTitle, systemImage: "ellipsis.circle")
                .font(reviewControlFont)
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

            Text(pageRangeLabel)
                .font(reviewCaptionFont)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(minWidth: 150)

            pageButton(systemImage: "chevron.right", action: nextPage, isEnabled: currentPageIndex < pageCount - 1)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    func pageButton(systemImage: String, action: @escaping () -> Void, isEnabled: Bool) -> some View {
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
