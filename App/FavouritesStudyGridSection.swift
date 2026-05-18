import SwiftUI

extension FavouritesTab {
    var recentStudySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            recentStudyHeader

            if studyGridEntries.isEmpty {
                Text(studyGridScope == .favorites ? "No favorite study items yet." : "No study characters yet.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    if !studyPhraseRows.isEmpty {
                        studyGridGroupLabel("Phrases")
                        StudyPhraseFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                            ForEach(studyPhraseRows) { row in
                                studyPhraseTile(row)
                            }
                        }
                    }

                    if !studyCharacterGridEntries.isEmpty {
                        studyGridGroupLabel("Characters")
                            .padding(.top, studyPhraseRows.isEmpty ? 0 : 10)
                        LazyVGrid(columns: recentCharacterColumns, spacing: 0) {
                            ForEach(studyCharacterGridEntries) { entry in
                                recentStudyButton(entry)
                            }
                        }
                    }
                }
            }
        }
    }

    func studyGridGroupLabel(_ title: String) -> some View {
        Text(title)
            .font(ResponsiveFont.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .accessibilityAddTraits(.isHeader)
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
            Text("Tap a phrase to preview it. Tap its star to favorite the whole phrase.")
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
        .frame(maxWidth: isNarrowStudyLayout ? 144 : 160)
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

    var recentCharacterColumns: [GridItem] {
        #if targetEnvironment(macCatalyst)
        return [GridItem(.adaptive(minimum: 44, maximum: 80), spacing: 0)]
        #else
        if isNarrowStudyLayout {
            return [GridItem(.adaptive(minimum: 44, maximum: 72), spacing: 0)]
        }
        return [GridItem(.adaptive(minimum: 44, maximum: 76), spacing: 0)]
        #endif
    }

    var recentGridFontSize: CGFloat {
        #if targetEnvironment(macCatalyst)
        return 28
        #else
        return isNarrowStudyLayout ? 24 : 26
        #endif
    }

    var studyPhraseTileWidth: CGFloat {
        #if targetEnvironment(macCatalyst)
        return 58
        #else
        return isNarrowStudyLayout ? 50 : 56
        #endif
    }

    var studyScriptToggle: some View {
        HStack(spacing: 4) {
            studyScriptButton("简", isActive: !studyGridUsesTraditionalScript) {
                studyGridUsesTraditionalScript = false
            }
            studyScriptButton("繁", isActive: studyGridUsesTraditionalScript) {
                studyGridUsesTraditionalScript = true
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Study grid character style")
        .accessibilityValue(studyGridUsesTraditionalScript ? "Traditional" : "Simplified")
    }

    func studyScriptButton(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(ResponsiveFont.subheadline.weight(.semibold))
                .frame(width: 32, height: 28)
                .background(isActive ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundStyle(isActive ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    func recentStudyButton(_ entry: StudyGridEntry) -> some View {
        if let marker = entry.phraseMarker {
            return AnyView(studyPhraseMarkerButton(entry, marker: marker))
        }

        let isActive = entry.character == store.previewCharacter || entry.phrase?.word == store.activeSidebarPhrasePreview?.word
        return AnyView(Button {
            if let phrase = entry.phrase {
                presentPhrase(phrase)
            } else {
                store.preview(character: entry.character)
                store.refreshPhrases(for: entry.character)
            }
        } label: {
            BrowseGridTileLabel(
                displayCharacter: studyGridDisplayText(entry.character),
                pinyin: entry.pinyin,
                fontSize: recentGridFontSize,
                isFavorite: entry.isFavoriteCharacter,
                background: BrowseImageTileStyle.background(isActive: isActive, highlightRole: entry.phraseRole, isMemoryHighlighted: false),
                stroke: BrowseImageTileStyle.stroke(isActive: isActive, highlightRole: entry.phraseRole, isMemoryHighlighted: false),
                strokeWidth: entry.phraseRole == nil ? 2 : 2.5,
                onShowPhrases: {
                    store.refreshPhrases(for: entry.character)
                    NotificationCenter.default.post(name: .radixShowPhraseTable, object: entry.character)
                }
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let phrase = entry.phrase {
                Button {
                    store.togglePhraseFavorite(phrase.word)
                } label: {
                    Label(store.isPhraseFavorite(phrase.word) ? "Remove Phrase from Favorites" : "Add Phrase to Favorites", systemImage: store.isPhraseFavorite(phrase.word) ? "star.slash" : "star")
                }
            } else {
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
            }
        })
    }

    func studyPhraseMarkerButton(_ entry: StudyGridEntry, marker: StudyPhraseMarker) -> some View {
        Button {
            if let phrase = entry.phrase {
                store.togglePhraseFavorite(phrase.word)
            }
        } label: {
            StudyPhraseMarkerTile(marker: marker)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(marker == .favorite ? "Remove phrase from Favorites" : "Add phrase to Favorites")
        .contextMenu {
            if let phrase = entry.phrase {
                Button {
                    store.togglePhraseFavorite(phrase.word)
                } label: {
                    Label(marker == .favorite ? "Remove Phrase from Favorites" : "Add Phrase to Favorites", systemImage: marker == .favorite ? "star.slash" : "star")
                }
            }
        }
    }
}
