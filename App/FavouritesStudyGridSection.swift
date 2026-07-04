import SwiftUI

private struct StudySavedPageRowData {
    let collection: CharacterCollection
    let rowNumber: Int
    let practices: [ConversationPracticePack]
    let correctedPages: [CharacterCollection]
    let isExpanded: Bool
    let isActiveBrowsePage: Bool
    let artifacts: [StudyPageArtifact]
}

private struct StudyPageArtifact: Identifiable {
    enum Kind {
        case translation
        case quiz
        case phrases
        case practice(ConversationPracticePack)
        case correctedPage(CharacterCollection)
    }

    let id: String
    let title: String
    let systemImage: String
    let tint: Color
    let kind: Kind
}

extension FavouritesTab {
    var recentStudySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            recentStudyHeader
            studyReviewContent
        }
    }

    @ViewBuilder
    var studyReviewContent: some View {
        if studyGridScope == .savedPages {
            studySavedPagesList
        } else if studyReviewTiles.isEmpty {
            Text(studyGridScope.emptyMessage)
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
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
        if isNarrowStudyLayout {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    sectionTitle(studyGridScope.title)
                    Spacer(minLength: 8)
                    if studyGridScope == .all {
                        clearRecentButton
                    } else if studyGridScope == .savedPages {
                        studyPageSortMenu
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
                    sectionTitle(studyGridScope.title)
                    Spacer(minLength: 8)
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
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.red.opacity(store.rootBreadcrumb.isEmpty ? 0.04 : 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
    }

    var studySavedPagesList: some View {
        let pages = sortedStudySavedPages()
        let pageIDsWithRecordedPhrases = pageIDsWithRecordedPhraseExtractions

        return LazyVStack(spacing: 0) {
            ForEach(Array(pages.enumerated()), id: \.element.id) { index, collection in
                let rowData = studySavedPageRowData(
                    collection,
                    rowNumber: index + 1,
                    hasRecordedPagePhrases: pageIDsWithRecordedPhrases.contains(collection.id)
                )
                studySavedPageRow(rowData)
            }
        }
    }

    private func studySavedPageRowData(
        _ collection: CharacterCollection,
        rowNumber: Int,
        hasRecordedPagePhrases: Bool
    ) -> StudySavedPageRowData {
        let practices = pagePracticePacks(for: collection)
        let correctedPages = correctedStudyPages(for: collection)
        let hasPagePhrases = hasKnownPagePhrases(for: collection, hasRecordedPagePhrases: hasRecordedPagePhrases)
        let isExpanded = expandedStudySavedPageID == collection.id
        let isActiveBrowsePage = store.selectedBrowseCollectionID == collection.id
        let artifacts = studyPageArtifacts(
            collection: collection,
            practices: practices,
            correctedPages: correctedPages,
            hasPagePhrases: hasPagePhrases
        )

        return StudySavedPageRowData(
            collection: collection,
            rowNumber: rowNumber,
            practices: practices,
            correctedPages: correctedPages,
            isExpanded: isExpanded,
            isActiveBrowsePage: isActiveBrowsePage,
            artifacts: artifacts
        )
    }

    private func studySavedPageRow(_ rowData: StudySavedPageRowData) -> some View {
        let collection = rowData.collection
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    expandedStudySavedPageID = rowData.isExpanded ? nil : collection.id
                }
            } label: {
                studySavedPageCollapsedRow(rowData)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(collectionDisplayName(collection)) saved page")
            .accessibilityHint(
                rowData.isActiveBrowsePage
                    ? "Currently open in Browse. \(rowData.isExpanded ? "Collapse page actions" : "Expand page actions")"
                    : (rowData.isExpanded ? "Collapse page actions" : "Expand page actions")
            )

            if rowData.isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 8) {
                        CollectionPageActionsMenu(
                            collection: collection,
                            hasGeminiAPIKey: !store.geminiAPIKey
                                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                            onViewTranslation: {
                                showStudyTranslationReport(collection)
                            },
                            onDelete: {
                                pendingStudyDeleteCollection = collection
                            },
                            aiTasks: studyPageAITasks(for: collection)
                        )
                        .disabled(isRunningStudyPageAction)

                        Button {
                            openSavedPageInBrowse(collection)
                        } label: {
                            Label("Browse", systemImage: "arrow.up.right.square")
                                .font(ResponsiveFont.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityLabel("Open \(collection.name) in Browse")
                        .help("Browse Page and Return to Study")
                    }

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
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowData.isActiveBrowsePage ? Color.accentColor.opacity(0.11) : RadixTheme.secondaryBackground.opacity(0.58))
        .overlay(alignment: .leading) {
            if rowData.isActiveBrowsePage {
                Rectangle()
                    .fill(Color.accentColor)
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
        let visibleArtifacts = Array(rowData.artifacts.prefix(5))
        let hiddenCount = rowData.artifacts.count - visibleArtifacts.count

        return HStack(alignment: .center, spacing: 10) {
            Text("\(rowData.rowNumber)")
                .font(ResponsiveFont.caption2.weight(.semibold))
                .foregroundStyle(rowData.isActiveBrowsePage ? Color.accentColor : Color.secondary)
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
                .foregroundStyle(rowData.isActiveBrowsePage ? Color.accentColor : Color.primary)
                .lineLimit(1)
                .layoutPriority(1)

            Spacer(minLength: 6)

            HStack(spacing: 4) {
                ForEach(visibleArtifacts) { artifact in
                    Image(systemName: artifact.systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(artifact.tint)
                        .frame(width: 22, height: 22)
                        .background(artifact.tint.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .accessibilityLabel(artifact.title)
                }

                if hiddenCount > 0 {
                    Text("+\(hiddenCount)")
                        .font(ResponsiveFont.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 22, minHeight: 22)
                }
            }

            Image(systemName: rowData.isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
        }
        .frame(minHeight: 44)
    }

    private func studyPageArtifacts(
        collection: CharacterCollection,
        practices: [ConversationPracticePack],
        correctedPages: [CharacterCollection],
        hasPagePhrases: Bool
    ) -> [StudyPageArtifact] {
        var artifacts: [StudyPageArtifact] = []

        if collection.translationReport?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            artifacts.append(StudyPageArtifact(
                id: "translation",
                title: "Translation",
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
                title: "Corrected Page",
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
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(artifact.tint.opacity(0.11))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .foregroundStyle(artifact.tint)
    }

    private func performStudyPageArtifact(_ artifact: StudyPageArtifact, collection: CharacterCollection) {
        switch artifact.kind {
        case .translation:
            showStudyTranslationReport(collection)
        case .quiz:
            beginStudyPageQuiz(collection)
        case .phrases:
            showPagePhrases(collection)
        case .practice(let pack):
            openStudyPracticePack(pack)
        case .correctedPage(let corrected):
            beginPromotingOCRCorrection(original: collection, corrected: corrected)
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
