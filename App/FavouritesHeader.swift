import SwiftUI

extension FavouritesTab {
    var favouritesHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
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
            Text("Whatever is remembered will be forgotten once the app is closed. Add to Favorites to keep.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
    }
}
