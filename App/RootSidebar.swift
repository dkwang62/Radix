import SwiftUI

extension RootView {
    var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                sidebarBrandHeader

                if store.sidebarNavigationStyle == .compact {
                    compactSidebarNavigation
                } else {
                    descriptiveSidebarNavigation
                }

                if store.previewCharacter != nil || store.activeSidebarPhrasePreview != nil {
                    sidebarPreview
                }

                Button {
                    showSettings = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: RadixIcon.settings)
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
            if !hasUsedSidebarNavigation {
                Text("Lifelong Chinese Companion")
                    .font(ResponsiveFont.subheadline.weight(.semibold))
                Text("Scan, save, study, and carry your Chinese across devices.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Picker("Sidebar navigation style", selection: $store.sidebarNavigationStyle) {
                Text(SidebarNavigationStyle.descriptive.displayName).tag(SidebarNavigationStyle.descriptive)
                Text(SidebarNavigationStyle.compact.displayName).tag(SidebarNavigationStyle.compact)
            }
            .pickerStyle(.segmented)
            .padding(.top, 4)
            .accessibilityLabel("Sidebar navigation style")
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    var descriptiveSidebarNavigation: some View {
        VStack(alignment: .leading, spacing: 8) {
            sidebarTaskButton(.scan, isActive: store.route == .capture) {
                hasUsedSidebarNavigation = true
                store.route = .capture
            }

            sidebarTaskButton(.search, isActive: store.route == .search && store.homeTab == .smart) {
                hasUsedSidebarNavigation = true
                store.goToSearchRoot()
            }

            sidebarTaskButton(.browse, isActive: store.route == .search && store.homeTab == .filter) {
                hasUsedSidebarNavigation = true
                store.goToBrowse()
            }

            sidebarTaskButton(.study, isActive: store.route == .favourites || (store.route == .search && store.homeTab == .favourites)) {
                hasUsedSidebarNavigation = true
                store.goToFavourites()
            }

            sidebarTaskButton(.aiLink, isActive: store.route == .aiLink) {
                hasUsedSidebarNavigation = true
                store.enterAILink()
            }

            sidebarTaskButton(.myData, isActive: store.route == .search && store.homeTab == .dataEdit) {
                hasUsedSidebarNavigation = true
                store.goToDataEdit()
            }
        }
    }

    var compactSidebarNavigation: some View {
        HStack(spacing: 6) {
            compactSidebarButton(.scan, isActive: store.route == .capture) {
                hasUsedSidebarNavigation = true
                store.route = .capture
            }
            compactSidebarButton(.search, isActive: store.route == .search && store.homeTab == .smart) {
                hasUsedSidebarNavigation = true
                store.goToSearchRoot()
            }
            compactSidebarButton(.browse, isActive: store.route == .search && store.homeTab == .filter) {
                hasUsedSidebarNavigation = true
                store.goToBrowse()
            }
            compactSidebarButton(.study, isActive: store.route == .favourites || (store.route == .search && store.homeTab == .favourites)) {
                hasUsedSidebarNavigation = true
                store.goToFavourites()
            }
            compactSidebarButton(.aiLink, isActive: store.route == .aiLink) {
                hasUsedSidebarNavigation = true
                store.enterAILink()
            }
            compactSidebarButton(.myData, isActive: store.route == .search && store.homeTab == .dataEdit) {
                hasUsedSidebarNavigation = true
                store.goToDataEdit()
            }
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
            .background(Color(.secondarySystemBackground).opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
        }
    }

    func sidebarTaskButton(
        _ item: RadixNavigationItem,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(ResponsiveFont.headline)
                    .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                    .frame(width: 30, height: 30)
                    .background(isActive ? Color.accentColor.opacity(0.12) : Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(ResponsiveFont.subheadline.weight(.semibold))
                    Text(item.subtitle)
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

    func compactSidebarButton(
        _ item: RadixNavigationItem,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: item.icon)
                .font(ResponsiveFont.headline)
                .frame(maxWidth: .infinity, minHeight: 42)
            .foregroundStyle(isActive ? Color.accentColor : Color.primary)
            .background(isActive ? Color.accentColor.opacity(0.12) : Color(.secondarySystemBackground).opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isActive ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
    }
}
