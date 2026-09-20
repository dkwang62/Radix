import SwiftUI

extension DataBackupPreviewSection {
    var backupPracticeSummary: some View {
        let importedPacks = RadixStudyPreferences.importedConversationPracticePacks

        return VStack(alignment: .leading, spacing: 8) {
            BackupSummaryLine(title: "Selected topic", value: store.selectedConversationPracticeTopic.title)
            BackupSummaryLine(title: "Built-in topics", value: "\(ConversationPracticeTopic.defaults.count)")
            BackupSummaryLine(title: "Imported practice packs", value: "\(importedPacks.count)")
            Text("Saved sentences use Study > Sentences > Transfer. They are kept out of normal backups so backup and restore stay fast.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

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

    func backupFavoritesSummary(characters: [ComponentItem], phrases: [PhraseItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            BackupSummaryLine(title: "Favorite characters", value: "\(characters.count)")
            if !characters.isEmpty {
                Text(characters.map(\.character).joined(separator: " "))
                    .font(ResponsiveFont.caption)
            }

            BackupSummaryLine(title: "Favorite phrases", value: "\(phrases.count)")
            if !phrases.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(backupPhraseRows(for: Array(phrases.prefix(80))).enumerated()), id: \.offset) { _, rowPhrases in
                        HStack(spacing: 8) {
                            ForEach(rowPhrases) { phrase in
                                BackupPhraseRow(phrase: phrase) {
                                    presentPhrase(phrase)
                                }
                            }

                            ForEach(0..<backupPhrasePlaceholderCount(for: rowPhrases), id: \.self) { _ in
                                Color.clear
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                        }
                    }
                }
                if phrases.count > 80 {
                    Text("Showing the first 80 of \(phrases.count) phrases.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
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
                BackupSummaryLine(title: "FreeLLMAPI URL", value: store.defaultAIBaseURLString.isEmpty ? "None" : store.defaultAIBaseURLString)
            }
            BackupSummaryLine(title: "Recent searches", value: "\(store.searchHistory.count)")
            BackupSummaryLine(title: "Remembered characters", value: "\(store.rootBreadcrumb.count)")
            BackupSummaryLine(title: "Phrase length choice", value: store.activePhraseLengthFilterLabel)
        }
        .padding(.top, 8)
    }

}
