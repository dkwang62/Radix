import SwiftUI

extension DataEditTab {
    var myDataHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("My Data section", selection: $activeDataEditSection) {
                ForEach(DataEditSection.allCases) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("My Data section")

            Group {
                switch activeDataEditSection {
                case .library:
                    glossaryHeaderLine(
                        "Your Radix memory: everything you added, saved, marked, or set up.",
                        systemImage: "checkmark.circle",
                        term: "Memory"
                    )
                case .localBackup:
                    glossaryHeaderLine(
                        "Save the same Radix memory as a dated copy kept on this device.",
                        systemImage: "clock.badge.checkmark",
                        term: "Dated Copy"
                    )
                case .myBackup:
                    glossaryHeaderLine(
                        "Save the same Radix memory as a file for another iPhone, iPad, or Mac.",
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
