import SwiftUI

extension RootView {
    var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    sidebarIconButton(
                        title: "Image",
                        icon: "camera",
                        isActive: store.route == .capture
                    ) {
                        store.route = .capture
                    }
                    sidebarIconButton(
                        title: "Browse",
                        icon: "square.grid.2x2",
                        isActive: store.route == .search && store.homeTab == .filter
                    ) {
                        store.goToBrowse()
                    }
                    sidebarIconButton(
                        title: "Search",
                        icon: "magnifyingglass",
                        isActive: store.route == .search && store.homeTab == .smart
                    ) {
                        store.goToSearchRoot()
                    }
                    sidebarIconButton(
                        title: "Favorites",
                        icon: "star",
                        isActive: store.route == .search && store.homeTab == .favourites
                    ) {
                        store.goToFavourites()
                    }
                    sidebarIconButton(
                        title: "AI Link",
                        icon: "sparkles",
                        isActive: store.route == .aiLink
                    ) {
                        store.enterAILink()
                    }
                    sidebarIconButton(
                        title: "My Data",
                        icon: "pencil.and.outline",
                        isActive: store.route == .search && store.homeTab == .dataEdit
                    ) {
                        store.goToDataEdit()
                    }
                }
                .padding(10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    showSettings = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "gearshape")
                            .font(ResponsiveFont.body)
                        Text("Settings")
                            .font(ResponsiveFont.subheadline.weight(.semibold))
                        Spacer()
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                if store.previewCharacter != nil || store.activeSidebarPhrasePreview != nil {
                    sidebarPreview
                }
            }
            .padding(8)
        }
    }

    @ViewBuilder
    var sidebarPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let phrase = store.activeSidebarPhrasePreview {
                    PhraseInfoCard(phrase: phrase, onDone: {
                        store.dismissSidebarPhrasePreview()
                    })
                    .environmentObject(store)
                } else if let current = store.previewCharacter {
                    CharacterPreviewHeader(
                        character: current,
                        showClearButton: false,
                        showAddToMemoryButton: !(store.route == .search && store.homeTab == .favourites),
                        isVertical: true
                    )
                } else {
                    EmptyView()
                }
            }
            .padding(8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )

            HStack {
                Spacer()

                Button {
                    store.goToFavourites()
                } label: {
                    Image(systemName: "list.star")
                        .font(ResponsiveFont.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    func sidebarIconButton(
        title: String,
        icon: String,
        usesSystemImage: Bool = true,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                if usesSystemImage {
                    Image(systemName: icon)
                        .font(ResponsiveFont.headline)
                } else {
                    Text(icon)
                        .font(ResponsiveFont.headline)
                }
                Text(title)
                    .font(ResponsiveFont.caption2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isActive ? Color.accentColor.opacity(0.16) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
