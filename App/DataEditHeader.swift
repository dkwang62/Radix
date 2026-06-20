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
        }
    }
}
