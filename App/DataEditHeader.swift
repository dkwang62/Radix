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
                    Label("Your Radix memory: everything you added, saved, marked, or set up.", systemImage: "checkmark.circle")
                case .localBackup:
                    Label("Save the same Radix memory as a dated copy kept on this device.", systemImage: "clock.badge.checkmark")
                case .myBackup:
                    Label("Save the same Radix memory as a file for another iPhone, iPad, or Mac.", systemImage: "arrow.left.arrow.right")
                case .advanced:
                    Label("For people who want Radix data as separate files for outside tools.", systemImage: "shippingbox")
                }
            }
            .font(ResponsiveFont.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}
