import SwiftUI

extension AddedPhraseReviewSheet {
    var topControlRow: some View {
        HStack(spacing: 6) {
            Spacer(minLength: 0)

            filterRow

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

            Spacer(minLength: 0)
        }
    }

    var filterRow: some View {
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

    var filterPickerPopover: some View {
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

    @ViewBuilder
    var toolRow: some View {
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
                    .tint(selectedTool == option ? option.color : RadixTheme.systemGray5)
                    .foregroundStyle(selectedTool == option ? Color.white : Color.primary)
                    .accessibilityLabel("Mark as \(option.title)")
                    .help("Mark as \(option.title)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    var promoteCheckedRow: some View {
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

    var searchField: some View {
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
        .background(RadixTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var pageFooter: some View {
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
