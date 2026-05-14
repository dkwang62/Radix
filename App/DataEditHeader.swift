import SwiftUI

extension DataEditTab {
    var myDataHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
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

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showAdvancedExports.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showAdvancedExports ? "arrow.uturn.backward.circle" : "square.and.arrow.up.on.square")
                        Text(showAdvancedExports ? "Backup & Restore" : "Advanced")
                            .font(ResponsiveFont.caption)
                    }
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(showAdvancedExports ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
            }

            if showHelp {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Backup saves everything you've added or changed — custom characters, phrases, saved images, favorites, API keys, and AI templates — into a single file.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                    Text("Additive restore merges dictionary, phrase, saved image, and API key changes. Complete restore replaces the app's overlay data, saved images, favorites, memory, search history, settings, API keys, and AI templates with the backup.")
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
