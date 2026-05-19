import SwiftUI

extension RootView {
    var hasOtherDevicesMemoryAccess: Bool {
        !entitlement.requiresPro(.myBackup)
    }

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
                let latestSnapshotTitle = snapshots.first?.title ?? "now"
                let fileMessage = hasOtherDevicesMemoryAccess
                    ? try replaceLastOtherDeviceFileIfPossible(with: data)
                    : "Saved on this device."

                importExportMessage = "Saved dated copy: \(latestSnapshotTitle). \(fileMessage)"
                showImportExportAlert = true
                isQuickSavingMemory = false
            } catch {
                importExportError = error.localizedDescription
                isQuickSavingMemory = false
            }
        }
    }

    func quickRestoreMemory() {
        guard !isQuickRestoringMemory else { return }
        guard hasDatedCopiesMemoryAccess else {
            presentPaywall(for: .datedCopies)
            return
        }
        isQuickRestoringMemory = true

        Task { @MainActor in
            do {
                let source = try quickRestoreMemorySource()
                try store.importDataEditData(source.data, mode: .complete)
                importExportMessage = "Restored memory from: \(source.name)"
                showImportExportAlert = true
                isQuickRestoringMemory = false
            } catch {
                importExportError = error.localizedDescription
                isQuickRestoringMemory = false
            }
        }
    }

    private func quickRestoreMemorySource() throws -> (data: Data, name: String) {
        if hasOtherDevicesMemoryAccess {
            let url = try lastOtherDeviceBackupURL()
            return (try Data(contentsOf: url), url.lastPathComponent)
        }

        let snapshot = try latestLocalSnapshot()
        return (try localSnapshotStore.data(for: snapshot), snapshot.title)
    }

    private func replaceLastOtherDeviceFileIfPossible(with data: Data) throws -> String {
        let cleanPath = lastOtherDeviceBackupPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPath.isEmpty else {
            return "No previous device file to replace."
        }

        let url = URL(fileURLWithPath: cleanPath)
        try data.write(to: url, options: .atomic)
        lastOtherDeviceBackupDate = Date().timeIntervalSince1970
        return "Replaced last file: \(url.lastPathComponent)."
    }

    private func latestLocalSnapshot() throws -> LocalDataSnapshot {
        guard let snapshot = try localSnapshotStore.snapshots().first else {
            throw NSError(domain: "Radix", code: 2, userInfo: [NSLocalizedDescriptionKey: "No dated copy is available yet. Save Memory first."])
        }

        return snapshot
    }

    private func lastOtherDeviceBackupURL() throws -> URL {
        let cleanPath = lastOtherDeviceBackupPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPath.isEmpty else {
            throw NSError(domain: "Radix", code: 1, userInfo: [NSLocalizedDescriptionKey: "No last saved file is available yet. Save an Other Devices file first."])
        }

        return URL(fileURLWithPath: cleanPath)
    }
}
