import SwiftUI

extension DataBackupPreviewSection {
    var backupFavoritesSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            BackupSummaryLine(title: "Favorite characters", value: "\(store.favoriteItems.count)")
            if !store.favoriteItems.isEmpty {
                Text(store.favoriteItems.map(\.character).joined(separator: " "))
                    .font(ResponsiveFont.caption)
            }

            BackupSummaryLine(title: "Favorite phrases", value: "\(store.favoritePhrasesItems.count)")
            if !store.favoritePhrasesItems.isEmpty {
                LazyVGrid(columns: backupPhraseColumns, alignment: .leading, spacing: 8) {
                    ForEach(store.favoritePhrasesItems) { phrase in
                        BackupPhraseRow(phrase: phrase) {
                            presentPhrase(phrase)
                        }
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    var backupAITemplatesSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            BackupSummaryLine(title: "Template blocks", value: "4 system sections")
            BackupSummaryLine(title: "Prompt tasks", value: "\(store.promptConfig.tasks.count)")
            BackupSummaryLine(title: "Selected tasks", value: "\(store.promptSelectedTaskIDs.count)")

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

    var backupAppStateSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            BackupSummaryLine(title: "Current route", value: routeDisplayName(store.route))
            BackupSummaryLine(title: "Home tab", value: homeTabDisplayName(store.homeTab))
            BackupSummaryLine(title: "Search mode", value: store.searchMode.rawValue)
            BackupSummaryLine(title: "Current query", value: store.query.isEmpty ? "None" : store.query)
            BackupSummaryLine(title: "Selected character", value: store.previewCharacter ?? "None")
            BackupSummaryLine(title: "Selected AI image", value: store.selectedAICollection?.name ?? "None")
            BackupSummaryLine(title: "Default AI", value: store.defaultAIName)
            if store.defaultAIPreset == .custom {
                BackupSummaryLine(title: "Custom AI URL", value: store.defaultAIBaseURLString.isEmpty ? "None" : store.defaultAIBaseURLString)
            }
            BackupSummaryLine(title: "Search history", value: "\(store.searchHistory.count) items")
            BackupSummaryLine(title: "Remembered trail", value: "\(store.rootBreadcrumb.count) items")
            BackupSummaryLine(title: "Phrase length", value: "\(store.phraseLength)-character")
        }
        .padding(.top, 8)
    }

    func routeDisplayName(_ route: AppRoute) -> String {
        switch route {
        case .search: return "Search"
        case .capture: return "Capture"
        case .lineage: return "Components"
        case .aiLink: return "AI Link"
        case .favourites: return "Favorites"
        }
    }

    func homeTabDisplayName(_ tab: HomeTab) -> String {
        switch tab {
        case .smart: return "Smart Search"
        case .filter: return "Filter"
        case .favourites: return "Favorites"
        case .dataEdit: return "DataEdit"
        }
    }
}
