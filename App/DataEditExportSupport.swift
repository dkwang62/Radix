import SwiftUI

enum AdvancedZipExportKind {
    case projectArchive
    case xcodeDataFiles
}

enum AdvancedExportKind {
    case projectArchive
    case projectManifest
    case projectReadme
    case xcodeDataFiles
    case fullDataset
    case sentenceLibrary
    case dictionaryDatabase
    case phraseDatabase
}

struct AdvancedExportToolsTip: Identifiable {
    let title: String
    let message: String

    var id: String { title }
}

struct LocalDataSnapshot: Identifiable, Hashable {
    let id: String
    let createdAt: Date
    let url: URL
    let byteCount: Int

    var title: String {
        Self.titleFormatter.string(from: createdAt)
    }

    var subtitle: String {
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }

    var relativeSavedText: String {
        Self.relativeText(for: createdAt)
    }

    static func relativeText(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private static let titleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

struct LocalDataSnapshotStore {
    static let maximumSnapshotCount = 20

    func snapshots() throws -> [LocalDataSnapshot] {
        let directory = try snapshotsDirectory()
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        return urls
            .filter { $0.pathExtension == "json" }
            .compactMap(snapshot(from:))
            .sorted { $0.createdAt > $1.createdAt }
    }

    func save(_ data: Data, createdAt: Date = Date()) throws -> [LocalDataSnapshot] {
        let directory = try snapshotsDirectory()
        let filename = "radix-local-\(Self.filenameFormatter.string(from: createdAt)).json"
        let url = directory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        try pruneSnapshots()
        return try snapshots()
    }

    func data(for snapshot: LocalDataSnapshot) throws -> Data {
        try Data(contentsOf: snapshot.url)
    }

    func delete(_ snapshot: LocalDataSnapshot) throws -> [LocalDataSnapshot] {
        try FileManager.default.removeItem(at: snapshot.url)
        return try snapshots()
    }

    private func snapshotsDirectory() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("Radix/LocalSnapshots", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func snapshot(from url: URL) -> LocalDataSnapshot? {
        let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey, .fileSizeKey])
        let createdAt = values?.creationDate
            ?? values?.contentModificationDate
            ?? Self.dateFromFilename(url.deletingPathExtension().lastPathComponent)
            ?? Date.distantPast
        return LocalDataSnapshot(
            id: url.lastPathComponent,
            createdAt: createdAt,
            url: url,
            byteCount: values?.fileSize ?? 0
        )
    }

    private func pruneSnapshots() throws {
        let snapshots = try snapshots()
        guard snapshots.count > Self.maximumSnapshotCount else { return }

        for snapshot in snapshots.dropFirst(Self.maximumSnapshotCount) {
            try FileManager.default.removeItem(at: snapshot.url)
        }
    }

    private static let filenameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()

    private static func dateFromFilename(_ filename: String) -> Date? {
        let stamp = filename.replacingOccurrences(of: "radix-local-", with: "")
        return filenameFormatter.date(from: stamp)
    }
}

enum ProjectArchiveName {
    static func baseName(for date: Date = Date()) -> String {
        stampedBaseName("radix_project", for: date)
    }

    static func stampedBaseName(_ baseName: String, for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        let cleanBase = baseName.replacingOccurrences(
            of: #"_\d{4}-\d{2}-\d{2}-\d{4}$"#,
            with: "",
            options: .regularExpression
        )
        return "\(cleanBase)_\(formatter.string(from: date))"
    }
}

struct DataBackupActionButton: View {
    let title: String
    let subtitle: String
    let systemName: String
    let foreground: Color
    let background: Color
    let border: Color
    var isLocked: Bool = false
    var lockBadge: String = "Plus"

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isLocked ? "lock.fill" : systemName)
                .font(.system(size: 18, weight: .bold))
                .radixIconButtonSurface(
                    size: 34,
                    background: foreground.opacity(0.12)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ResponsiveFont.caption.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(ResponsiveFont.caption2)
                    .opacity(0.85)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            if isLocked {
                Text(lockBadge)
                    .font(ResponsiveFont.caption.bold())
                    .fixedSize(horizontal: true, vertical: false)
                    .radixPill(background: RadixTheme.background.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity, minHeight: RadixControlMetrics.actionCardHeight, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .foregroundStyle(foreground)
        .radixSurface(background, border: border)
    }
}

struct AdvancedExportProgressRow: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Preparing advanced export...")
                .font(ResponsiveFont.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct AdvancedExportMessageRow: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(message)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("Dismiss", action: onDismiss)
                .font(ResponsiveFont.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AdvancedExportOptionRow: View {
    let title: String
    let subtitle: String
    let toolsTip: AdvancedExportToolsTip
    let systemName: String
    let color: Color
    let isLocked: Bool
    let isDisabled: Bool
    let onExport: () -> Void
    let onShowTools: (AdvancedExportToolsTip) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onExport) {
                AdvancedExportOptionCard(
                    title: title,
                    subtitle: isLocked ? "\(subtitle) Unlock Advanced Pro to export." : subtitle,
                    systemName: isLocked ? "lock.fill" : systemName,
                    color: color,
                    badge: isLocked ? "Pro" : nil
                )
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)

            Button {
                onShowTools(toolsTip)
            } label: {
                Image(systemName: "info.circle")
                    .font(ResponsiveFont.body)
                    .foregroundStyle(color)
                    .radixIconButtonSurface(
                        size: 34,
                        background: color.opacity(0.10),
                        radius: 17
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tools needed for \(title)")
        }
    }
}

private struct AdvancedExportOptionCard: View {
    let title: String
    let subtitle: String
    let systemName: String
    let color: Color
    let badge: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemName)
                .font(ResponsiveFont.title3)
                .foregroundStyle(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(ResponsiveFont.subheadline.bold())
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let badge {
                Text(badge)
                    .font(ResponsiveFont.caption.bold())
                    .foregroundStyle(color)
                    .radixPill(background: color.opacity(0.12))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .radixSurface(color.opacity(0.12), border: color.opacity(0.35))
    }
}
