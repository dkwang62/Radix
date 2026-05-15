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
            BackupSummaryLine(title: "Shared instructions", value: "4 sections")
            BackupSummaryLine(title: "Instruction items", value: "\(store.promptConfig.tasks.count)")
            BackupSummaryLine(title: "Selected instructions", value: "\(store.promptSelectedTaskIDs.count)")

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
            BackupSummaryLine(title: "Selected saved page", value: store.selectedAICollection?.name ?? "None")
            BackupSummaryLine(title: "Default AI", value: store.defaultAIName)
            BackupSummaryLine(title: "API keys", value: "\(store.currentAPIKeyBackup().savedCount) saved")
            if store.defaultAIPreset == .custom {
                BackupSummaryLine(title: "Custom AI URL", value: store.defaultAIBaseURLString.isEmpty ? "None" : store.defaultAIBaseURLString)
            }
            BackupSummaryLine(title: "Search history", value: "\(store.searchHistory.count) items")
            BackupSummaryLine(title: "Remembered trail", value: "\(store.rootBreadcrumb.count) items")
            BackupSummaryLine(title: "Phrase length", value: store.activePhraseLengthFilterLabel)
        }
        .padding(.top, 8)
    }

    func routeDisplayName(_ route: AppRoute) -> String {
        switch route {
        case .search: return "Search"
        case .capture: return "Scan"
        case .lineage: return "Character Breakdown"
        case .aiLink: return "AI Link"
        case .favourites: return "Study"
        }
    }

    func homeTabDisplayName(_ tab: HomeTab) -> String {
        switch tab {
        case .smart: return "Search"
        case .filter: return "Browse"
        case .favourites: return "Study"
        case .dataEdit: return "My Data"
        }
    }
}
