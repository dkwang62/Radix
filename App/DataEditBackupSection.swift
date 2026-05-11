import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension DataEditTab {
    var backupAndRestoreSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Button {
                    pendingRestoreMode = .additive
                    showRestorePicker = true
                } label: {
                    DataBackupActionButton(
                        title: "Additive Restore",
                        subtitle: "Keeps current data",
                        systemName: "square.and.arrow.down",
                        foreground: Color.accentColor,
                        background: Color.accentColor.opacity(0.1),
                        border: Color.accentColor.opacity(0.35)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    createPortableBackup()
                } label: {
                    DataBackupActionButton(
                        title: reuseExportInProgress && reuseExportFilename.contains("backup") ? "Preparing Backup..." : "Back Up My Data",
                        subtitle: "Exports your saved data",
                        systemName: "square.and.arrow.up.fill",
                        foreground: .white,
                        background: Color.accentColor,
                        border: Color.accentColor
                    )
                }
                .buttonStyle(.plain)
                .disabled(reuseExportInProgress)

                Button {
                    pendingRestoreMode = .complete
                    showRestorePicker = true
                } label: {
                    DataBackupActionButton(
                        title: "Complete Restore",
                        subtitle: "Replaces data",
                        systemName: "square.and.arrow.down.fill",
                        foreground: Color.orange,
                        background: Color.orange.opacity(0.1),
                        border: Color.orange.opacity(0.35)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    var whatsInMyBackupSection: some View {
        DataBackupPreviewSection(
            addedPhraseEntries: addedPhraseEntries,
            basePhraseCoreEditEntries: basePhraseCoreEditEntries,
            phraseEntriesWithNotes: phraseEntriesWithNotes,
            onPreviewCharacter: previewBackupCharacter,
            showSavedPagesPreview: $showSavedPagesPreview,
            showFavoritesPreview: $showFavoritesPreview,
            showAITemplatesPreview: $showAITemplatesPreview,
            showAppStatePreview: $showAppStatePreview,
            showAddedCharactersPreview: $showAddedCharactersPreview,
            showAddedPhrasesPreview: $showAddedPhrasesPreview,
            showEditedCharactersPreview: $showEditedCharactersPreview,
            showEditedPhrasesPreview: $showEditedPhrasesPreview
        )
    }

    func createPortableBackup() {
        reuseExportInProgress = true
        reuseExportMessage = nil
        Task { @MainActor in
            do {
                let data = try dataExportService.exportPortableBackup(store.portableBackupPackage())
                reuseExportDocument = BinaryFileDocument(data: data)
                reuseExportFilename = "radix_unified_backup"
                reuseExportContentType = .json
                reuseExportInProgress = false
                showReuseExporter = true
            } catch {
                reuseExportInProgress = false
                backupError = error.localizedDescription
                showBackupAlert = true
            }
        }
    }

    func previewBackupCharacter(_ character: String) {
        store.preview(character: character)
        #if !targetEnvironment(macCatalyst)
        if UIDevice.current.userInterfaceIdiom == .phone {
            withAnimation { dataEditScrollProxy?.scrollTo("myDataTop", anchor: .top) }
        }
        #endif
    }
}
