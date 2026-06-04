import SwiftUI

extension DataEditTab {
    var myDataHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Back Up and Restore")
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Use this area when you want your Radix data available on other devices or recoverable later.")
                    .font(ResponsiveFont.caption2)
                    .foregroundStyle(.secondary)
            }

            Picker("My Data section", selection: $activeDataEditSection) {
                ForEach(DataEditSection.allCases) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("My Data section")

            Group {
                switch activeDataEditSection {
                case .myBackup:
                    glossaryHeaderLine(
                        "Create or restore an iCloud backup for another iPhone, iPad, or Mac.",
                        systemImage: "externaldrive.badge.icloud",
                        term: "iCloud Backup"
                    )
                case .advanced:
                    glossaryHeaderLine(
                        "For people who want Radix data as separate files for outside tools.",
                        systemImage: "shippingbox",
                        term: "Data Portability"
                    )
                }
            }
            .font(ResponsiveFont.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    func glossaryHeaderLine(_ text: String, systemImage: String, term: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Label(text, systemImage: systemImage)
            GlossaryTermButton(term: term)
        }
    }
}
