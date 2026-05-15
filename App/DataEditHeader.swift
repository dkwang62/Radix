import SwiftUI

extension DataEditTab {
    var myDataHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Review your additions and move them between iPhone, iPad, and Mac.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showHelp.toggle() }
                } label: {
                    Image(systemName: showHelp ? "questionmark.circle.fill" : "questionmark.circle")
                        .font(ResponsiveFont.body)
                        .foregroundStyle(showHelp ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Help")
            }

            Picker("My Data section", selection: $activeDataEditSection) {
                ForEach(DataEditSection.allCases) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("My Data section")

            if showHelp {
                VStack(alignment: .leading, spacing: 8) {
                    Text("My Data preview is free.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                    Text("Data portability is the key paid feature: what you add on one device can be carried to the others.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                    Text("Advanced exports files for developers and reuse.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .transition(.opacity)
            }
        }
    }
}
