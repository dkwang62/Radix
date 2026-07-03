import SwiftUI

extension FavouritesTab {
    var favouritesHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Favorite characters, phrases, pages, and recently viewed characters.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
                if hasDismissedStudyIntro {
                    Button {
                        withAnimation { hasDismissedStudyIntro = false }
                    } label: {
                        if store.sidebarNavigationStyle == .compact {
                            Image(systemName: RadixIcon.help)
                        } else {
                            RadixHelpLabel()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel("Show Study help")
                }
            }

        }
        .padding()
    }
}
