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
                    title: "Take Photo",
                    subtitle: "Capture text",
                    systemImage: "camera.fill",
                    isPrimary: true
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Take Photo")
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
            if let topic = item.guideTopic {
                DispatchQueue.main.async {
                    offerNavigationGuide(topic)
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
        .accessibilityHint(item.subtitle)
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
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.55).onEnded { _ in
                offerNavigationGuide(guideTopic, force: true)
            }
        )
        .help(guideTopic.summary)
    }

    var sidebarSettingsTabButton: some View {
        let showsTitle = store.sidebarNavigationStyle == .descriptive

        return Button {
            hasUsedSidebarNavigation = true
            store.goToSettings()
            DispatchQueue.main.async {
                offerNavigationGuide(.settings)
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
            .foregroundStyle(store.route == .settings ? Color.white : Color.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: showsTitle ? 48 : 42)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(store.route == .settings ? Color.accentColor : RadixTheme.secondaryBackground.opacity(0.65))
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
        .accessibilityValue(store.route == .settings ? "Selected" : "")
        .accessibilityHint(RadixNavigationGuideTopic.settings.summary)
        .overlay(
            Group {
                if store.route == .settings {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                } else {
                    EmptyView()
                }
            }
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.55).onEnded { _ in
                offerNavigationGuide(.settings, force: true)
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
