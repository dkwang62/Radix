import SwiftUI

extension DataEditTab {
    var backupAndRestoreSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("iCloud Backup")
                    .font(ResponsiveFont.headline)
                Text("Plus")
                    .font(ResponsiveFont.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Text("Create a backup in iCloud Drive, then restore it on another iPhone, iPad, or Mac. Included with Radix Plus.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            myBackupVisibilityNote

            otherDeviceSavedStatusRow

            LazyVGrid(columns: backupActionColumns, spacing: 10) {
                Button {
                    guard !entitlement.requiresPro(.myBackup) else {
                        onRequirePro(.myBackup)
                        return
                    }
                    createPortableBackup()
                } label: {
                    DataBackupActionButton(
                        title: reuseExportInProgress && reuseExportFilename.contains("backup") ? "Preparing..." : "Back Up to iCloud",
                        subtitle: "Choose iCloud Drive",
                        systemName: "square.and.arrow.up.fill",
                        foreground: .white,
                        background: Color.accentColor,
                        border: Color.accentColor,
                        isLocked: entitlement.requiresPro(.myBackup)
                    )
                }
                .buttonStyle(.plain)
                .disabled(reuseExportInProgress)

                Button {
                    guard !entitlement.requiresPro(.myBackup) else {
                        onRequirePro(.myBackup)
                        return
                    }
                    pendingRestoreMode = .additive
                    showRestorePicker = true
                } label: {
                    DataBackupActionButton(
                        title: "Add From Backup",
                        subtitle: "Keep what is here",
                        systemName: "square.and.arrow.down",
                        foreground: Color.accentColor,
                        background: Color.accentColor.opacity(0.1),
                        border: Color.accentColor.opacity(0.35),
                        isLocked: entitlement.requiresPro(.myBackup)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    guard !entitlement.requiresPro(.myBackup) else {
                        onRequirePro(.myBackup)
                        return
                    }
                    pendingRestoreMode = .complete
                    showRestorePicker = true
                } label: {
                    DataBackupActionButton(
                        title: "Restore Backup",
                        subtitle: "Replace this device",
                        systemName: "square.and.arrow.down.fill",
                        foreground: Color.orange,
                        background: Color.orange.opacity(0.1),
                        border: Color.orange.opacity(0.35),
                        isLocked: entitlement.requiresPro(.myBackup)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(RadixTheme.secondaryBackground.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    var myBackupVisibilityNote: some View {
        if entitlement.requiresPro(.myBackup) {
            Label("You can preview backup contents for free. Creating and restoring iCloud backups unlocks with Radix Plus.", systemImage: "lock.open")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RadixTheme.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    var otherDeviceSavedStatusRow: some View {
        let hasSavedFile = lastOtherDeviceBackupMetadata.hasBackup
        let fileURL = URL(fileURLWithPath: lastOtherDeviceBackupMetadata.path)
        let filename = fileURL.lastPathComponent
        let relativeText = hasSavedFile
            ? LocalDataSnapshot.relativeText(for: Date(timeIntervalSince1970: lastOtherDeviceBackupMetadata.timestamp))
            : nil

        return HStack(spacing: 10) {
            Image(systemName: hasSavedFile ? "checkmark.circle.fill" : "externaldrive")
                .foregroundStyle(hasSavedFile ? Color.green : Color.secondary)

            Text(hasSavedFile ? "Last iCloud backup: \(filename) \(relativeText ?? "")." : "No iCloud backup created yet.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(hasSavedFile ? Color.green : Color.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(hasSavedFile ? Color.green.opacity(0.1) : RadixTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    func createPortableBackup() {
        guard !entitlement.requiresPro(.myBackup) else {
            onRequirePro(.myBackup)
            return
        }
        reuseExportInProgress = true
        reuseExportMessage = nil
        Task { @MainActor in
            do {
                let data = try dataExportService.exportPortableBackup(store.portableBackupPackage())
                reuseExportDocument = BinaryFileDocument(data: data)
                reuseExportFilename = "radix_icloud_backup"
                reuseExportContentType = RadixFileTypes.json
                reuseExportInProgress = false
                showReuseExporter = true
            } catch {
                reuseExportInProgress = false
                backupError = error.localizedDescription
                showBackupAlert = true
            }
        }
    }
}
