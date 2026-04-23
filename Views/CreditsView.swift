import SwiftUI

struct CreditsView: View {
    var body: some View {
        List {
            Section("Third-Party Data Sources") {
                dataSourceCard(
                    title: "CC-CEDICT",
                    detail: "Chinese-English dictionary data from CC-CEDICT.",
                    note: "License: CC BY-SA 4.0",
                    linkTitle: "https://cc-cedict.org/",
                    linkURL: "https://cc-cedict.org/",
                    licenseTitle: "CC-CEDICT License Text",
                    licenseFile: "CEDICT_LICENSE"
                )

                dataSourceCard(
                    title: "Unicode Unihan Database",
                    detail: "Character metadata from the Unicode Unihan database.",
                    note: nil,
                    linkTitle: "https://www.unicode.org/",
                    linkURL: "https://www.unicode.org/",
                    licenseTitle: "Unicode License Text",
                    licenseFile: "UNICODE_LICENSE"
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("IDS / Ideographic Description Sequences")
                        .font(ResponsiveFont.subheadline.bold())
                    Text("Character structure notation used for decomposition and synthesis.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                    Text("Examples: ⿰ left-right, ⿱ top-bottom, ⿴ enclosure.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                    Link("Unicode IDS reference", destination: URL(string: "https://www.unicode.org/")!)
                        .font(ResponsiveFont.caption)
                }
                .padding(.vertical, 6)
            }

            Section("Legal Notice") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Radix includes third-party data and software. Ownership remains with the original licensors.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                    Text("CC-CEDICT is attributed under CC BY-SA 4.0. Adapted redistribution may require ShareAlike.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                    Text("Radix is not endorsed by or affiliated with CC-CEDICT, Unicode, or HanziWriter maintainers.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Credits / Data Sources")
    }

    @ViewBuilder
    private func dataSourceCard(
        title: String,
        detail: String,
        note: String?,
        linkTitle: String,
        linkURL: String,
        licenseTitle: String,
        licenseFile: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(ResponsiveFont.subheadline.bold())
            Text(detail)
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
            if let note {
                Text(note)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }
            Link(linkTitle, destination: URL(string: linkURL)!)
                .font(ResponsiveFont.caption)

            DisclosureGroup(licenseTitle) {
                Text(LicenseTextLoader.loadText(fileName: licenseFile))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(.top, 6)
            }
            .font(ResponsiveFont.caption)
        }
        .padding(.vertical, 6)
    }
}
