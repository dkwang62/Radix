import SwiftUI

extension DataEditTab {
    @ViewBuilder
    var backupAndRestoreSection: some View {
        compactPhoneBackupAndRestoreSection
    }

    var fullBackupAndRestoreSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Portable Backup")
                    .font(ResponsiveFont.headline)
                Text("Plus")
                    .font(ResponsiveFont.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Text("Save a portable backup, then merge or restore it on another iPhone, iPad, or Mac. Included with Radix Plus.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            myBackupVisibilityNote

            otherDeviceSavedStatusRow

            LazyVGrid(columns: backupActionColumns, spacing: 10) {
                backupToiCloudButton
                addFromBackupButton
                restoreBackupButton
            }
        }
        .padding()
        .background(RadixTheme.secondaryBackground.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var compactPhoneBackupAndRestoreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            otherDeviceSavedStatusRow

            myBackupVisibilityNote

            compactBackupContentsDisclosure
        }
        .padding(12)
        .background(RadixTheme.secondaryBackground.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var compactPhoneBackupActionBar: some View {
        VStack(spacing: 8) {
            backupToiCloudButton

            LazyVGrid(columns: pairedBackupActionColumns, spacing: 8) {
                addFromBackupButton
                restoreBackupButton
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    var backupToiCloudButton: some View {
        Button {
            guard !entitlement.requiresPro(.myBackup) else {
                onRequirePro(.myBackup)
                return
            }
            createPortableBackup()
        } label: {
            DataBackupActionButton(
                title: reuseExportInProgress && reuseExportFilename.contains("backup") ? "Preparing..." : "Save Backup",
                subtitle: "Choose where to save",
                systemName: "square.and.arrow.up.fill",
                foreground: .white,
                background: Color.accentColor,
                border: Color.accentColor,
                isLocked: entitlement.requiresPro(.myBackup)
            )
        }
        .buttonStyle(.plain)
        .disabled(reuseExportInProgress)
    }

    var addFromBackupButton: some View {
        Button {
            guard !entitlement.requiresPro(.myBackup) else {
                onRequirePro(.myBackup)
                return
            }
            pendingRestoreMode = .additive
            showRestorePicker = true
        } label: {
            DataBackupActionButton(
                title: "Merge Backup",
                subtitle: "Keep existing data",
                systemName: "square.and.arrow.down",
                foreground: Color.accentColor,
                background: Color.accentColor.opacity(0.1),
                border: Color.accentColor.opacity(0.35),
                isLocked: entitlement.requiresPro(.myBackup)
            )
        }
        .buttonStyle(.plain)
    }

    var restoreBackupButton: some View {
        Button {
            guard !entitlement.requiresPro(.myBackup) else {
                onRequirePro(.myBackup)
                return
            }
            pendingRestoreMode = .complete
            showRestorePicker = true
        } label: {
            DataBackupActionButton(
                title: "Replace My Data",
                subtitle: "Restore this backup",
                systemName: "square.and.arrow.down.fill",
                foreground: Color.orange,
                background: Color.orange.opacity(0.1),
                border: Color.orange.opacity(0.35),
                isLocked: entitlement.requiresPro(.myBackup)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    var myBackupVisibilityNote: some View {
        if entitlement.requiresPro(.myBackup) {
            Label("You can preview contents for free. Saving and restoring backups unlocks with Radix Plus.", systemImage: "lock.open")
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

            Text(hasSavedFile ? "Last backup created: \(filename) \(relativeText ?? "")." : "No backup created yet.")
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
