import SwiftUI

extension DataEditTab {
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

                try createRecoverySnapshotIfNeeded()

                restorePhase = .restoring
                try store.importDataEditPayload(payload, mode: pendingRestoreMode)
                guard isCurrentRestore(operationID) else { return }

                let modeLabel = pendingRestoreMode == .complete
                    ? "Restored this device"
                    : "Amalgamated backup data"
                backupMessage = "\(modeLabel) from: \(url.lastPathComponent)"
                finishBackupRestore(operationID: operationID)
                showBackupAlert = true
            } catch {
                guard isCurrentRestore(operationID) else { return }
                finishBackupRestore(operationID: operationID)
                presentBackupError(error.localizedDescription)
            }
        }
    }

    private func createRecoverySnapshotIfNeeded() throws {
        guard pendingRestoreMode == .complete else { return }
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
