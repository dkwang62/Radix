import SwiftUI

extension DataEditTab {
    var currentMemorySummaryTiles: some View {
        LazyVGrid(columns: librarySummaryColumns, spacing: 8) {
            librarySummaryTile(
                title: "Characters",
                value: "\(store.addedDictionaryCharacters.count + store.baseDictionaryCoreEditedCharacters.count + store.dictionaryCharactersWithNotes.count)",
                systemImage: "character.book.closed",
                tint: .blue
            )
            librarySummaryTile(
                title: "Phrases",
                value: "\(addedPhraseEntries.count + basePhraseCoreEditEntries.count + phraseEntriesWithNotes.count)",
                systemImage: "text.quote",
                tint: .green
            )
            librarySummaryTile(
                title: "Saved Pages",
                value: "\(store.allCollections.count)",
                systemImage: "photo.on.rectangle",
                tint: .purple
            )
            librarySummaryTile(
                title: "Study Items",
                value: "\(store.favoriteItems.count + store.favoritePhrasesItems.count + store.rootBreadcrumb.count)",
                systemImage: "star.fill",
                tint: .orange
            )
            librarySummaryTile(
                title: "AI Links",
                value: "\(store.promptConfig.tasks.count)",
                systemImage: "wand.and.stars",
                tint: .teal
            )
            librarySummaryTile(
                title: "App State",
                value: "\(store.searchHistory.count + store.rootBreadcrumb.count + (store.previewCharacter == nil ? 0 : 1))",
                systemImage: "slider.horizontal.3",
                tint: .gray
            )
        }
    }

    var memorySavedStatusRow: some View {
        let latestSnapshot = localSnapshots.first
        return HStack(spacing: 10) {
            Image(systemName: latestSnapshot == nil ? "clock.badge.exclamationmark" : "clock.badge.checkmark")
                .foregroundStyle(latestSnapshot == nil ? Color.secondary : Color.green)

            Text(latestSnapshot.map { "Last saved \($0.relativeSavedText)." } ?? "No dated copy saved on this device yet.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(latestSnapshot == nil ? Color.secondary : Color.green)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(latestSnapshot == nil ? Color(.secondarySystemBackground) : Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var localSnapshotsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Save a Copy Here", systemImage: "clock.badge.checkmark")
                    .font(ResponsiveFont.headline)
                Spacer()
                Text("\(localSnapshots.count) copies")
                    .font(ResponsiveFont.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text("Free dated copies kept on this device. Each copy contains the same Radix Memory shown below.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            memorySavedStatusRow

            currentMemorySummaryTiles

            Button {
                createLocalSnapshot()
            } label: {
                DataBackupActionButton(
                    title: "Save Dated Copy",
                    subtitle: "No file to choose",
                    systemName: "clock.badge.plus",
                    foreground: .white,
                    background: Color.accentColor,
                    border: Color.accentColor
                )
            }
            .buttonStyle(.plain)

            if localSnapshots.isEmpty {
                Text("No dated copies yet.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 8) {
                    ForEach(localSnapshots) { snapshot in
                        LocalDataSnapshotRow(
                            snapshot: snapshot,
                            onAdd: { restoreLocalSnapshot(snapshot, mode: .additive) },
                            onReplace: { restoreLocalSnapshot(snapshot, mode: .complete) },
                            onDelete: { deleteLocalSnapshot(snapshot) }
                        )
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    func createLocalSnapshot() {
        do {
            let data = try dataExportService.exportPortableBackup(store.portableBackupPackage())
            localSnapshots = try localSnapshotStore.save(data)
            backupMessage = "Saved dated copy: \(localSnapshots.first?.title ?? "Now")"
            showBackupAlert = true
        } catch {
            backupError = error.localizedDescription
            showBackupAlert = true
        }
    }

    func restoreLocalSnapshot(_ snapshot: LocalDataSnapshot, mode: RestoreMode) {
        do {
            let data = try localSnapshotStore.data(for: snapshot)
            try store.importDataEditData(data, mode: mode)
            refreshLocalSnapshots()
            let modeLabel = mode == .complete ? "Replaced this device's data" : "Added to what is already here"
            backupMessage = "\(modeLabel) from \(snapshot.title)"
            showBackupAlert = true
        } catch {
            backupError = error.localizedDescription
            showBackupAlert = true
        }
    }

    func deleteLocalSnapshot(_ snapshot: LocalDataSnapshot) {
        do {
            localSnapshots = try localSnapshotStore.delete(snapshot)
            backupMessage = "Deleted dated copy: \(snapshot.title)"
            showBackupAlert = true
        } catch {
            backupError = error.localizedDescription
            showBackupAlert = true
        }
    }
}

struct LocalDataSnapshotRow: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    let snapshot: LocalDataSnapshot
    let onAdd: () -> Void
    let onReplace: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 34, height: 34)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.title)
                        .font(ResponsiveFont.body.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(snapshot.subtitle)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            snapshotActions
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    var snapshotActions: some View {
        if sizeClass == .compact {
            VStack(spacing: 8) {
                addButton
                replaceButton
                deleteButton
            }
            .font(ResponsiveFont.caption.weight(.semibold))
        } else {
            HStack(spacing: 8) {
                addButton
                replaceButton
                deleteButton
            }
            .font(ResponsiveFont.caption.weight(.semibold))
        }
    }

    var addButton: some View {
        Button(action: onAdd) {
            Label("Add to Memory", systemImage: "plus")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    var replaceButton: some View {
        Button(role: .destructive, action: onReplace) {
            Label("Replace Memory", systemImage: "arrow.triangle.2.circlepath")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    var deleteButton: some View {
        Button(role: .destructive, action: onDelete) {
            Label("Delete", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }
}
