import SwiftUI

enum DataEditSection: String, CaseIterable, Identifiable {
    case myBackup = "iCloud Backup"
    case advanced = "Advanced Pro"

    var id: String { rawValue }
}

struct AddedPhraseReviewPresentation: Identifiable {
    let id = UUID()
}

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
    @State var reuseExportContentType = RadixFileTypes.json
    @State var showReuseExporter = false
    @State var reuseExportInProgress = false
    @State var reuseExportMessage: String?
    @State var lastOtherDeviceBackupMetadata = RadixBackupMetadataStore.latest
    @State var activeZipExportKind: AdvancedZipExportKind = .xcodeDataFiles
    @State var activeAdvancedExportKind: AdvancedExportKind = .fullDataset
    @State var advancedToolsTip: AdvancedExportToolsTip?
    let dataExportService = DataExportService()
    let localSnapshotStore = LocalDataSnapshotStore()
    @State var localSnapshots: [LocalDataSnapshot] = []

    @State var editorMessage: String?
    @State var editorError: String?

    @State var showAddedCharactersPreview = false
    @State var showEditedCharactersPreview = false
    @State var showEditedPhrasesPreview = false
    @State var showSavedPagesPreview = false
    @State var showFavoritesPreview = false
    @State var showAITemplatesPreview = false
    @State var showAppStatePreview = false
    @State var showBackupContentsDetails = false

    @State var activeDataEditSection: DataEditSection = .myBackup
    @State var showHelp = false
    @State var dataEditScrollProxy: ScrollViewProxy?

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Color.clear.frame(height: 0).id("myDataTop")

                        if !RadixPlatform.isPhone {
                            sharedMemorySaveSection
                        }

                        myDataHeader
                            .padding(12)
                            .background(RadixTheme.background)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        switch activeDataEditSection {
                        case .myBackup:
                            backupAndRestoreSection
                        case .advanced:
                            premiumExportsSection
                        }

                        if let editorError {
                            Text(editorError)
                                .font(ResponsiveFont.caption)
                                .foregroundStyle(.red)
                        }
                        if let editorMessage {
                            Text(editorMessage)
                                .font(ResponsiveFont.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .modifier(DataEditTransferModifier(
                reuseExportDocument: $reuseExportDocument,
                reuseExportContentType: $reuseExportContentType,
                reuseExportFilename: $reuseExportFilename,
                showReuseExporter: $showReuseExporter,
                showRestorePicker: $showRestorePicker,
                reuseExportInProgress: $reuseExportInProgress,
                backupError: $backupError,
                showBackupAlert: $showBackupAlert,
                onExportSuccess: handleReuseExportSuccess,
                onRestore: restoreBackup
            ))
            .alert("My Data", isPresented: $showBackupAlert) {
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
            .onAppear {
                dataEditScrollProxy = proxy
                lastOtherDeviceBackupMetadata = RadixBackupMetadataStore.latest
            }
        }
    }

    func handleReuseExportSuccess(_ url: URL) {
        let base = url.deletingPathExtension().lastPathComponent
        if RadixFileTypes.isJSON(reuseExportContentType) && reuseExportFilename == "radix_icloud_backup" {
            lastOtherDeviceBackupMetadata = RadixBackupMetadataStore.recordBackup(at: url)
            backupMessage = "Created iCloud backup: \(url.lastPathComponent)"
            showBackupAlert = true
        } else {
            reuseExportMessage = "Saved to: \(url.lastPathComponent)"
            if activeAdvancedExportKind == .projectArchive {
                projectArchiveFileName = base
            } else if activeAdvancedExportKind == .xcodeDataFiles {
                xcodeDataFilesFileName = base
            } else if activeAdvancedExportKind == .fullDataset {
                fullDatasetFileName = base
            } else if activeAdvancedExportKind == .dictionaryDatabase {
                mergedDictionaryFileName = base
            } else if activeAdvancedExportKind == .phraseDatabase {
                mergedPhrasesFileName = base
            }
        }
    }

    func restoreBackup(from result: Result<[URL], Error>) {
        guard !entitlement.requiresPro(.myBackup) else {
            onRequirePro(.myBackup)
            return
        }
        do {
            guard let url = try result.get().first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            try store.importDataEditData(data, mode: pendingRestoreMode)
            let modeLabel = pendingRestoreMode == .complete ? "Restored this device" : "Added backup data"
            backupMessage = "\(modeLabel) from: \(url.lastPathComponent)"
            showBackupAlert = true
        } catch {
            backupError = error.localizedDescription
            showBackupAlert = true
        }
    }

    func refreshLocalSnapshots() {
        do {
            localSnapshots = try localSnapshotStore.snapshots()
        } catch {
            backupError = error.localizedDescription
            showBackupAlert = true
        }
    }
}
