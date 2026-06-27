import SwiftUI

extension RootView {
    var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                sidebarBrandHeader

                sidebarGlobalActionRow
                sidebarMainNavigation

                if store.previewCharacter != nil || store.activeSidebarPhrasePreview != nil {
                    sidebarPreview
                }
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
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    var sidebarGlobalActionRow: some View {
        HStack(spacing: 8) {
            Button {
                hasUsedSidebarNavigation = true
                beginNewSearch()
            } label: {
                PrimaryActionTile(
                    title: "Search",
                    subtitle: "Anything",
                    systemImage: RadixIcon.search,
                    isPrimary: false
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Search in Radix")

            Button {
                hasUsedSidebarNavigation = true
                store.showiPhoneDetail = false
                store.previewCharacter = nil
                store.startBrowseCameraPage()
            } label: {
                PrimaryActionTile(
                    title: "Camera",
                    subtitle: "Capture text",
                    systemImage: "camera.fill",
                    isPrimary: true
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Camera")
        }
    }

    var sidebarMainNavigation: some View {
        HStack(spacing: 6) {
            sidebarTabButton(.browse)
            sidebarTabButton(.study)
            sidebarTabButton(.aiLink)
            sidebarTabButton(.myData)
            sidebarSettingsTabButton
        }
    }

    func sidebarTabButton(_ item: RadixNavigationItem) -> some View {
        let id = item.rawValue
        let guideTopic = item.guideTopic ?? .browse
        let showsTitle = store.sidebarNavigationStyle == .descriptive
        let isActive = {
            if store.route == .favourites { return id == 3 }
            if store.route == .aiLink { return id == 4 }
            if store.route == .lineage { return false }
            if store.route == .capture { return false }
            if store.route == .settings { return false }
            switch store.homeTab {
            case .smart: return false
            case .filter: return id == 2
            case .favourites: return id == 3
            case .dataEdit: return id == 5
            }
        }()

        return Button {
            handleNavigationGuideTap(guideTopic, isActive: isActive) {
                store.clearCrossTabOrigin()
                switch id {
                case 2:
                    hasUsedSidebarNavigation = true
                    store.goToBrowse()
                case 3:
                    hasUsedSidebarNavigation = true
                    store.goToFavourites()
                case 4:
                    hasUsedSidebarNavigation = true
                    store.enterAILink()
                case 5:
                    hasUsedSidebarNavigation = true
                    store.goToDataEdit()
                default:
                    break
                }
            }
        } label: {
            VStack(spacing: showsTitle ? 2 : 0) {
                Image(systemName: item.icon)
                    .font(.system(size: isActive ? 17 : 16, weight: .semibold))
                if showsTitle {
                    Text(item.compactTitle)
                        .font(ResponsiveFont.tinySystem(size: 10, weight: isActive ? .bold : .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)
                }
            }
            .foregroundStyle(isActive ? Color.white : Color.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: showsTitle ? 48 : 42)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Color.accentColor : RadixTheme.secondaryBackground.opacity(0.65))
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityValue(isActive ? "Selected" : "")
        .accessibilityHint("\(item.subtitle) Select this destination again to show its guide.")
        .overlay(
            Group {
                if isActive {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                } else {
                    EmptyView()
                }
            }
        )
        .help(guideTopic.summary)
    }

    var sidebarSettingsTabButton: some View {
        let showsTitle = store.sidebarNavigationStyle == .descriptive
        let isActive = store.route == .settings

        return Button {
            handleNavigationGuideTap(.settings, isActive: isActive) {
                store.clearCrossTabOrigin()
                hasUsedSidebarNavigation = true
                store.goToSettings()
            }
        } label: {
            VStack(spacing: showsTitle ? 2 : 0) {
                Image(systemName: RadixIcon.settings)
                    .font(.system(size: 16, weight: .semibold))
                if showsTitle {
                    Text("Settings")
                        .font(ResponsiveFont.tinySystem(size: 10, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.52)
                }
            }
            .foregroundStyle(isActive ? Color.white : Color.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: showsTitle ? 48 : 42)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Color.accentColor : RadixTheme.secondaryBackground.opacity(0.65))
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
        .accessibilityValue(isActive ? "Selected" : "")
        .accessibilityHint("\(RadixNavigationGuideTopic.settings.summary) Select Settings again to show its guide.")
        .overlay(
            Group {
                if isActive {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                } else {
                    EmptyView()
                }
            }
        )
        .help(RadixNavigationGuideTopic.settings.summary)
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
            .background(RadixTheme.secondaryBackground.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(RadixTheme.separator, lineWidth: 0.5)
            )
        }
    }

}
