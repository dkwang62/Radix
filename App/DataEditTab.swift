import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import UniformTypeIdentifiers

enum DataEditSection: String, CaseIterable, Identifiable {
    case library = "Memory"
    case localBackup = "This Device"
    case myBackup = "Other Devices"
    case advanced = "Advanced"

    var id: String { rawValue }
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
    @State var reuseExportContentType: UTType = .json
    @State var showReuseExporter = false
    @State var reuseExportInProgress = false
    @State var reuseExportMessage: String?
    @AppStorage("dataEditLastOtherDeviceBackupPath") var lastOtherDeviceBackupPath = ""
    @AppStorage("dataEditLastOtherDeviceBackupDate") var lastOtherDeviceBackupDate = 0.0
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
    @State var showAddedPhrasesPreview = false
    @State var showEditedPhrasesPreview = false
    @State var showSavedPagesPreview = false
    @State var showFavoritesPreview = false
    @State var showAITemplatesPreview = false
    @State var showAppStatePreview = false
    @State var showDeleteAddedPhrasesConfirmation = false
    @State var showAddedPhraseReview = false

    @State var activeDataEditSection: DataEditSection = .library
    @State var showHelp = false
    @State var dataEditScrollProxy: ScrollViewProxy?

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                myDataHeader
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                    .background(Color(.systemBackground))
                    .overlay(alignment: .bottom) {
                        Divider()
                    }
                    .zIndex(1)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Color.clear.frame(height: 0).id("myDataTop")

                        #if !targetEnvironment(macCatalyst)
                        if UIDevice.current.userInterfaceIdiom == .phone {
                            activeCharacterContext
                        }
                        #endif

                        switch activeDataEditSection {
                        case .library:
                            libraryOverviewSection
                        case .localBackup:
                            localSnapshotsSection
                        case .myBackup:
                            backupAndRestoreSection
                        case .advanced:
                            premiumExportsSection
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
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
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
            .alert("Delete Added Phrases?", isPresented: $showDeleteAddedPhrasesConfirmation) {
                Button("Delete All", role: .destructive) {
                    deleteAllAddedPhrases()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This removes every phrase you added from Memory. Built-in phrases and phrase notes on built-in phrases are kept.")
            }
            .sheet(isPresented: $showAddedPhraseReview) {
                AddedPhraseReviewSheet()
                    .environmentObject(store)
            }
            .onAppear {
                dataEditScrollProxy = proxy
                refreshLocalSnapshots()
            }
            .onChange(of: activeDataEditSection) { _, _ in
                refreshLocalSnapshots()
            }
        }
    }

    func handleReuseExportSuccess(_ url: URL) {
        let base = url.deletingPathExtension().lastPathComponent
        if reuseExportContentType == .json && reuseExportFilename == "radix_unified_backup" {
            lastOtherDeviceBackupPath = url.path
            lastOtherDeviceBackupDate = Date().timeIntervalSince1970
            backupMessage = "Saved file: \(url.lastPathComponent)"
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
            let modeLabel = pendingRestoreMode == .complete ? "Replaced this device's data" : "Added data to this device"
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
