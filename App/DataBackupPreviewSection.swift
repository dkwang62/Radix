import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DataBackupPreviewSection: View {
    @EnvironmentObject private var store: RadixStore
    @State private var selectedPhrase: PhraseItem?
    @State private var revertBasePhraseMessage: String?

    let addedPhraseEntries: [PhraseItem]
    let basePhraseCoreEditEntries: [PhraseItem]
    let phraseEntriesWithNotes: [PhraseItem]
    let onPreviewCharacter: (String) -> Void

    @Binding var showSavedPagesPreview: Bool
    @Binding var showFavoritesPreview: Bool
    @Binding var showAITemplatesPreview: Bool
    @Binding var showAppStatePreview: Bool
    @Binding var showAddedCharactersPreview: Bool
    @Binding var showAddedPhrasesPreview: Bool
    @Binding var showEditedCharactersPreview: Bool
    @Binding var showEditedPhrasesPreview: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's In My Backup")
                .font(ResponsiveFont.headline)

            VStack(alignment: .leading, spacing: 12) {
                DisclosureGroup("Saved Images (\(store.allCollections.count))", isExpanded: $showSavedPagesPreview) {
                    backupSavedPagesRows
                }

                DisclosureGroup("Favorites (\(store.favoriteItems.count) characters, \(store.favoritePhrasesItems.count) phrases)", isExpanded: $showFavoritesPreview) {
                    backupFavoritesSummary
                }

                DisclosureGroup("AI Templates (\(store.promptConfig.tasks.count) tasks)", isExpanded: $showAITemplatesPreview) {
                    backupAITemplatesSummary
                }

                DisclosureGroup("App State", isExpanded: $showAppStatePreview) {
                    backupAppStateSummary
                }

                DisclosureGroup("Added Characters (\(store.addedDictionaryCharacters.count))", isExpanded: $showAddedCharactersPreview) {
                    backupCharacterRows(store.addedDictionaryCharacters)
                }

                DisclosureGroup("Added Phrases (\(addedPhraseEntries.count))", isExpanded: $showAddedPhrasesPreview) {
                    backupPhraseRows(addedPhraseEntries)
                }

                DisclosureGroup("Edits to Base Dictionary (\(store.baseDictionaryCoreEditedCharacters.count))", isExpanded: $showEditedCharactersPreview) {
                    backupCharacterRows(store.baseDictionaryCoreEditedCharacters)
                }

                DisclosureGroup("Edits to Base Phrases (\(basePhraseCoreEditEntries.count))", isExpanded: $showEditedPhrasesPreview) {
                    revertBasePhrasesRow
                    backupPhraseRows(basePhraseCoreEditEntries)
                }

                DisclosureGroup("Characters With Notes (\(store.dictionaryCharactersWithNotes.count))") {
                    backupCharacterRows(store.dictionaryCharactersWithNotes)
                }

                DisclosureGroup("Phrases With Notes (\(phraseEntriesWithNotes.count))") {
                    backupPhraseRows(phraseEntriesWithNotes)
                }

            }
            .padding(12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(item: phonePhraseSheetBinding) { phrase in
            NavigationStack {
                PhraseInfoCard(phrase: phrase, onDone: {
                    selectedPhrase = nil
                })
                    .environmentObject(store)
                    .padding()
                    .navigationTitle(phrase.word)
                    .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var revertBasePhrasesRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Revert base phrase edits that have no notes.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Revert All", role: .destructive, action: revertAllUnnotedBasePhraseEdits)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            if let revertBasePhraseMessage {
                Text(revertBasePhraseMessage)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    private func revertAllUnnotedBasePhraseEdits() {
        do {
            let revertedWords = try store.removeAllUnnotedAddedPhrases()
            let phraseWord = revertedWords.count == 1 ? "phrase" : "phrases"
            revertBasePhraseMessage = revertedWords.isEmpty
                ? "No edited base phrases without notes to revert."
                : "Reverted \(revertedWords.count) edited base \(phraseWord) without notes."
        } catch {
            revertBasePhraseMessage = "Revert failed: \(error.localizedDescription)"
        }
    }

    @ViewBuilder
    private func backupCharacterRows(_ characters: [String]) -> some View {
        let sortedCharacters = sortedBackupCharacters(characters)
        let displayed = Array(sortedCharacters.prefix(80))
        let truncated = sortedCharacters.count > displayed.count

        VStack(alignment: .leading, spacing: 8) {
            if characters.isEmpty {
                Text("No matching characters.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: backupCharacterColumns, alignment: .leading, spacing: 8) {
                    ForEach(displayed, id: \.self) { character in
                        let item = store.item(for: character)
                        backupCharacterTile(character, item: item)
                    }
                }

                if truncated {
                    Text("Showing the first \(displayed.count) of \(sortedCharacters.count) characters.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func backupCharacterTile(_ character: String, item: ComponentItem?) -> some View {
        let pinyin = item?.pinyinText ?? ""

        Button {
            onPreviewCharacter(character)
        } label: {
            VStack(spacing: 4) {
            Text(character)
                    .font(.system(size: 28, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(pinyin.isEmpty ? "-" : pinyin)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(Color(.secondarySystemBackground).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.separator).opacity(0.45), lineWidth: 1)
        )
        .copyCharacterContextMenu(character, pinyin: pinyin)
    }

    @ViewBuilder
    private func backupPhraseRows(_ phrases: [PhraseItem]) -> some View {
        let sortedPhrases = sortedBackupPhrases(phrases)

        if phrases.isEmpty {
            Text("No matching phrases.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        } else {
            LazyVGrid(columns: backupPhraseColumns, alignment: .leading, spacing: 8) {
                ForEach(sortedPhrases) { phrase in
                    backupPhraseRow(phrase)
                }
            }
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func backupPhraseRow(_ phrase: PhraseItem) -> some View {
        Button {
            presentPhrase(phrase)
        } label: {
            PhraseSummaryTile(phrase: phrase)
        }
        .buttonStyle(.plain)
        .phraseContextMenu(phrase)
    }

    private var backupSavedPagesRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.allCollections.isEmpty {
                Text("No saved images.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.allCollections) { collection in
                    HStack(spacing: 8) {
                        if let thumbnail = backupThumbnailImage(for: collection) {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 36, height: 36)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }

                        Text(collection.name)
                            .font(ResponsiveFont.caption)
                        Spacer()
                        Text("\(collection.characters.count) chars")
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(.top, 8)
    }

    private func backupThumbnailImage(for collection: CharacterCollection) -> UIImage? {
        guard let data = collection.thumbnailJPEGData else { return nil }
        return UIImage(data: data)
    }

    private var backupFavoritesSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            summaryLine("Favorite characters", value: "\(store.favoriteItems.count)")
            if !store.favoriteItems.isEmpty {
                Text(store.favoriteItems.map(\.character).joined(separator: " "))
                    .font(ResponsiveFont.caption)
            }

            summaryLine("Favorite phrases", value: "\(store.favoritePhrasesItems.count)")
            if !store.favoritePhrasesItems.isEmpty {
                LazyVGrid(columns: backupPhraseColumns, alignment: .leading, spacing: 8) {
                    ForEach(store.favoritePhrasesItems) { phrase in
                        Button {
                            presentPhrase(phrase)
                        } label: {
                            PhraseSummaryTile(phrase: phrase)
                        }
                        .buttonStyle(.plain)
                        .phraseContextMenu(phrase)
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    private var backupPhraseColumns: [GridItem] {
        [GridItem(.adaptive(minimum: isPhone ? 120 : 140), spacing: 8)]
    }

    private var backupCharacterColumns: [GridItem] {
        [GridItem(.adaptive(minimum: isPhone ? 72 : 82), spacing: 8)]
    }

    private func sortedBackupCharacters(_ characters: [String]) -> [String] {
        characters.sorted { lhs, rhs in
            let leftItem = store.item(for: lhs)
            let rightItem = store.item(for: rhs)
            let leftKey = backupSortKey(primary: leftItem?.pinyinText ?? "", fallback: lhs)
            let rightKey = backupSortKey(primary: rightItem?.pinyinText ?? "", fallback: rhs)
            return leftKey.localizedStandardCompare(rightKey) == .orderedAscending
        }
    }

    private func sortedBackupPhrases(_ phrases: [PhraseItem]) -> [PhraseItem] {
        phrases.sorted { lhs, rhs in
            let leftKey = backupSortKey(primary: lhs.pinyin, fallback: lhs.word)
            let rightKey = backupSortKey(primary: rhs.pinyin, fallback: rhs.word)
            return leftKey.localizedStandardCompare(rightKey) == .orderedAscending
        }
    }

    private func backupSortKey(primary: String, fallback: String) -> String {
        let value = primary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : primary
        return value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private var isPhone: Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        return UIDevice.current.userInterfaceIdiom == .phone
        #endif
    }

    private func presentPhrase(_ phrase: PhraseItem) {
        store.speakPhrase(phrase)
        if isPhone {
            store.presentPhraseInSidebar(phrase)
            selectedPhrase = phrase
        } else {
            selectedPhrase = nil
            store.presentPhraseInSidebar(phrase)
        }
    }

    private var phonePhraseSheetBinding: Binding<PhraseItem?> {
        Binding(
            get: { isPhone ? selectedPhrase : nil },
            set: { newValue in
                if isPhone {
                    selectedPhrase = newValue
                }
            }
        )
    }

    private var backupAITemplatesSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            summaryLine("Template blocks", value: "4 system sections")
            summaryLine("Prompt tasks", value: "\(store.promptConfig.tasks.count)")
            summaryLine("Selected tasks", value: "\(store.promptSelectedTaskIDs.count)")

            ForEach(store.promptConfig.tasks) { task in
                HStack {
                    Text(task.title)
                        .font(ResponsiveFont.caption)
                    Spacer()
                    if store.promptSelectedTaskIDs.contains(task.id) {
                        Text("Selected")
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    private var backupAppStateSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            summaryLine("Current route", value: routeDisplayName(store.route))
            summaryLine("Home tab", value: homeTabDisplayName(store.homeTab))
            summaryLine("Search mode", value: store.searchMode.rawValue)
            summaryLine("Current query", value: store.query.isEmpty ? "None" : store.query)
            summaryLine("Selected character", value: store.previewCharacter ?? "None")
            summaryLine("Selected AI image", value: store.selectedAICollection?.name ?? "None")
            summaryLine("Default AI", value: store.defaultAIName)
            if store.defaultAIPreset == .custom {
                summaryLine("Custom AI URL", value: store.defaultAIBaseURLString.isEmpty ? "None" : store.defaultAIBaseURLString)
            }
            summaryLine("Search history", value: "\(store.searchHistory.count) items")
            summaryLine("Remembered trail", value: "\(store.rootBreadcrumb.count) items")
            summaryLine("Phrase length", value: "\(store.phraseLength)-character")
        }
        .padding(.top, 8)
    }

    private func summaryLine(_ title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(ResponsiveFont.caption.bold())
            Spacer()
            Text(value)
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func routeDisplayName(_ route: AppRoute) -> String {
        switch route {
        case .search: return "Search"
        case .capture: return "Capture"
        case .lineage: return "Components"
        case .aiLink: return "AI Link"
        case .favourites: return "Favorites"
        }
    }

    private func homeTabDisplayName(_ tab: HomeTab) -> String {
        switch tab {
        case .smart: return "Smart Search"
        case .filter: return "Filter"
        case .favourites: return "Favorites"
        case .dataEdit: return "DataEdit"
        }
    }
}
