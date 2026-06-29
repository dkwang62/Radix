import SwiftUI

extension DataBackupPreviewSection {
    var backupPracticeSummary: some View {
        let importedPacks = RadixStudyPreferences.importedConversationPracticePacks

        return VStack(alignment: .leading, spacing: 8) {
            BackupSummaryLine(title: "Selected topic", value: store.selectedConversationPracticeTopic.title)
            BackupSummaryLine(title: "Built-in topics", value: "\(ConversationPracticeTopic.defaults.count)")
            BackupSummaryLine(title: "Imported practice packs", value: "\(importedPacks.count)")

            if !importedPacks.isEmpty {
                ForEach(importedPacks, id: \.packID) { pack in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(pack.title)
                            .font(ResponsiveFont.caption)
                        Spacer(minLength: 0)
                        Text("\(pack.entries.count) sentences")
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.top, 8)
    }

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
            BackupSummaryLine(title: "Saved AI Link buttons", value: "\(store.promptConfig.tasks.count)")
            BackupSummaryLine(title: "Buttons turned on", value: "\(store.promptSelectedTaskIDs.count)")

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
            BackupSummaryLine(title: "Current screen", value: store.route.rawValue.capitalized)
            BackupSummaryLine(title: "Last character opened", value: store.previewCharacter ?? "None")
            BackupSummaryLine(title: "Current search", value: store.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "None" : store.query)
            BackupSummaryLine(title: "Search mode", value: store.searchMode.rawValue.capitalized)
            BackupSummaryLine(title: "Script choice", value: store.scriptFilter.rawValue.capitalized)
            BackupSummaryLine(title: "Sidebar buttons", value: store.sidebarNavigationStyle.displayName)
            BackupSummaryLine(title: "Chosen AI app", value: store.defaultAIName)
            BackupSummaryLine(title: "Saved AI keys", value: "\(store.currentAPIKeyBackup().savedCount)")
            if store.defaultAIPreset == .custom {
                BackupSummaryLine(title: "Custom AI URL", value: store.defaultAIBaseURLString.isEmpty ? "None" : store.defaultAIBaseURLString)
            }
            BackupSummaryLine(title: "Recent searches", value: "\(store.searchHistory.count)")
            BackupSummaryLine(title: "Remembered characters", value: "\(store.rootBreadcrumb.count)")
            BackupSummaryLine(title: "Phrase length choice", value: store.activePhraseLengthFilterLabel)
        }
        .padding(.top, 8)
    }

}
