import SwiftUI

extension RootView {
    var hasDatedCopiesMemoryAccess: Bool {
        !entitlement.requiresPro(.datedCopies)
    }

    func exportProfile() {
        if entitlement.requiresPro(.myBackup) {
            presentPaywall(for: .myBackup)
            return
        }
        do {
            profileExportDocument = JSONFileDocument(data: try store.exportProfileData())
            showProfileExporter = true
        } catch {
            importExportError = error.localizedDescription
        }
    }

    func importProfile() {
        if entitlement.requiresPro(.myBackup) {
            presentPaywall(for: .myBackup)
            return
        }
        showProfileImporter = true
    }

    func loadAddPhrases() {
        if entitlement.requiresPro(.advanced) {
            presentPaywall(for: .advanced)
            return
        }
        showAddPhrasesImporter = true
    }

    func exportAddPhrases() {
        if entitlement.requiresPro(.advanced) {
            presentPaywall(for: .advanced)
            return
        }
        do {
            addPhrasesExportDocument = AddPhrasesFileDocument(data: try store.exportAddPhrasesDB())
            showAddPhrasesExporter = true
        } catch {
            importExportError = error.localizedDescription
        }
    }

    func useDefaultAddPhrases() {
        if entitlement.requiresPro(.advanced) {
            presentPaywall(for: .advanced)
            return
        }
        do {
            try store.restoreDefaultAddPhrasesFile()
            importExportMessage = "Using the default phrases_add.db file."
            showImportExportAlert = true
        } catch {
            importExportError = error.localizedDescription
        }
    }

    func presentPaywall(for gate: EntitlementManager.FeatureGate) {
        store.showPaywall(for: gate)
    }

    func quickSaveMemory() {
        guard !isQuickSavingMemory else { return }
        guard hasDatedCopiesMemoryAccess else {
            presentPaywall(for: .datedCopies)
            return
        }
        isQuickSavingMemory = true

        Task { @MainActor in
            do {
                let data = try dataExportService.exportPortableBackup(store.portableBackupPackage())
                let snapshots = try localSnapshotStore.save(data)
                quickLocalSnapshots = snapshots
                let latestSnapshotTitle = snapshots.first?.title ?? "now"
                importExportMessage = "Saved locally: \(latestSnapshotTitle)."
                showImportExportAlert = true
                isQuickSavingMemory = false
            } catch {
                importExportError = error.localizedDescription
                isQuickSavingMemory = false
            }
        }
    }

    func quickRestoreMemory(from snapshot: LocalDataSnapshot? = nil) {
        guard !isQuickRestoringMemory else { return }
        guard hasDatedCopiesMemoryAccess else {
            presentPaywall(for: .datedCopies)
            return
        }
        isQuickRestoringMemory = true

        Task { @MainActor in
            do {
                let source = try quickRestoreMemorySource(snapshot: snapshot)
                try store.importDataEditData(source.data, mode: .complete)
                refreshQuickLocalSnapshots()
                importExportMessage = "Restored local snapshot: \(source.name)"
                showImportExportAlert = true
                isQuickRestoringMemory = false
            } catch {
                importExportError = error.localizedDescription
                isQuickRestoringMemory = false
            }
        }
    }

    func refreshQuickLocalSnapshots() {
        do {
            quickLocalSnapshots = try localSnapshotStore.snapshots()
        } catch {
            quickLocalSnapshots = []
        }
    }

    @ViewBuilder
    var restoreSnapshotMenuContent: some View {
        if quickLocalSnapshots.isEmpty {
            Text("No snapshots saved")
        } else {
            ForEach(quickLocalSnapshots) { snapshot in
                Button {
                    quickRestoreMemory(from: snapshot)
                } label: {
                    Label(snapshot.title, systemImage: "clock.arrow.circlepath")
                }
            }
        }

        Divider()

        Button {
            refreshQuickLocalSnapshots()
        } label: {
            Label("Refresh List", systemImage: "arrow.clockwise")
        }
    }

    private func quickRestoreMemorySource(snapshot: LocalDataSnapshot?) throws -> (data: Data, name: String) {
        let snapshot = try snapshot ?? latestLocalSnapshot()
        return (try localSnapshotStore.data(for: snapshot), snapshot.title)
    }

    private func latestLocalSnapshot() throws -> LocalDataSnapshot {
        guard let snapshot = try localSnapshotStore.snapshots().first else {
            throw NSError(domain: "Radix", code: 2, userInfo: [NSLocalizedDescriptionKey: "No local snapshot is available yet. Save Snapshot first."])
        }

        return snapshot
    }
}
