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
                    Label("View is free. This is the personal Radix work you have built up.", systemImage: "checkmark.circle")
                case .myBackup:
                    Label("Export and import unlock with My Backup so your data can travel between devices.", systemImage: "arrow.left.arrow.right")
                case .advanced:
                    Label("Advanced is for developer-style exports and reuse outside the normal app flow.", systemImage: "shippingbox")
                }
            }
            .font(ResponsiveFont.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}
