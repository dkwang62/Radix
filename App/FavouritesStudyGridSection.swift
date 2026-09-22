import SwiftUI

private struct StudySavedPageRowData {
    let collection: CharacterCollection
    let practices: [ConversationPracticePack]
    let correctedPages: [CharacterCollection]
    let isActivePage: Bool
    let artifacts: [StudyPageArtifact]
}

private struct StudyPageArtifact: Identifiable {
    enum Kind {
        case translation
        case quiz
        case phrases
        case practice(ConversationPracticePack)
        case correctedPage(CharacterCollection)
        case aiCleanedPage
    }

    let id: String
    let title: String
    let systemImage: String
    let tint: Color
    let kind: Kind
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
        } else if studyGridScope != .savedPages {
            HStack(alignment: .center, spacing: 8) {
                Spacer(minLength: 0)
                studyScriptToggle
                if studyGridScope == .all {
                    clearRecentButton
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
        screenState.activeSectionTitle
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

    var studySavedPagesList: some View {
        let pages = sortedStudySavedPages()
        let pageIDsWithRecordedPhrases = pageIDsWithRecordedPhraseExtractions
        let selectedCollection = store.selectedBrowseCollection ?? pages.first

        return VStack(alignment: .leading, spacing: 10) {
            if let collection = selectedCollection {
                let rowData = studySavedPageRowData(
                    collection,
                    hasRecordedPagePhrases: pageIDsWithRecordedPhrases.contains(collection.id)
                )
                studySavedPageRow(rowData, pages: pages)
            }
        }
    }

    private func studySavedPageRowData(
        _ collection: CharacterCollection,
        hasRecordedPagePhrases: Bool
    ) -> StudySavedPageRowData {
        let practices = pagePracticePacks(for: collection)
        let correctedPages = correctedStudyPages(for: collection)
        let aiCleanedPage = RadixStudyPreferences.aiCleanedPage(for: collection.id)
        let hasPagePhrases = hasKnownPagePhrases(for: collection, hasRecordedPagePhrases: hasRecordedPagePhrases)
        let isActivePage = store.selectedBrowseCollectionID == collection.id
        let artifacts = studyPageArtifacts(
            collection: collection,
            practices: practices,
            correctedPages: correctedPages,
            aiCleanedPage: aiCleanedPage,
            hasPagePhrases: hasPagePhrases
        )

        return StudySavedPageRowData(
            collection: collection,
            practices: practices,
            correctedPages: correctedPages,
            isActivePage: isActivePage,
            artifacts: artifacts
        )
    }

    private func studySavedPageRow(
        _ rowData: StudySavedPageRowData,
        pages: [CharacterCollection]
    ) -> some View {
        let collection = rowData.collection
        return VStack(alignment: .leading, spacing: 8) {
            studySavedPageHeader(rowData, pages: pages)

            VStack(alignment: .leading, spacing: 8) {
                studySavedPageExpandedControls(collection)

                if studyPageActionMessageCollectionID == collection.id, let studyPageActionMessage {
                    Label {
                        Text(studyPageActionMessage)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        if isRunningStudyPageAction {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "checkmark.circle")
                        }
                    }
                    .font(ResponsiveFont.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(rowData.artifacts) { artifact in
                            studyPageArtifactChip(artifact, collection: collection)
                        }
                    }
                    .padding(.vertical, 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 2)
        }
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

    private func studySavedPageHeader(
        _ rowData: StudySavedPageRowData,
        pages: [CharacterCollection]
    ) -> some View {
        SavedPageWorkspaceHeader(
            collection: rowData.collection,
            isActive: rowData.isActivePage,
            dateMode: studyPageSortOrder
        ) {
            studyPageSelectionSwitcher(
                rowData.collection,
                pages: pages,
                isActive: rowData.isActivePage
            )
        }
    }

    private func studySavedPageExpandedControls(_ collection: CharacterCollection) -> some View {
        HStack(spacing: 6) {
            studySavedPageActionsMenu(
                collection,
                usesCompactLabel: true,
                compactControlSize: 28
            )
            studyScriptToggle
            studyPageWorkspaceSwitcher(collection)
        }
    }

    private func studyPageSelectionSwitcher(
        _ collection: CharacterCollection,
        pages: [CharacterCollection],
        isActive: Bool
    ) -> some View {
        PageSelectionSwitcher(
            pages: pages,
            selectedPageID: collection.id,
            displayName: collectionDisplayName,
            onSelect: { page in
                store.selectBrowseCollection(id: page.id)
            },
            sortOrder: Binding(
                get: { studyPageSortOrder },
                set: { studyPageSortOrder = $0 }
            ),
            labelTitle: collectionDisplayName(collection),
            labelFont: ResponsiveFont.subheadline.weight(.semibold),
            labelForegroundStyle: isActive ? RadixAccent.primary : .primary,
            labelMinWidth: nil
        )
        .help("Switch saved page")
    }

    private func studySavedPageActionsMenu(
        _ collection: CharacterCollection,
        usesCompactLabel: Bool = false,
        compactControlSize: CGFloat? = nil
    ) -> some View {
        CollectionPageActionsMenu(
            collection: collection,
            actionHandlers: CollectionPageActionHandlers(
                rename: { beginStudyRenaming(collection) },
                edit: { beginStudyEditing(collection) },
                choosePhrases: { showPagePhrases(collection) },
                originalOCR: collection.sourceType == .ocr ? {
                    openOriginalOCRPageFromStudy(collection)
                } : nil,
                translation: { showStudyTranslationReport(collection) },
                delete: { pendingStudyDeleteCollection = collection }
            ),
            hasAutomaticAIConfiguration: store.hasAutomaticAIConfiguration,
            aiTasks: studyPageAITasks(for: collection),
            usesCompactLabel: usesCompactLabel,
            compactControlSize: compactControlSize
        )
        .disabled(isRunningStudyPageAction)
    }

    private func studyPageWorkspaceSwitcher(_ collection: CharacterCollection) -> some View {
        PageWorkspaceSwitcher(selectedMode: .study) { mode in
            if mode == .browse {
                openSavedPageInBrowse(collection)
            }
        }
        .help("Switch between browsing and studying this page")
    }

    private func openOriginalOCRPageFromStudy(_ collection: CharacterCollection) {
        let originalID = collection.correctedFromCollectionID ?? collection.id
        if let original = store.collection(id: originalID) {
            openSavedPageInBrowse(original)
        } else {
            openSavedPageInBrowse(collection)
        }
    }

    private func studyPageArtifacts(
        collection: CharacterCollection,
        practices: [ConversationPracticePack],
        correctedPages: [CharacterCollection],
        aiCleanedPage: AICleanedPageRecord?,
        hasPagePhrases: Bool
    ) -> [StudyPageArtifact] {
        var artifacts: [StudyPageArtifact] = []

        if aiCleanedPage != nil {
            artifacts.append(StudyPageArtifact(
                id: "ai-cleaned-page",
                title: "Extracted Sentences",
                systemImage: "doc.text.magnifyingglass",
                tint: .indigo,
                kind: .aiCleanedPage
            ))
        }

        if collection.translationReport?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            artifacts.append(StudyPageArtifact(
                id: "translation",
                title: "Explanation",
                systemImage: "translate",
                tint: .blue,
                kind: .translation
            ))
        }

        artifacts.append(StudyPageArtifact(
            id: "quiz",
            title: "Quiz",
            systemImage: "checkmark.circle",
            tint: .orange,
            kind: .quiz
        ))

        if hasPagePhrases {
            artifacts.append(StudyPageArtifact(
                id: "phrases",
                title: "Phrases",
                systemImage: "text.bubble",
                tint: .mint,
                kind: .phrases
            ))
        }

        for pack in practices {
            artifacts.append(StudyPageArtifact(
                id: "practice-\(pack.packID)",
                title: pagePracticeArtifactTitle(for: pack),
                systemImage: pagePracticeArtifactIcon(for: pack),
                tint: .teal,
                kind: .practice(pack)
            ))
        }

        for corrected in correctedPages {
            artifacts.append(StudyPageArtifact(
                id: "corrected-\(corrected.id)",
                title: "Corrected Text",
                systemImage: "doc.badge.gearshape",
                tint: .green,
                kind: .correctedPage(corrected)
            ))
        }

        return artifacts
    }

    private func studyPageArtifactChip(_ artifact: StudyPageArtifact, collection: CharacterCollection) -> some View {
        Button {
            performStudyPageArtifact(artifact, collection: collection)
        } label: {
            Text(artifact.title)
                .font(ResponsiveFont.tinySystem(size: 11).weight(.semibold))
                .lineLimit(1)
                .radixPill(
                    horizontal: 8,
                    vertical: 6,
                    background: artifact.tint.opacity(0.11),
                    radius: 8
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(artifact.tint)
    }

    private func performStudyPageArtifact(_ artifact: StudyPageArtifact, collection: CharacterCollection) {
        switch artifact.kind {
        case .translation:
            showStudyTranslationReport(collection)
        case .quiz:
            beginStudyAILinkPageTask(collection, taskID: BuiltInPromptTaskID.createQuiz.rawValue)
        case .phrases:
            showPagePhrases(collection)
        case .practice(let pack):
            openStudyPracticePack(pack, from: collection)
        case .correctedPage(let corrected):
            beginPromotingOCRCorrection(original: collection, corrected: corrected)
        case .aiCleanedPage:
            openAICleanedPage(collection)
        }
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
