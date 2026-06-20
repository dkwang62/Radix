import SwiftUI

extension FavouritesTab {
    var recentStudySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            recentStudyHeader

            if studyReviewTiles.isEmpty {
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
                    sectionTitle("Recent & Favorites")
                    Spacer(minLength: 8)
                    if studyGridScope == .all {
                        clearRecentButton
                    }
                }
                HStack(spacing: 8) {
                    studyScopePicker
                    studyScriptToggle
                }
                studyFavoriteLegend
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    sectionTitle("Recent & Favorites")
                    Spacer(minLength: 8)
                    studyScopePicker
                    studyScriptToggle
                }
                if studyGridScope == .all {
                    HStack {
                        Spacer(minLength: 0)
                        clearRecentButton
                    }
                }
                studyFavoriteLegend
            }
        }
    }

    var studyFavoriteLegend: some View {
        HStack(spacing: 5) {
            Image(systemName: RadixIcon.saved)
                .font(ResponsiveFont.tinySystem(size: 10, weight: .semibold))
                .foregroundStyle(.yellow)
            Text(studyGridScope.legendText)
                .font(ResponsiveFont.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    var studyScopePicker: some View {
        Picker("Study items", selection: Binding(
            get: { studyGridScope },
            set: { studyGridScope = $0 }
        )) {
            ForEach(StudyGridScope.allCases) { scope in
                Text(scope.title).tag(scope)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
        .frame(maxWidth: isNarrowStudyLayout ? 220 : 240)
        .accessibilityLabel("Study items")
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
