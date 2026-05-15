import SwiftUI

extension RootView {
    var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                sidebarBrandHeader

                if store.previewCharacter != nil || store.activeSidebarPhrasePreview != nil {
                    sidebarPreview
                }

                VStack(alignment: .leading, spacing: 8) {
                    sidebarTaskButton(
                        title: "Scan",
                        subtitle: "Use a camera, photo, or file to turn real text into a browsable page.",
                        icon: "camera.viewfinder",
                        isActive: store.route == .capture
                    ) {
                        store.route = .capture
                    }

                    sidebarTaskButton(
                        title: "Search",
                        subtitle: "Find characters and phrases by Chinese, pinyin, English meaning, or strokes.",
                        icon: "magnifyingglass",
                        isActive: store.route == .search && store.homeTab == .smart
                    ) {
                        store.goToSearchRoot()
                    }

                    sidebarTaskButton(
                        title: "Browse",
                        subtitle: "Explore the dictionary or open saved pages from scans and pasted text.",
                        icon: "square.grid.2x2",
                        isActive: store.route == .search && store.homeTab == .filter
                    ) {
                        store.goToBrowse()
                    }

                    sidebarTaskButton(
                        title: "Study",
                        subtitle: "Return to favorites, remembered items, and pages you want to revisit.",
                        icon: "star",
                        isActive: store.route == .favourites || (store.route == .search && store.homeTab == .favourites)
                    ) {
                        store.goToFavourites()
                    }

                    sidebarTaskButton(
                        title: "AI Link",
                        subtitle: "Use repeatable AI actions for phrases, interpretation, translation, and saved pages.",
                        icon: "sparkles",
                        isActive: store.route == .aiLink
                    ) {
                        store.enterAILink()
                    }

                    sidebarTaskButton(
                        title: "My Data",
                        subtitle: "Your additions can travel between iPhone, iPad, and Mac.",
                        icon: "externaldrive",
                        isActive: store.route == .search && store.homeTab == .dataEdit
                    ) {
                        store.goToDataEdit()
                    }
                }

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
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground).opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(8)
        }
    }

    var sidebarBrandHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Scan, understand, and save Chinese characters.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
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
            .background(Color(.secondarySystemBackground).opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
        }
    }

    func sidebarTaskButton(
        title: String,
        subtitle: String,
        icon: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(ResponsiveFont.headline)
                    .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                    .frame(width: 30, height: 30)
                    .background(isActive ? Color.accentColor.opacity(0.12) : Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(ResponsiveFont.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(ResponsiveFont.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(isActive ? Color.accentColor.opacity(0.1) : Color(.secondarySystemBackground).opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isActive ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
