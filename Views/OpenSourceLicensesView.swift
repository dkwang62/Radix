import SwiftUI

struct OpenSourceLicensesView: View {
    @Environment(\.dismiss) private var dismiss

    private let licenseFiles = [
        LicenseFile(title: "HanziWriter MIT License", fileName: "HANZI_WRITER_LICENSE", fileExtension: "txt", subdirectory: "Licenses"),
        LicenseFile(title: "Arphic Public License", fileName: "ARPHICPL", fileExtension: "TXT", subdirectory: "Licenses")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Radix uses HanziWriter for stroke-order animation.")
                            .font(ResponsiveFont.body)
                        Text("HanziWriter is licensed under the MIT License. Stroke-order data is derived from Make Me a Hanzi / Arphic font data and is distributed under the Arphic Public License.")
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Data Source Note")
                            .font(ResponsiveFont.subheadline.bold())
                        Text("The provenance of the bundled dictionary and phrase database should be verified before public App Store release. No additional license claim is made here for those datasets.")
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(Color.orange.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    ForEach(licenseFiles) { file in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(file.title)
                                .font(ResponsiveFont.headline)
                            Text(Self.licenseText(for: file))
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(14)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .background(Color(.secondarySystemBackground).opacity(0.35))
            .navigationTitle("Open Source Licenses")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private static func licenseText(for file: LicenseFile) -> String {
        guard let url = Bundle.main.url(
            forResource: file.fileName,
            withExtension: file.fileExtension,
            subdirectory: file.subdirectory
        ), let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "License text could not be loaded."
        }
        return text
    }
}

private struct LicenseFile: Identifiable {
    var id: String { "\(subdirectory)/\(fileName).\(fileExtension)" }
    let title: String
    let fileName: String
    let fileExtension: String
    let subdirectory: String
}
