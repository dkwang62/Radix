import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DataBackupPreviewSection: View {
    @EnvironmentObject private var store: RadixStore
    @State private var selectedPhrase: PhraseItem?

    let addedPhraseEntries: [PhraseItem]
    let editedPhraseEntries: [PhraseItem]
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
                    backupCharacterRows(store.addedDictionaryCharacters, badge: "Added")
                }

                DisclosureGroup("Added Phrases (\(addedPhraseEntries.count))", isExpanded: $showAddedPhrasesPreview) {
                    backupPhraseRows(addedPhraseEntries, badge: "Added")
                }

                DisclosureGroup("Characters With Notes (\(store.editedDictionaryCharacters.count))", isExpanded: $showEditedCharactersPreview) {
                    backupCharacterRows(store.editedDictionaryCharacters, badge: "Notes Added")
                }

                DisclosureGroup("Edited Phrases (\(editedPhraseEntries.count))", isExpanded: $showEditedPhrasesPreview) {
                    backupPhraseRows(editedPhraseEntries, badge: "Edited")
                }

            }
            .padding(12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(item: $selectedPhrase) { phrase in
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

    @ViewBuilder
    private func backupCharacterRows(_ characters: [String], badge: String) -> some View {
        let displayed = Array(characters.prefix(80))
        let truncated = characters.count > displayed.count

        VStack(alignment: .leading, spacing: 8) {
            if characters.isEmpty {
                Text("No matching characters.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(displayed, id: \.self) { character in
                        let item = store.item(for: character)
                        backupCharacterRow(character, badge: badge, item: item)
                    }
                }

                if truncated {
                    Text("Showing the first \(displayed.count) of \(characters.count) characters.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func backupCharacterRow(_ character: String, badge: String, item: ComponentItem?) -> some View {
        let pinyin = item?.pinyinText ?? ""
        let definition = item?.definition ?? ""
        let isBuiltInCharacter = store.editedDictionaryCharactersSet.contains(character)

        HStack(alignment: .top, spacing: 10) {
            Text(character)
                .font(ResponsiveFont.title3.bold())
                .copyCharacterContextMenu(character, pinyin: pinyin)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 2) {
                if !pinyin.isEmpty {
                    Text(pinyin)
                        .font(ResponsiveFont.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Text(definition.isEmpty ? "No definition" : definition)
                    .font(ResponsiveFont.caption)
                    .lineLimit(2)
            }

            Spacer()

            HStack(spacing: 6) {
                Button(store.characterNotesActionTitle(for: character)) {
                    store.openQuickCharacterEditor(character)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                Button(role: isBuiltInCharacter ? nil : .destructive) {
                    if isBuiltInCharacter {
                        store.restoreDictionaryCharacterFromLibrary(character)
                    } else {
                        store.loadDataEditEntry(for: character)
                        try? store.deleteCurrentDataEditEntry()
                    }
                } label: {
                    Text(isBuiltInCharacter ? "Revert" : "Delete")
                        .font(ResponsiveFont.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded {
            onPreviewCharacter(character)
        })
    }

    @ViewBuilder
    private func backupPhraseRows(_ phrases: [PhraseItem], badge: String) -> some View {
        if phrases.isEmpty {
            Text("No matching phrases.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        } else {
            LazyVGrid(columns: backupPhraseColumns, alignment: .leading, spacing: 8) {
                ForEach(phrases) { phrase in
                    backupPhraseRow(phrase, badge: badge)
                }
            }
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func backupPhraseRow(_ phrase: PhraseItem, badge: String) -> some View {
        Button {
            presentPhrase(phrase)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                PhraseSummaryTile(phrase: phrase)
                Text(badge)
                    .font(ResponsiveFont.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
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

    private var isPhone: Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        return UIDevice.current.userInterfaceIdiom == .phone
        #endif
    }

    private func presentPhrase(_ phrase: PhraseItem) {
        store.speakPhrase(phrase)
        selectedPhrase = phrase
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
