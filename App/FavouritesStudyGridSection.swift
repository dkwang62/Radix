import SwiftUI

extension FavouritesTab {
    var recentStudySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            recentStudyHeader

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
        VStack(spacing: 8) {
            ForEach(sortedStudySavedPages()) { collection in
                studySavedPageRow(collection)
            }
        }
    }

    func studySavedPageRow(_ collection: CharacterCollection) -> some View {
        let practices = pagePracticePacks(for: collection)
        let correctedPages = correctedStudyPages(for: collection)
        let pagePhrases = pagePhrases(for: collection)
        let isExpanded = expandedStudySavedPageID == collection.id

        return VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    expandedStudySavedPageID = isExpanded ? nil : collection.id
                }
            } label: {
                studySavedPageCollapsedRow(
                    collection,
                    practices: practices,
                    correctedPages: correctedPages,
                    pagePhrases: pagePhrases,
                    isExpanded: isExpanded
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(collectionDisplayName(collection)) saved page")
            .accessibilityHint(isExpanded ? "Collapse page actions" : "Expand page actions")

            if isExpanded {
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
                            if collection.translationReport?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                                studyPageArtifactChip(
                                    title: "Translation",
                                    tint: .blue
                                ) {
                                    showStudyTranslationReport(collection)
                                }
                            }

                            studyPageArtifactChip(
                                title: "Quiz",
                                tint: .orange
                            ) {
                                beginStudyPageQuiz(collection)
                            }

                            if !pagePhrases.isEmpty {
                                studyPageArtifactChip(
                                    title: "Phrases",
                                    tint: .mint
                                ) {
                                    showPagePhrases(collection)
                                }
                            }

                            ForEach(practices, id: \.packID) { pack in
                                studyPageArtifactChip(
                                    title: pagePracticeArtifactTitle(for: pack),
                                    tint: .teal
                                ) {
                                    openStudyPracticePack(pack)
                                }
                            }

                            ForEach(correctedPages) { corrected in
                                studyPageArtifactChip(
                                    title: "Corrected Page",
                                    tint: .green
                                ) {
                                    beginPromotingOCRCorrection(original: collection, corrected: corrected)
                                }
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
        .background(RadixTheme.secondaryBackground.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    func studySavedPageCollapsedRow(
        _ collection: CharacterCollection,
        practices: [ConversationPracticePack],
        correctedPages: [CharacterCollection],
        pagePhrases: [PhraseItem],
        isExpanded: Bool
    ) -> some View {
        let indicators = studyPageArtifactIndicators(
            collection: collection,
            practices: practices,
            correctedPages: correctedPages,
            pagePhrases: pagePhrases
        )
        let visibleIndicators = Array(indicators.prefix(5))
        let hiddenCount = indicators.count - visibleIndicators.count

        return HStack(alignment: .center, spacing: 10) {
            RadixThumbnailView(
                thumbnail: RadixThumbnail(jpegData: collection.thumbnailJPEGData),
                size: 34,
                cornerRadius: 8,
                placeholderSystemImage: collection.isFavorite ? "star.fill" : "photo",
                placeholderColor: collection.isFavorite ? Color.yellow : Color.secondary
            )

            Text(collectionDisplayName(collection))
                .font(ResponsiveFont.subheadline.weight(.semibold))
                .lineLimit(1)
                .layoutPriority(1)

            Spacer(minLength: 6)

            HStack(spacing: 4) {
                ForEach(Array(visibleIndicators.enumerated()), id: \.offset) { _, indicator in
                    Image(systemName: indicator.systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(indicator.tint)
                        .frame(width: 22, height: 22)
                        .background(indicator.tint.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .accessibilityLabel(indicator.label)
                }

                if hiddenCount > 0 {
                    Text("+\(hiddenCount)")
                        .font(ResponsiveFont.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 22, minHeight: 22)
                }
            }

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
        }
        .frame(minHeight: 44)
    }

    func studyPageArtifactIndicators(
        collection: CharacterCollection,
        practices: [ConversationPracticePack],
        correctedPages: [CharacterCollection],
        pagePhrases: [PhraseItem]
    ) -> [(systemImage: String, tint: Color, label: String)] {
        var indicators: [(systemImage: String, tint: Color, label: String)] = []

        if collection.translationReport?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            indicators.append(("translate", .blue, "Translation"))
        }

        indicators.append(("checkmark.circle", .orange, "Quiz"))

        if !pagePhrases.isEmpty {
            indicators.append(("text.bubble", .mint, "Phrases"))
        }

        for pack in practices {
            indicators.append((
                pagePracticeArtifactIcon(for: pack),
                .teal,
                pagePracticeArtifactTitle(for: pack)
            ))
        }

        for _ in correctedPages {
            indicators.append(("doc.badge.gearshape", .green, "Corrected Page"))
        }

        return indicators
    }

    func studyPageArtifactChip(
        title: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(ResponsiveFont.tinySystem(size: 11).weight(.semibold))
                .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(tint.opacity(0.11))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint)
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
