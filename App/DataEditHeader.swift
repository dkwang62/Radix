import SwiftUI

extension DataEditTab {
    var myDataHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Choose What to Do")
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Use the Memory summary above, then choose where to save, restore, or move it.")
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
                case .localBackup:
                    glossaryHeaderLine(
                        "Create or restore Memory Stamps on this device. Each stamp contains the Memory shown above.",
                        systemImage: "clock.badge.checkmark",
                        term: "Dated Copy"
                    )
                case .myBackup:
                    glossaryHeaderLine(
                        "Export or import the Memory shown above for another iPhone, iPad, or Mac.",
                        systemImage: "arrow.left.arrow.right",
                        term: "Other Devices"
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
