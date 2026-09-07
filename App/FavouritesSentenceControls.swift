import SwiftUI

extension FavouritesTab {
    func sentenceExamplesControls(usesCompactLayout: Bool? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            practiceSentenceControlRow {
                sentenceExamplePageNavigation
            } trailing: {
                practiceSentenceModeControls
            }

            if let message = sentenceExampleStatusMessage {
                Text(message)
                    .font(ResponsiveFont.caption2.weight(.semibold))
                    .foregroundStyle(RadixAccent.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            sentenceExampleFilterAndToolsRow(usesCompactLayout: usesCompactLayout)
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: RadixRadius.medium))
        .onChange(of: sentenceExampleSearchText) { _, _ in
            resetSentenceExampleResultsContext()
        }
        .onChange(of: sentenceExampleMinimumCharacterCount) { _, _ in
            resetSentenceExampleResultsContext()
        }
    }

    func sentenceExampleFilterAndToolsRow(usesCompactLayout: Bool? = nil) -> some View {
        let compactLayout = usesCompactLayout ?? (isPhone || isNarrowStudyLayout)
        return Group {
            if compactLayout {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        sentenceExampleSourceFilterMenu
                            .fixedSize(horizontal: true, vertical: false)

                        TextField("Search sentences", text: $screenState.sentences.searchText)
                            .textFieldStyle(.roundedBorder)
                            .font(ResponsiveFont.caption)
                            .frame(minWidth: 0, maxWidth: .infinity)

                        sentenceExampleToolsMenu
                            .fixedSize(horizontal: true, vertical: false)
                    }

                    sentenceExampleMinimumCharactersSlider
                        .frame(maxWidth: .infinity)
                }
            } else {
                HStack(spacing: 8) {
                    sentenceExampleSourceFilterMenu
                        .fixedSize(horizontal: true, vertical: false)

                    TextField("Search sentences", text: $screenState.sentences.searchText)
                        .textFieldStyle(.roundedBorder)
                        .font(ResponsiveFont.caption)
                        .frame(minWidth: 160, maxWidth: .infinity)

                    sentenceExampleMinimumCharactersSlider
                        .frame(width: 210)

                    sentenceExampleToolsMenu
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
    }

    var sentenceExampleMinimumCharacterFilter: Int {
        Int(sentenceExampleMinimumCharacterCount.rounded())
    }

    var sentenceExampleMinimumCharactersSlider: some View {
        HStack(spacing: 7) {
            Slider(value: $screenState.sentences.minimumCharacterCount, in: 2...40, step: 1)
                .tint(RadixAccent.primary)

            Text("\(sentenceExampleMinimumCharacterFilter)")
                .font(ResponsiveFont.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .trailing)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(RadixTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Minimum sentence characters")
        .accessibilityValue("\(sentenceExampleMinimumCharacterFilter)")
        .help("Filter to sentences with at least this many Chinese characters")
    }

    var sentenceExampleSourceFilterMenu: some View {
        Menu {
            ForEach(SentenceExampleStudyFilter.allCases) { filter in
                Button {
                    sentenceExampleFilter = filter
                    resetSentenceExampleResultsContext()
                } label: {
                    Label(
                        filter.rawValue,
                        systemImage: sentenceExampleFilter == filter ? "checkmark" : filter.systemImage
                    )
                }
            }
        } label: {
            Label(sentenceExampleFilter.rawValue, systemImage: sentenceExampleFilter.systemImage)
                .font(ResponsiveFont.caption.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .radixPill(
                    horizontal: 9,
                    vertical: 6,
                    background: RadixTheme.secondaryBackground
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(RadixAccent.primary)
        .accessibilityLabel("Sentence source")
        .accessibilityValue(sentenceExampleFilter.rawValue)
        .help("Choose sentence source")
    }

    var sentenceExampleToolsMenu: some View {
        Menu {
            if isSelectingSentenceExamples {
                Button {
                    stopSelectingSentenceExamples()
                } label: {
                    Label("Cancel Selection", systemImage: "xmark.circle")
                }
            } else if sentenceExampleResultCount > 0 {
                Button {
                    startSelectingSentenceExamples()
                } label: {
                    Label("Select Sentences", systemImage: "checklist")
                }
            }

            Button {
                exportSentenceDatabase()
            } label: {
                Label("Export Sentences", systemImage: "square.and.arrow.up")
            }
            .disabled(isRunningSentenceDatabaseTransfer)

            Button {
                showSentenceDatabaseImporter = true
            } label: {
                Label("Import Sentences", systemImage: "square.and.arrow.down")
            }
            .disabled(isRunningSentenceDatabaseTransfer)

            sentenceExampleDeleteMenu
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 18, weight: .semibold))
                .radixIconButtonSurface(
                    size: 34,
                    background: RadixTheme.systemGray5,
                    radius: 17
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isRunningSentenceDatabaseTransfer ? .secondary : RadixAccent.primary)
        .disabled(isRunningSentenceDatabaseTransfer)
        .accessibilityLabel("Sentence tools")
    }

    @ViewBuilder
    var sentenceExampleDeleteMenu: some View {
        Divider()

        Menu {
            if isSelectingSentenceExamples {
                Button(role: .destructive) {
                    showDeleteSelectedSentenceExamplesConfirmation = true
                } label: {
                    Label("Delete Selected", systemImage: "trash")
                }
                .disabled(selectedSentenceExampleIDs.isEmpty)
            }

            if canBulkDeleteFilteredSentenceExamples {
                Button(role: .destructive) {
                    showDeleteFilteredSentenceExamplesConfirmation = true
                } label: {
                    Label("Delete Results", systemImage: "trash")
                }
            }

            Button(role: .destructive) {
                showClearSentenceDatabaseConfirmation = true
            } label: {
                Label("Clear Saved Sentences...", systemImage: "trash")
            }
            .disabled(isRunningSentenceDatabaseTransfer)
        } label: {
            Label("Delete...", systemImage: "trash")
        }
        .disabled(isRunningSentenceDatabaseTransfer)
    }
}
