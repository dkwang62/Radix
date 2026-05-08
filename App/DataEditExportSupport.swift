import SwiftUI

enum AdvancedZipExportKind {
    case projectArchive
    case xcodeDataFiles
}

struct AdvancedExportToolsTip: Identifiable {
    let title: String
    let message: String

    var id: String { title }
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

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemName)
                .font(ResponsiveFont.body.bold())
            Text(title)
                .font(ResponsiveFont.caption.bold())
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(subtitle)
                .font(ResponsiveFont.caption2)
                .multilineTextAlignment(.center)
                .opacity(0.85)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 84)
        .padding(.horizontal, 8)
        .background(background)
        .foregroundStyle(foreground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(border, lineWidth: 1)
        )
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
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(message)
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Dismiss", action: onDismiss)
                .font(ResponsiveFont.caption)
        }
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
                    subtitle: isLocked ? "\(subtitle) Unlock Pro to export." : subtitle,
                    systemName: isLocked ? "lock.fill" : systemName,
                    color: color
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
                    .frame(width: 34, height: 34)
                    .background(color.opacity(0.10))
                    .clipShape(Circle())
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.35), lineWidth: 1)
        )
    }
}
