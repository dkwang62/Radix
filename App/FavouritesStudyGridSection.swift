import SwiftUI

extension FavouritesTab {
    var recentStudySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            recentStudyHeader

            if studyGridEntries.isEmpty {
                Text(studyGridScope == .saved ? "No saved study items yet." : "No study characters yet.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if !studyPhraseGridEntries.isEmpty {
                        studyGridGroupLabel("Phrases")
                        LazyVGrid(columns: recentCharacterColumns, spacing: 0) {
                            ForEach(studyPhraseGridEntries) { entry in
                                recentStudyButton(entry)
                            }
                        }
                    }

                    if !studyCharacterGridEntries.isEmpty {
                        studyGridGroupLabel("Characters")
                            .padding(.top, studyPhraseGridEntries.isEmpty ? 0 : 4)
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

    var hasStudyGridItems: Bool {
        !studyGridEntries.isEmpty
    }

    var studyGridEntries: [StudyGridEntry] {
        studyPhraseGridEntries + studyCharacterGridEntries
    }

    var studyPhraseGridEntries: [StudyGridEntry] {
        let favoritePhrases = store.favoritePhrasesItems
        let recentPhrases = studyGridScope == .all ? recentStudyPhrases : []

        let phraseEntries = favoritePhrases.flatMap { phrase in
            Array(phrase.word).enumerated().compactMap { offset, rawCharacter -> StudyGridEntry? in
                let character = String(rawCharacter)
                guard let item = store.item(for: character) else { return nil }
                return StudyGridEntry(
                    id: "phrase:\(phrase.word):\(offset)",
                    character: character,
                    pinyin: item.pinyinText,
                    phrase: phrase,
                    phraseRole: offset == 0 ? .target : .phraseMember,
                    isFavoriteCharacter: offset == 0
                )
            }
        }

        let recentPhraseEntries = recentPhrases.flatMap { phrase in
            Array(phrase.word).enumerated().compactMap { offset, rawCharacter -> StudyGridEntry? in
                let character = String(rawCharacter)
                guard let item = store.item(for: character) else { return nil }
                return StudyGridEntry(
                    id: "recentPhrase:\(phrase.word):\(offset)",
                    character: character,
                    pinyin: item.pinyinText,
                    phrase: phrase,
                    phraseRole: offset == 0 ? .target : .phraseMember,
                    isFavoriteCharacter: false
                )
            }
        }

        return phraseEntries + recentPhraseEntries
    }

    var studyCharacterGridEntries: [StudyGridEntry] {
        let visiblePhraseCharacters = Set(studyVisiblePhrases.flatMap { phrase in
            phrase.word.map { String($0) }
        })

        let favoriteCharacterEntries = store.favoriteItems
            .filter { !visiblePhraseCharacters.contains($0.character) }
            .map { item in
                StudyGridEntry(
                    id: "character:\(item.character)",
                    character: item.character,
                    pinyin: item.pinyinText,
                    phrase: nil,
                    phraseRole: nil,
                    isFavoriteCharacter: true
                )
            }

        let recentCharacterEntries = store.recentOnlyCharacterItems
            .filter { !visiblePhraseCharacters.contains($0.character) }
            .filter { _ in studyGridScope == .all }
            .map { item in
                StudyGridEntry(
                    id: "recent:\(item.character)",
                    character: item.character,
                    pinyin: item.pinyinText,
                    phrase: nil,
                    phraseRole: nil,
                    isFavoriteCharacter: false
                )
            }

        return favoriteCharacterEntries + recentCharacterEntries
    }

    var studyVisiblePhrases: [PhraseItem] {
        store.favoritePhrasesItems + (studyGridScope == .all ? recentStudyPhrases : [])
    }

    var recentStudyPhrases: [PhraseItem] {
        store.rootBreadcrumb
            .filter { $0.count > 1 && !store.isPhraseFavorite($0) }
            .compactMap { store.mergedPhrase(for: $0) }
    }

    func studyGridGroupLabel(_ title: String) -> some View {
        Text(title)
            .font(ResponsiveFont.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.top, 2)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    var recentStudyHeader: some View {
        if isNarrowStudyLayout {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    sectionTitle("Recent & Saved")
                }
                HStack(spacing: 8) {
                    studyScopePicker
                    studyScriptToggle
                    if studyGridScope == .all {
                        clearRecentButton
                    }
                }
            }
        } else {
            HStack(alignment: .center, spacing: 8) {
                sectionTitle("Recent & Saved")
                Spacer(minLength: 8)
                studyScopePicker
                studyScriptToggle
                if studyGridScope == .all {
                    clearRecentButton
                }
            }
        }
    }

    var studyScopePicker: some View {
        Picker("Study items", selection: Binding(
            get: { studyGridScope },
            set: { studyGridScope = $0 }
        )) {
            ForEach(StudyGridScope.allCases) { scope in
                Text(scope.rawValue).tag(scope)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
        .frame(maxWidth: isNarrowStudyLayout ? 150 : 170)
        .accessibilityLabel("Study items")
    }

    var clearRecentButton: some View {
        Button(role: .destructive) {
            store.clearRecentCharacters()
        } label: {
            Label("Clear Recent", systemImage: "trash")
                .font(ResponsiveFont.caption.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(store.rootBreadcrumb.isEmpty)
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
                .frame(width: 34, height: 30)
                .background(isActive ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundStyle(isActive ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    func recentStudyButton(_ entry: StudyGridEntry) -> some View {
        let isActive = entry.character == store.previewCharacter || entry.phrase?.word == store.activeSidebarPhrasePreview?.word
        return Button {
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
                    Label("Remove Phrase from Study", systemImage: "star.slash")
                }
            } else {
                Button {
                    store.toggleFavorite(character: entry.character)
                } label: {
                    Label(store.isFavorite(entry.character) ? "Remove from Study" : "Add to Study", systemImage: store.isFavorite(entry.character) ? "star.slash" : "star")
                }
                if store.rootBreadcrumb.contains(entry.character) {
                    Button {
                        store.removeRootBreadcrumb(entry.character)
                    } label: {
                        Label("Remove from Recent", systemImage: "clock.badge.xmark")
                    }
                }
            }
        }
    }

    func studyGridDisplayText(_ text: String) -> String {
        studyGridUsesTraditionalScript ? store.traditionalText(text) : store.simplifiedText(text)
    }
}

struct StudyGridEntry: Identifiable {
    let id: String
    let character: String
    let pinyin: String
    let phrase: PhraseItem?
    let phraseRole: ImagePhraseHighlightRole?
    let isFavoriteCharacter: Bool
}
