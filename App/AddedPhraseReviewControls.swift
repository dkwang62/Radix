import SwiftUI

extension AddedPhraseReviewSheet {
    var topControlRow: some View {
        HStack(spacing: 8) {
            filterRow

            if hasBatchActions {
                batchMenu
            }

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

    var hasBatchActions: Bool {
        !newPhrases.isEmpty || !rejectedPhrases.isEmpty
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
                .frame(minWidth: 108)
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
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(RadixPlatform.isDesktop ? "Choose a status, then click phrases" : "Choose a status, then tap phrases")
                    .font(reviewCaptionFont.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 8)

                if selectedTool != nil {
                    Button("Stop Marking") {
                        selectedTool = nil
                        reviewCycle.setActiveTool(nil)
                        resetPageAndSelection()
                    }
                    .buttonStyle(.borderless)
                    .font(reviewCaptionFont)
                }
            }

            LazyVGrid(columns: reviewToolColumns, spacing: 7) {
                ForEach(PhraseReviewStatusTool.allCases) { option in
                    Button {
                        toggleTool(option)
                    } label: {
                        Label(option.title, systemImage: option.icon)
                            .font(reviewControlFont)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, minHeight: usesRegularReviewLayout ? 34 : 28)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(selectedTool == option ? option.color : RadixTheme.systemGray5)
                    .foregroundStyle(selectedTool == option ? Color.white : Color.primary)
                    .accessibilityLabel("Mark as \(option.title)")
                    .help("Select this tool, then choose phrases to mark them as \(option.title).")
                }
            }

            Text("Accepted: useful • Hidden: page context only • Rejected: not a phrase • Unreviewed: decide later")
                .font(ResponsiveFont.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let selectedTool {
                Text("\(selectedTool.title) is active. The filter stays unchanged while you classify.")
                    .font(reviewCaptionFont)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RadixTheme.secondaryBackground.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var reviewToolColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 7),
            count: usesRegularReviewLayout ? 4 : 2
        )
    }

    var batchMenu: some View {
        Menu {
            if !newPhrases.isEmpty {
                Button {
                    createAIReviewPage()
                } label: {
                    Label("Create AI Review Page (\(newPhrases.count))", systemImage: "photo.on.rectangle")
                }

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
        } label: {
            Label("Batch", systemImage: "ellipsis.circle")
                .font(reviewControlFont)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .tint(RadixTheme.systemGray5)
        .foregroundStyle(Color.primary)
        .help("Bulk actions for unreviewed and rejected phrases.")
    }

    var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search added phrases", text: $searchText)
                .font(.system(size: usesRegularReviewLayout ? 16 : 15))
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
        .background(RadixTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var pageFooter: some View {
        HStack(spacing: 10) {
            pageButton(systemImage: "chevron.left", action: previousPage, isEnabled: currentPageIndex > 0)

            Text("Page \(currentPageIndex + 1) of \(pageCount) · \(filteredPhrases.count) phrases")
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
