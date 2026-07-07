import SwiftUI

enum DataEditSection: String, CaseIterable, Identifiable {
    case myBackup = "Backup File"
    case advanced = "Advanced Exports"

    var id: String { rawValue }
}

private extension DataEditTab {
    var dataEditContentMaxWidth: CGFloat {
        RadixPlatform.isDesktop ? 920 : 680
    }
}

struct PendingBackupRestore: Identifiable {
    let id = UUID()
    let payload: PortableBackupPayload
    let filename: String
    let mode: RestoreMode
}

enum BackupRestorePhase: Equatable {
    case idle
    case acquiringFile
    case validating
    case restoring

    var message: String {
        switch self {
        case .idle: return ""
        case .acquiringFile: return "Downloading and opening backup…"
        case .validating: return "Checking compatibility…"
        case .restoring: return "Updating Radix data…"
        }
    }

    var isActive: Bool { self != .idle }
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
    @State var restorePhase: BackupRestorePhase = .idle
    @State var restoreOperationID: UUID?
    @State var pendingBackupRestore: PendingBackupRestore?

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
    @State var recentBackupMetadata = RadixBackupMetadataStore.history
    @State var activeZipExportKind: AdvancedZipExportKind = .xcodeDataFiles
    @State var activeAdvancedExportKind: AdvancedExportKind = .fullDataset
    @State var advancedToolsTip: AdvancedExportToolsTip?
    let dataExportService = DataExportService()
    let localSnapshotStore = LocalDataSnapshotStore()

    @State var editorMessage: String?
    @State var editorError: String?

    @State var showAddedCharactersPreview = false
    @State var showEditedCharactersPreview = false
    @State var showEditedPhrasesPreview = false
    @State var showSavedPagesPreview = false
    @State var showFavoritesPreview = false
    @State var showAITemplatesPreview = false
    @State var showPracticePreview = false
    @State var showAppStatePreview = false
    @State var showBackupContentsDetails = false

    @State var activeDataEditSection: DataEditSection = .myBackup
    @State var dataEditScrollProxy: ScrollViewProxy?

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                myDataHeader
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .background(RadixTheme.background)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Color.clear.frame(height: 0).id("myDataTop")

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
                    .frame(maxWidth: dataEditContentMaxWidth, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
            .alert(
                restoreConfirmationTitle,
                isPresented: Binding(
                    get: { pendingBackupRestore != nil },
                    set: { if !$0 { pendingBackupRestore = nil } }
                )
            ) {
                Button("Cancel", role: .cancel) {
                    pendingBackupRestore = nil
                }
                Button(
                    restoreConfirmationButtonTitle,
                    role: pendingBackupRestore?.mode == .complete ? .destructive : nil
                ) {
                    confirmPendingBackupRestore()
                }
            } message: {
                Text(restoreConfirmationMessage)
            }
            .overlay { backupRestoreOverlay }
            .onAppear {
                dataEditScrollProxy = proxy
                lastOtherDeviceBackupMetadata = RadixBackupMetadataStore.latest
                recentBackupMetadata = RadixBackupMetadataStore.history
            }
        }
    }

    func handleReuseExportSuccess(_ url: URL) {
        let base = url.deletingPathExtension().lastPathComponent
        if RadixFileTypes.isJSON(reuseExportContentType) && reuseExportFilename == "radix_icloud_backup" {
            lastOtherDeviceBackupMetadata = RadixBackupMetadataStore.recordBackup(at: url)
            recentBackupMetadata = RadixBackupMetadataStore.history
            backupMessage = "Created backup: \(url.lastPathComponent)"
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

}
