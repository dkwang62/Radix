import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import UniformTypeIdentifiers

struct DataEditTab: View {
    @EnvironmentObject var store: RadixStore
    @EnvironmentObject var entitlement: EntitlementManager
    @Environment(\.horizontalSizeClass) var sizeClass
    let onLoadAddPhrases: () -> Void
    let onExportAddPhrases: () -> Void
    let onUseDefaultAddPhrases: () -> Void
    let onRequirePro: (EntitlementManager.FeatureGate) -> Void

    @State var showRestorePicker = false
    @State var pendingRestoreMode: RestoreMode = .additive
    @State var backupMessage: String?
    @State var backupError: String?
    @State var showBackupAlert = false

    @State var fullDatasetFileName: String = "radix_full_dataset"
    @State var mergedDictionaryFileName: String = "radix_merged_dictionary"
    @State var mergedPhrasesFileName: String = "radix_merged_phrases"
    @State var xcodeDataFilesFileName: String = "radix_xcode_data_files"
    @State var projectArchiveFileName: String = ProjectArchiveName.baseName()
    @State var reuseExportDocument = BinaryFileDocument(data: Data())
    @State var reuseExportFilename: String = ""
    @State var reuseExportContentType: UTType = .json
    @State var showReuseExporter = false
    @State var reuseExportInProgress = false
    @State var reuseExportMessage: String?
    @State var activeZipExportKind: AdvancedZipExportKind = .xcodeDataFiles
    @State var advancedToolsTip: AdvancedExportToolsTip?
    let dataExportService = DataExportService()

    @State var editorMessage: String?
    @State var editorError: String?

    @State var showAddedCharactersPreview = false
    @State var showEditedCharactersPreview = false
    @State var showAddedPhrasesPreview = false
    @State var showEditedPhrasesPreview = false
    @State var showSavedPagesPreview = false
    @State var showFavoritesPreview = false
    @State var showAITemplatesPreview = false
    @State var showAppStatePreview = false

    @State var showAdvancedExports = false
    @State var showHelp = false
    @State var dataEditScrollProxy: ScrollViewProxy?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Color.clear.frame(height: 0).id("myDataTop")

                    #if !targetEnvironment(macCatalyst)
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        activeCharacterContext
                    }
                    #endif

                    myDataHeader

                    if showAdvancedExports {
                        premiumExportsSection
                    } else {
                        backupAndRestoreSection
                        whatsInMyBackupSection
                    }

                    if let editorError {
                        Text(editorError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    if let editorMessage {
                        Text(editorMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .fileExporter(
                isPresented: $showReuseExporter,
                document: reuseExportDocument,
                contentType: reuseExportContentType,
                defaultFilename: reuseExportFilename
            ) { result in
                reuseExportInProgress = false
                switch result {
                case .success(let url):
                    handleReuseExportSuccess(url)
                case .failure(let error):
                    backupError = error.localizedDescription
                    showBackupAlert = true
                }
            }
            .fileImporter(
                isPresented: $showRestorePicker,
                allowedContentTypes: [.json, .data],
                allowsMultipleSelection: false
            ) { result in
                restoreBackup(from: result)
            }
            .alert("Backup / Restore", isPresented: $showBackupAlert) {
                Button("OK", role: .cancel) {
                    backupMessage = nil
                    backupError = nil
                }
            } message: {
                if let msg = backupError {
                    Text(msg)
                } else if let msg = backupMessage {
                    Text(msg)
                }
            }
            .onAppear { dataEditScrollProxy = proxy }
        }
    }

    func handleReuseExportSuccess(_ url: URL) {
        let base = url.deletingPathExtension().lastPathComponent
        if reuseExportContentType == .json && reuseExportFilename == "radix_unified_backup" {
            backupMessage = "Backup saved to: \(url.lastPathComponent)"
            showBackupAlert = true
        } else {
            reuseExportMessage = "Saved to: \(url.lastPathComponent)"
            if reuseExportContentType == .zipArchive {
                if activeZipExportKind == .projectArchive {
                    projectArchiveFileName = base
                } else {
                    xcodeDataFilesFileName = base
                }
            } else if reuseExportContentType == .json {
                fullDatasetFileName = base
            } else if reuseExportFilename.hasPrefix(mergedDictionaryFileName.isEmpty ? "radix_merged_dictionary" : mergedDictionaryFileName) {
                mergedDictionaryFileName = base
            } else {
                mergedPhrasesFileName = base
            }
        }
    }

    func restoreBackup(from result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            try store.importDataEditData(data, mode: pendingRestoreMode)
            let modeLabel = pendingRestoreMode == .complete ? "Complete restore" : "Additive restore"
            backupMessage = "\(modeLabel) from: \(url.lastPathComponent)"
            showBackupAlert = true
        } catch {
            backupError = error.localizedDescription
            showBackupAlert = true
        }
    }
}
