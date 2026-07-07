import SwiftUI

extension DataEditTab {
    @ViewBuilder
    var backupAndRestoreSection: some View {
        backupFileSection
    }

    var backupFileSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            portableBackupActionsSection

            compactBackupContentsDisclosure
        }
        .padding(12)
        .radixSurface(RadixTheme.secondaryBackground.opacity(0.4))
    }

    var studyCheckpointsNote: some View {
        Button {
            store.goToFavourites(preservingOrigin: true)
        } label: {
            Label("Checkpoints", systemImage: "clock.arrow.circlepath")
                .font(ResponsiveFont.caption.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .radixPill(background: RadixAccent.primary.opacity(0.1))
        }
        .buttonStyle(.plain)
        .foregroundStyle(RadixAccent.primary)
    }

    var portableBackupActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                plusBadge
                Spacer()
                studyCheckpointsNote
            }

            Text("Create a new file from memory, merge file and memory, or restore memory from a file.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)

            myBackupVisibilityNote
            recentBackupStrip

            portableBackupActionButtons
        }
    }

    var plusBadge: some View {
        Text("Plus")
            .font(ResponsiveFont.caption.bold())
            .foregroundStyle(RadixAccent.primary)
            .radixPill(background: RadixAccent.primary.opacity(0.14))
            .accessibilityLabel("Radix Plus feature")
    }

    @ViewBuilder
    var portableBackupActionButtons: some View {
        VStack(spacing: 8) {
            backupToiCloudButton
            mergeBackupButton
            replaceBackupButton
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
                Label("Merge File and Device", systemImage: "arrow.triangle.2.circlepath")
            }

            Button(role: .destructive) {
                restoreBackup(metadata, mode: .complete)
            } label: {
                Label("Restore from File", systemImage: "square.and.arrow.down.fill")
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
            .radixSurface(RadixTheme.background)
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
                .foregroundStyle(RadixAccent.primary)
                .radixIconButtonSurface(
                    size: 24,
                    background: RadixAccent.primary.opacity(0.1),
                    radius: RadixRadius.small
                )

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
        .radixSurface(RadixTheme.background)
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
                subtitle: "Create a new file from memory",
                systemName: "square.and.arrow.up.fill",
                foreground: .white,
                background: RadixAccent.primary,
                border: RadixAccent.primary,
                isLocked: entitlement.requiresPro(.myBackup)
            )
        }
        .buttonStyle(.plain)
        .disabled(reuseExportInProgress)
    }

    var mergeBackupButton: some View {
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
                subtitle: "File and memory both contain the merged contents",
                systemName: "arrow.triangle.2.circlepath",
                foreground: .white,
                background: RadixAccent.primary,
                border: RadixAccent.primary,
                isLocked: entitlement.requiresPro(.myBackup)
            )
        }
        .buttonStyle(.plain)
    }

    var replaceBackupButton: some View {
        Button {
            guard !entitlement.requiresPro(.myBackup) else {
                onRequirePro(.myBackup)
                return
            }
            pendingRestoreMode = .complete
            showRestorePicker = true
        } label: {
            DataBackupActionButton(
                title: RadixCopy.restoreBackup,
                subtitle: "Replace memory with the file",
                systemName: "square.and.arrow.down.fill",
                foreground: Color.orange,
                background: RadixTheme.background,
                border: Color.orange.opacity(0.45),
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .radixCard(padding: 10, background: RadixTheme.background)
        }
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
