import SwiftUI

extension DataEditTab {
    @ViewBuilder
    var backupAndRestoreSection: some View {
        protectAndRecoverSection
    }

    var protectAndRecoverSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Protect & Recover", systemImage: "shield.lefthalf.filled")
                .font(ResponsiveFont.title3.weight(.bold))

            Text("Checkpoints let you undo changes on this device. Backup files protect or transfer your data between devices.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            checkpointActionsSection

            Divider()

            portableBackupActionsSection

            compactBackupContentsDisclosure
        }
        .padding(12)
        .background(RadixTheme.secondaryBackground.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    var checkpointActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("On This Device")
                .font(ResponsiveFont.headline)

            Text("Create a checkpoint before major edits, then return to it if you change your mind.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: pairedBackupActionColumns, spacing: 8) {
                createCheckpointButton
                returnToCheckpointButton
            }

            recentCheckpointStrip
        }
    }

    var portableBackupActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Backup File")
                    .font(ResponsiveFont.headline)
                Text("Plus")
                    .font(ResponsiveFont.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Text("Create a portable file, merge it without removing current work, or replace this device from it.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)

            myBackupVisibilityNote
            recentBackupStrip

            portableBackupActionButtons
        }
    }

    @ViewBuilder
    var portableBackupActionButtons: some View {
        if RadixPlatform.isPhone {
            VStack(spacing: 8) {
                backupToiCloudButton

                LazyVGrid(columns: pairedBackupActionColumns, spacing: 8) {
                    addFromBackupButton
                    restoreBackupButton
                }
            }
        } else {
            LazyVGrid(columns: backupActionColumns, spacing: 8) {
                backupToiCloudButton
                addFromBackupButton
                restoreBackupButton
            }
        }
    }

    var recentCheckpointStrip: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Latest Checkpoints")
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if checkpoints.isEmpty {
                emptyRecoveryRow("No checkpoints created yet.")
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(checkpoints.prefix(3))) { checkpoint in
                        Button {
                            pendingCheckpointReturn = checkpoint
                        } label: {
                            recoveryListRow(
                                title: checkpoint.title,
                                subtitle: "\(checkpoint.relativeSavedText) · \(checkpoint.subtitle)",
                                systemImage: "clock.arrow.circlepath",
                                trailingSystemImage: "arrow.counterclockwise"
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isCreatingCheckpoint || isReturningToCheckpoint)
                    }
                }
            }
        }
    }

    var recentBackupStrip: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Latest Backup Files")
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if recentBackupMetadata.isEmpty {
                emptyRecoveryRow("No backup files created yet.")
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(recentBackupMetadata.prefix(3))) { metadata in
                        recentBackupFileRow(metadata)
                    }
                }
            }
        }
    }

    func recentBackupFileRow(_ metadata: RadixBackupMetadata) -> some View {
        let url = URL(fileURLWithPath: metadata.path)
        let subtitle = LocalDataSnapshot.relativeText(for: Date(timeIntervalSince1970: metadata.timestamp))
        let readable = RadixBackupMetadataStore.isReadable(metadata)

        return Menu {
            Button {
                restoreBackup(metadata, mode: .additive)
            } label: {
                Label("Merge Backup", systemImage: "square.and.arrow.down")
            }

            Button(role: .destructive) {
                restoreBackup(metadata, mode: .complete)
            } label: {
                Label("Replace from Backup", systemImage: "square.and.arrow.down.fill")
            }
        } label: {
            recoveryListRow(
                title: url.lastPathComponent,
                subtitle: readable ? subtitle : "\(subtitle) · choose file again",
                systemImage: "doc.zipper",
                trailingSystemImage: readable ? "arrow.triangle.2.circlepath" : "folder"
            )
        }
        .buttonStyle(.plain)
    }

    func emptyRecoveryRow(_ text: String) -> some View {
        Text(text)
            .font(ResponsiveFont.caption)
            .foregroundStyle(.secondary)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RadixTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    func recoveryListRow(
        title: String,
        subtitle: String,
        systemImage: String,
        trailingSystemImage: String
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, height: 24)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(ResponsiveFont.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Image(systemName: trailingSystemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RadixTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var createCheckpointButton: some View {
        let locked = entitlement.requiresPro(.datedCopies)
        return Button {
            if locked {
                onRequirePro(.datedCopies)
            } else {
                onCreateCheckpoint()
            }
        } label: {
            DataBackupActionButton(
                title: isCreatingCheckpoint ? "Creating..." : RadixCopy.createCheckpoint,
                subtitle: "Keep a local recovery point",
                systemName: "clock.badge.checkmark",
                foreground: Color.accentColor,
                background: Color.accentColor.opacity(0.1),
                border: Color.accentColor.opacity(0.35),
                isLocked: locked
            )
        }
        .buttonStyle(.plain)
        .disabled(isCreatingCheckpoint || isReturningToCheckpoint)
    }

    var returnToCheckpointButton: some View {
        let locked = entitlement.requiresPro(.datedCopies)
        return Menu {
            if locked {
                Button {
                    onRequirePro(.datedCopies)
                } label: {
                    Label("Unlock Checkpoints", systemImage: "lock.fill")
                }
            } else if checkpoints.isEmpty {
                Text("No checkpoints created")
            } else {
                ForEach(checkpoints) { checkpoint in
                    Button {
                        pendingCheckpointReturn = checkpoint
                    } label: {
                        Label(checkpoint.title, systemImage: "clock.arrow.circlepath")
                    }
                }
            }

            Divider()

            Button {
                onRefreshCheckpoints()
            } label: {
                Label("Refresh List", systemImage: "arrow.clockwise")
            }
        } label: {
            DataBackupActionButton(
                title: isReturningToCheckpoint ? "Returning..." : RadixCopy.returnToCheckpoint,
                subtitle: checkpoints.isEmpty ? "No checkpoints yet" : "\(checkpoints.count) available",
                systemName: "arrow.counterclockwise",
                foreground: Color.orange,
                background: Color.orange.opacity(0.1),
                border: Color.orange.opacity(0.35),
                isLocked: locked
            )
        }
        .buttonStyle(.plain)
        .disabled(isCreatingCheckpoint || isReturningToCheckpoint)
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
                title: reuseExportInProgress && reuseExportFilename.contains("backup") ? "Preparing..." : RadixCopy.createBackup,
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
                title: RadixCopy.mergeBackup,
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
                title: RadixCopy.replaceFromBackup,
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
