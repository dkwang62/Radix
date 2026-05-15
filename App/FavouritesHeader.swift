import SwiftUI

extension FavouritesTab {
    var favouritesHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Saved characters, phrases, and recent items.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
                HStack(spacing: 12) {
                    Button(action: onExportProfile) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Button(action: onImportProfile) {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
                .font(ResponsiveFont.body)
                .foregroundStyle(Color.accentColor)
            }

        }
        .padding()
    }
}
