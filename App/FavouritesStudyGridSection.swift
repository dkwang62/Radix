import SwiftUI

private struct StudySavedPageRowData {
    let collection: CharacterCollection
    let rowNumber: Int
    let showsResumeSignal: Bool
    let isActivePage: Bool
}

extension FavouritesTab {
    @ViewBuilder
    var studyReviewContent: some View {
        if studyGridScope == .savedPages {
            if store.allCollections.isEmpty {
                studyEmptyState(
                    title: "No Pages Yet",
                    message: "Use Camera, paste Chinese text, or import an image to create your first page.",
                    systemImage: "photo.on.rectangle",
                    actionTitle: "Create Page",
                    actionSystemImage: "plus"
                ) {
                    store.startBrowseCameraPage(preservingOrigin: true)
                }
            } else {
                studySavedPagesList
            }
        } else if studyReviewTiles.isEmpty {
            studyEmptyState(
                title: studyGridScope.emptyTitle,
                message: studyGridScope.emptyMessage,
                systemImage: studyGridScope.emptySystemImage
            )
        } else {
            RadixTileFlowLayout(
                horizontalSpacing: RadixTileMetrics.compactSpacing,
                verticalSpacing: RadixTileMetrics.compactSpacing
            ) {
                ForEach(studyReviewTiles) { tile in
                    switch tile.kind {
                    case .phrase(let row):
                        studyPhraseTile(row)
                    case .character(let entry):
                        recentStudyButton(entry)
                            .frame(width: recentStudyCharacterTileWidth)
                    }
                }
            }
        }
    }

    func studyEmptyState(
        title: String,
        message: String,
        systemImage: String,
        actionTitle: String? = nil,
        actionSystemImage: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color.secondary.opacity(0.55))

            Text(title)
                .font(ResponsiveFont.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text(message)
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: actionSystemImage ?? "arrow.right")
                        .font(ResponsiveFont.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(RadixTheme.secondaryBackground.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    func studyPhraseTile(_ row: StudyPhraseRowData) -> some View {
        let isActive = row.phrase.word == store.activeSidebarPhrasePreview?.word
        return StudyPhraseSingleTile(
            phraseText: studyGridDisplayText(row.phrase.word),
            pinyin: row.phrase.pinyin,
            marker: row.marker,
            isActive: isActive,
            onPreview: {
                presentPhrase(row.phrase)
            },
            onToggleFavorite: {
                store.togglePhraseFavorite(row.phrase.word)
            }
        )
        .contextMenu {
            Button {
                store.togglePhraseFavorite(row.phrase.word)
            } label: {
                Label(store.isPhraseFavorite(row.phrase.word) ? "Remove Phrase from Favorites" : "Add Phrase to Favorites", systemImage: store.isPhraseFavorite(row.phrase.word) ? "star.slash" : "star")
            }
        }
    }

    @ViewBuilder
    var recentStudyHeader: some View {
        if isShowingFocusedStudySection {
            EmptyView()
        } else if isNarrowStudyLayout {
            VStack(alignment: .leading, spacing: 8) {
                if studyGridScope == .all || studyGridScope == .savedPages {
                    HStack(alignment: .center, spacing: 8) {
                        Spacer(minLength: 0)
                        if studyGridScope == .all {
                        clearRecentButton
                        } else if studyGridScope == .savedPages {
                            studyPageSortMenu
                        }
                    }
                }
                if studyGridScope != .savedPages {
                    HStack {
                        Spacer(minLength: 0)
                        studyScriptToggle
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    Spacer(minLength: 0)
                    if studyGridScope == .savedPages {
                        studyPageSortMenu
                    } else {
                        studyScriptToggle
                    }
                }
                if studyGridScope == .all {
                    HStack {
                        Spacer(minLength: 0)
                        clearRecentButton
                    }
                }
            }
        }
    }

    var isShowingFocusedStudySection: Bool {
        focusedStudySection != nil
    }

    var isShowingAddedPhraseReview: Bool {
        focusedStudySection == .addedPhrases
    }

    var isShowingConversationPractice: Bool {
        focusedStudySection == .conversationPractice
    }

    var isShowingSentenceExamples: Bool {
        focusedStudySection == .sentences
    }

    var isPhoneSentenceExamplesReadingMode: Bool {
        isPhone && isShowingSentenceExamples
    }

    var showsStudyPinnedControls: Bool {
        !isPhone || !isShowingFocusedStudySection
    }

    var activeStudySectionTitle: String {
        if showStudyCheckpoints { return "Checkpoints" }
        if let focusedStudySection { return focusedStudySection.title }
        return studyGridScope.title
    }

    var clearRecentButton: some View {
        Button(role: .destructive) {
            store.clearRecentCharacters()
        } label: {
            Label("Clear Recent", systemImage: RadixIcon.delete)
                .font(ResponsiveFont.caption2.weight(.semibold))
        }
        .buttonStyle(.plain)
        .controlSize(.small)
        .foregroundStyle(store.rootBreadcrumb.isEmpty ? Color.secondary : Color.red.opacity(0.82))
        .radixPill(
            horizontal: 8,
            vertical: 5,
            background: Color.red.opacity(store.rootBreadcrumb.isEmpty ? 0.04 : 0.08),
            radius: 8
        )
        .disabled(store.rootBreadcrumb.isEmpty)
        .accessibilityLabel("Clear Recent")
    }

    var recentGridFontSize: CGFloat {
        RadixPlatform.isDesktop ? 28 : (isNarrowStudyLayout ? 24 : 26)
    }

    var recentStudyCharacterTileWidth: CGFloat {
        RadixPlatform.isDesktop ? 80 : (isNarrowStudyLayout ? 72 : 76)
    }

    var studyScriptToggle: some View {
        CompactScriptToggle(
            isTraditional: studyGridUsesTraditionalScript,
            accessibilityLabel: "Study grid character style",
            minWidth: 32,
            height: 28
        ) {
            studyGridUsesTraditionalScript.toggle()
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    var studyPageSortMenu: some View {
        Menu {
            ForEach(PageCollectionSortOrder.allCases) { order in
                Button {
                    studyPageSortOrder = order
                } label: {
                    Label(order.rawValue, systemImage: studyPageSortOrder == order ? "checkmark" : "calendar")
                }
            }
        } label: {
            Label(studyPageSortOrder.rawValue, systemImage: "arrow.up.arrow.down")
                .font(ResponsiveFont.caption2.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .radixPill(
                    horizontal: 8,
                    vertical: 5,
                    background: RadixAccent.primary.opacity(0.1),
                    radius: 8
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(RadixAccent.primary)
    }

    var studySavedPagesList: some View {
        let pages = sortedStudySavedPages()
        let resumePageID = store.sortedCollections(order: .lastViewed).first?.id

        return LazyVStack(spacing: 0) {
            ForEach(Array(pages.enumerated()), id: \.element.id) { index, collection in
                let rowData = studySavedPageRowData(
                    collection,
                    rowNumber: index + 1,
                    resumePageID: resumePageID
                )
                studySavedPageRow(rowData)
            }
        }
    }

    private func studySavedPageRowData(
        _ collection: CharacterCollection,
        rowNumber: Int,
        resumePageID: UUID?
    ) -> StudySavedPageRowData {
        let isActivePage = store.selectedBrowseCollectionID == collection.id
        let showsResumeSignal = isActivePage || resumePageID == collection.id

        return StudySavedPageRowData(
            collection: collection,
            rowNumber: rowNumber,
            showsResumeSignal: showsResumeSignal,
            isActivePage: isActivePage
        )
    }

    private func studySavedPageRow(_ rowData: StudySavedPageRowData) -> some View {
        let collection = rowData.collection
        return Button {
            openSavedPageWorkspace(collection)
        } label: {
            studySavedPageCollapsedRow(rowData)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(collectionDisplayName(collection)) saved page")
        .accessibilityHint("Open page")
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowData.isActivePage ? RadixAccent.primary.opacity(0.11) : RadixTheme.secondaryBackground.opacity(0.58))
        .overlay(alignment: .leading) {
            if rowData.isActivePage {
                Rectangle()
                    .fill(RadixAccent.primary)
                    .frame(width: 3)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(RadixTheme.separator.opacity(0.7))
                .frame(height: 0.5)
        }
    }

    private func studySavedPageCollapsedRow(_ rowData: StudySavedPageRowData) -> some View {
        return HStack(alignment: .center, spacing: 10) {
            Text("\(rowData.rowNumber)")
                .font(ResponsiveFont.caption2.weight(.semibold))
                .foregroundStyle(rowData.isActivePage ? RadixAccent.primary : Color.secondary)
                .monospacedDigit()
                .frame(width: 28, alignment: .trailing)

            RadixThumbnailView(
                thumbnail: RadixThumbnail(jpegData: rowData.collection.thumbnailJPEGData),
                size: 34,
                cornerRadius: 8,
                placeholderSystemImage: rowData.collection.isFavorite ? "star.fill" : "photo",
                placeholderColor: rowData.collection.isFavorite ? Color.yellow : Color.secondary
            )

            Text(collectionDisplayName(rowData.collection))
                .font(ResponsiveFont.subheadline.weight(.semibold))
                .foregroundStyle(rowData.isActivePage ? RadixAccent.primary : Color.primary)
                .lineLimit(1)
                .layoutPriority(1)

            Spacer(minLength: 6)

            if rowData.showsResumeSignal {
                Label(studyPageResumeText(rowData.collection), systemImage: "clock")
                    .font(ResponsiveFont.caption2.weight(.semibold))
                    .foregroundStyle(rowData.isActivePage ? RadixAccent.primary : Color.secondary)
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .radixPill(
                        horizontal: 6,
                        vertical: 4,
                        background: (rowData.isActivePage ? RadixAccent.primary : Color.secondary).opacity(0.10),
                        radius: 7
                    )
            }

            RadixCompactChevronLabel(
                chevronSystemName: "chevron.right",
                chevronFont: .system(size: 12, weight: .bold),
                chevronForegroundStyle: .secondary,
                width: 22,
                height: 22
            )
        }
        .frame(minHeight: 44)
    }

    func studySavedPageActionsMenu(_ collection: CharacterCollection) -> some View {
        CollectionPageActionsMenu(
            collection: collection,
            hasGeminiAPIKey: !store.geminiAPIKey
                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            onViewOriginalOCR: collection.sourceType == .ocr ? {
                openOriginalOCRPageFromStudy(collection)
            } : nil,
            onViewTranslation: {
                showStudyTranslationReport(collection)
            },
            onDelete: {
                pendingStudyDeleteCollection = collection
            },
            aiTasks: studyPageAITasks(for: collection)
        )
        .disabled(isRunningStudyPageAction)
    }

    private func openOriginalOCRPageFromStudy(_ collection: CharacterCollection) {
        let originalID = collection.correctedFromCollectionID ?? collection.id
        if let original = store.collection(id: originalID) {
            openSavedPageInBrowse(original)
        } else {
            openSavedPageInBrowse(collection)
        }
    }

    private func studyPageResumeText(_ collection: CharacterCollection) -> String {
        let date = collection.lastViewedAt ?? collection.createdAt
        return "Viewed \(date.formatted(date: .abbreviated, time: .omitted))"
    }

    func recentStudyButton(_ entry: StudyGridEntry) -> some View {
        let isActive = entry.character == store.previewCharacter
        return AnyView(Button {
            store.preview(character: entry.character)
            store.refreshPhrases(for: entry.character)
        } label: {
            BrowseGridTileLabel(
                displayCharacter: studyGridDisplayText(entry.character),
                pinyin: entry.pinyin,
                fontSize: recentGridFontSize,
                isFavorite: entry.isFavoriteCharacter,
                background: BrowseImageTileStyle.background(isActive: isActive, highlightRole: nil, isMemoryHighlighted: false),
                stroke: BrowseImageTileStyle.stroke(isActive: isActive, highlightRole: nil, isMemoryHighlighted: false),
                strokeWidth: RadixTileMetrics.borderWidth,
                onShowPhrases: {
                    store.refreshPhrases(for: entry.character)
                    NotificationCenter.default.post(name: .radixShowPhraseTable, object: entry.character)
                }
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                store.toggleFavorite(character: entry.character)
            } label: {
                Label(store.isFavorite(entry.character) ? "Remove from Favorites" : "Add to Favorites", systemImage: store.isFavorite(entry.character) ? "star.slash" : "star")
            }
            if store.rootBreadcrumb.contains(entry.character) {
                Button {
                    store.removeRootBreadcrumb(entry.character)
                } label: {
                    Label("Remove from Recent", systemImage: "clock.badge.xmark")
                }
            }
        })
    }
}
