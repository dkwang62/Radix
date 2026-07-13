import SwiftUI

extension DataEditTab {
    var databaseOptimizationStatusRow: some View {
        HStack(spacing: 10) {
            if store.databaseOptimizationInProgress {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(RadixAccent.primary)
            }

            Text(store.databaseOptimizationMessage ?? "Optimization complete.")
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RadixAccent.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    var backupRestoreOverlay: some View {
        if restorePhase.isActive {
            ZStack {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()

                VStack(spacing: 14) {
                    ProgressView()
                    Text(restorePhase.message)
                        .font(ResponsiveFont.body.weight(.semibold))
                    Text("Radix will stop waiting automatically if the file cannot be read.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Cancel Restore", role: .cancel) {
                        cancelBackupRestore(message: "Restore cancelled. Your existing data was not replaced.")
                    }
                }
                .padding(24)
                .frame(maxWidth: 340)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 12)
                .padding()
            }
        }
    }

    func restoreBackup(from result: Result<[URL], Error>) {
        guard !entitlement.requiresPro(.myBackup) else {
            onRequirePro(.myBackup)
            return
        }

        let url: URL
        do {
            guard let selectedURL = try result.get().first else { return }
            url = selectedURL
        } catch {
            presentBackupError(error.localizedDescription)
            return
        }

        let operationID = UUID()
        restoreOperationID = operationID
        restorePhase = .acquiringFile
        backupError = nil

        // Begin access synchronously while the document-picker URL is active.
        // Waiting until the asynchronous task starts can lose iPhone access to
        // an otherwise valid iCloud file.
        let accessed = url.startAccessingSecurityScopedResource()
        runBackupRestore(url: url, accessed: accessed, operationID: operationID)
        scheduleBackupAcquisitionTimeout(operationID: operationID)
    }

    func restoreBackup(_ metadata: RadixBackupMetadata, mode: RestoreMode) {
        guard !entitlement.requiresPro(.myBackup) else {
            onRequirePro(.myBackup)
            return
        }

        pendingRestoreMode = mode
        let url = URL(fileURLWithPath: metadata.path)
        guard RadixBackupMetadataStore.isReadable(metadata) else {
            editorMessage = "Choose \(url.lastPathComponent) again to \(mode == .complete ? "replace this device" : "merge backup data")."
            showRestorePicker = true
            return
        }

        let operationID = UUID()
        restoreOperationID = operationID
        restorePhase = .acquiringFile
        backupError = nil

        let accessed = url.startAccessingSecurityScopedResource()
        runBackupRestore(url: url, accessed: accessed, operationID: operationID)
        scheduleBackupAcquisitionTimeout(operationID: operationID)
    }

    private func runBackupRestore(url: URL, accessed: Bool, operationID: UUID) {
        Task { @MainActor in
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            do {
                let data = try await Task.detached(priority: .userInitiated) {
                    try DataExportService().readPortableBackup(at: url)
                }.value
                guard isCurrentRestore(operationID) else { return }

                restorePhase = .validating
                let payload = try PortableBackupCodec().decode(data)
                guard isCurrentRestore(operationID) else { return }
                if pendingRestoreMode == .additive {
                    try await mergeBackupFile(url: url, payload: payload, operationID: operationID)
                    return
                }
                finishBackupRestore(operationID: operationID)
                pendingBackupRestore = PendingBackupRestore(
                    payload: payload,
                    filename: url.lastPathComponent,
                    mode: pendingRestoreMode
                )
            } catch {
                guard isCurrentRestore(operationID) else { return }
                finishBackupRestore(operationID: operationID)
                presentBackupError(error.localizedDescription)
            }
        }
    }

    private func mergeBackupFile(
        url: URL,
        payload: PortableBackupPayload,
        operationID: UUID
    ) async throws {
        restorePhase = .restoring
        try await store.importDataEditPayloadForRestore(payload, mode: .additive)
        guard isCurrentRestore(operationID) else { return }

        let mergedData = try dataExportService.exportPortableBackup(store.portableBackupPackage())
        try await Task.detached(priority: .userInitiated) {
            try DataExportService().writePortableBackup(mergedData, to: url)
        }.value
        guard isCurrentRestore(operationID) else { return }

        lastOtherDeviceBackupMetadata = RadixBackupMetadataStore.recordBackup(at: url)
        recentBackupMetadata = RadixBackupMetadataStore.history
        backupMessage = "Merged Radix memory with: \(url.lastPathComponent). Radix is optimizing in the background."
        finishBackupRestore(operationID: operationID)
        showBackupAlert = true
        RadixHaptics.success()
    }

    var restoreConfirmationTitle: String {
        pendingBackupRestore?.mode == .complete ? "Restore from Backup?" : "Merge Backup?"
    }

    var restoreConfirmationButtonTitle: String {
        pendingBackupRestore?.mode == .complete ? "Wipe and Restore" : "Merge Backup"
    }

    var restoreConfirmationMessage: String {
        guard let pending = pendingBackupRestore else { return "" }
        let action = pending.mode == .complete
            ? "This will replace memory with the selected file. Radix will save a recovery checkpoint first, but Merge Backup is safer unless you need an exact file restore."
            : "Radix will combine the file and memory so both contain the merged contents."
        return "Selected: \(pending.filename)\n\n\(pending.payload.contentsSummary)\n\n\(action)"
    }

    func confirmPendingBackupRestore() {
        guard let pending = pendingBackupRestore else { return }
        pendingBackupRestore = nil

        let operationID = UUID()
        restoreOperationID = operationID
        restorePhase = .restoring

        Task { @MainActor in
            do {
                if pending.mode == .complete {
                    try createRecoverySnapshotIfNeeded(for: pending.mode)
                }
                try await store.importDataEditPayloadForRestore(pending.payload, mode: pending.mode)
                guard isCurrentRestore(operationID) else { return }

                backupMessage = pending.mode == .complete
                    ? "Restored Radix memory from: \(pending.filename). Radix is optimizing in the background."
                    : "Merged backup data from: \(pending.filename). Radix is optimizing in the background."
                finishBackupRestore(operationID: operationID)
                showBackupAlert = true
                RadixHaptics.success()
            } catch {
                guard isCurrentRestore(operationID) else { return }
                finishBackupRestore(operationID: operationID)
                presentBackupError(error.localizedDescription)
                RadixHaptics.error()
            }
        }
    }

    private func createRecoverySnapshotIfNeeded(for mode: RestoreMode) throws {
        guard mode == .complete else { return }
        let recoveryData = try dataExportService.exportPortableBackup(store.portableBackupPackage())
        _ = try localSnapshotStore.save(recoveryData)
    }

    private func scheduleBackupAcquisitionTimeout(operationID: UUID) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(120))
            guard isCurrentRestore(operationID), restorePhase != .restoring else { return }
            cancelBackupRestore(
                message: "Radix stopped waiting because the selected iCloud file did not become available within two minutes. Your existing data was not replaced."
            )
        }
    }

    private func isCurrentRestore(_ operationID: UUID) -> Bool {
        restoreOperationID == operationID
    }

    private func finishBackupRestore(operationID: UUID) {
        guard isCurrentRestore(operationID) else { return }
        restoreOperationID = nil
        restorePhase = .idle
    }

    func cancelBackupRestore(message: String) {
        guard restoreOperationID != nil else { return }
        restoreOperationID = nil
        restorePhase = .idle
        presentBackupError(message)
    }

    private func presentBackupError(_ message: String) {
        backupError = message
        showBackupAlert = true
    }
}

private extension PortableBackupPayload {
    var contentsSummary: String {
        switch self {
        case .unified(let package):
            let pageCount = package.collections?.count ?? 0
            let characterCount = package.dictionaryPatchOverlay.map { $0.customEntries.count + $0.patches.count + $0.deletions.count }
                ?? package.dictionaryOverlay?.upserts.count
                ?? package.dictionary?.count
                ?? 0
            return "Contains \(characterCount) character changes, \(package.phrases.count) phrases, and \(pageCount) saved pages."
        case .legacyDictionary(let dictionary):
            return "Contains \(dictionary.count) dictionary characters from an older Radix backup."
        }
    }
}
