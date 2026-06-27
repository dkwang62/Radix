import SwiftUI

extension RootView {
    var phoneDetailNavigationBinding: Binding<Bool> {
        Binding(
            get: {
                store.showiPhoneDetail && !(store.route == .search && store.homeTab == .filter)
            },
            set: { isPresented in
                store.showiPhoneDetail = isPresented
            }
        )
    }

    var phoneSelection: Int {
        if store.route == .capture { return 0 }
        if store.route == .favourites { return 3 }
        if store.route == .aiLink { return 4 }
        if store.route == .settings { return 6 }
        if store.route == .lineage { return -1 }
        switch store.homeTab {
        case .smart: return 1
        case .filter: return 2
        case .favourites: return 3
        case .dataEdit: return 5
        }
    }

    var phoneTitle: String {
        switch phoneSelection {
        case -1: return "Character Breakdown"
        case 0: return "Take Photo"
        case 1: return "Search"
        case 2: return browseNavigationTitle
        case 3: return "Study"
        case 4: return "AI Link"
        case 5: return "My Data"
        case 6: return "Settings"
        default: return "Radix"
        }
    }

    @ViewBuilder
    var iPhoneView: some View {
        NavigationStack {
            VStack(spacing: 0) {
                crossTabReturnBar
                BreadcrumbStrip()
                phoneGlobalActionRow
                phoneContent
                    .frame(maxHeight: .infinity, alignment: .top)
                phoneTabBar
            }
            .navigationTitle(phoneTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: phoneDetailNavigationBinding) {
                if let current = store.previewCharacter,
                   let item = store.item(for: current) {
                    VStack(spacing: 12) {
                        BreadcrumbStrip()
                        CharacterDetailView(item: item)
                    }
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                store.showiPhoneDetail = false
                            } label: {
                                Label("Back", systemImage: "chevron.left")
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    var phoneContent: some View {
        switch phoneSelection {
        case -1:
            ComponentsExplorerShell()
        case 0:
            CaptureTab(
                shouldOpenCamera: $shouldOpenPhoneCamera,
                presentation: .directCamera
            )
        case 1:
            SmartSearchTab()
        case 2:
            FilterGridTab()
        case 3:
            FavouritesTab(
                onExportProfile: exportProfile,
                onImportProfile: importProfile,
                onRequirePro: { gate in store.showPaywall(for: gate) },
                onOpenProtectRecover: {
                    store.goToDataEdit(preservingOrigin: true)
                },
                onCreateCheckpoint: quickSaveMemory,
                onReturnToCheckpoint: quickRestoreMemory(from:),
                onRefreshCheckpoints: refreshQuickLocalSnapshots,
                checkpoints: quickLocalSnapshots,
                isCreatingCheckpoint: isQuickSavingMemory,
                isReturningToCheckpoint: isQuickRestoringMemory
            )
        case 4:
            aiLinkContent
        case 5:
            DataEditTab(
                onLoadAddPhrases: loadAddPhrases,
                onExportAddPhrases: exportAddPhrases,
                onUseDefaultAddPhrases: useDefaultAddPhrases,
                onRequirePro: { gate in store.showPaywall(for: gate) }
            )
        case 6:
            SettingsView(showsCloseButton: false) {
                hasSeenWelcome = false
            }
            .environmentObject(store)
        default:
            SmartSearchTab()
        }
    }

    var phoneGlobalActionRow: some View {
        HStack(spacing: 8) {
            Button {
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
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    var phoneTabBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 4) {
                tabButton(.browse)
                tabButton(.study)
                tabButton(.aiLink)
                tabButton(.myData)
                phoneSettingsTabButton
            }
            .padding(.top, 8)
            .padding(.bottom, 7)
            .padding(.horizontal, 6)
        }
        .background(.bar)
        .shadow(color: Color.black.opacity(0.06), radius: 8, y: -2)
    }

    func tabButton(_ item: RadixNavigationItem) -> some View {
        let id = item.rawValue
        let guideTopic = item.guideTopic ?? .browse
        let showsTitle = store.sidebarNavigationStyle == .descriptive
        let isActive = {
            if store.route == .capture { return id == 0 }
            if store.route == .favourites { return id == 3 }
            if store.route == .aiLink { return id == 4 }
            if store.route == .lineage { return false }
            if store.route == .settings { return false }
            switch store.homeTab {
            case .smart: return id == 1
            case .filter: return id == 2
            case .favourites: return id == 3
            case .dataEdit: return id == 5
            }
        }()

        return Button {
            handleNavigationGuideTap(guideTopic, isActive: isActive) {
                store.clearCrossTabOrigin()
                if RadixPlatform.isPhone {
                    if id != 2 {
                        store.previewCharacter = nil
                        store.showiPhoneDetail = false
                    }
                }
                switch id {
                case 0:
                    store.startBrowseCameraPage()
                case 4:
                    store.route = .aiLink
                case 1:
                    store.route = .search
                    store.homeTab = .smart
                case 2:
                    store.route = .search
                    store.homeTab = .filter
                    store.returnToBrowseGrid()
                case 3:
                    store.route = .search
                    store.homeTab = .favourites
                case 5:
                    store.goToDataEdit()
                default:
                    store.route = .search
                    store.homeTab = .smart
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
                        .transition(.opacity)
                }
            }
            .foregroundStyle(isActive ? Color.white : Color.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: showsTitle ? 48 : 42)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Color.accentColor : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityValue(isActive ? "Selected" : "")
        .accessibilityHint("\(item.subtitle) Tap this selected destination again to show its guide.")
    }

    var phoneSettingsTabButton: some View {
        let showsTitle = store.sidebarNavigationStyle == .descriptive
        let isActive = store.route == .settings

        return Button {
            handleNavigationGuideTap(.settings, isActive: isActive) {
                store.clearCrossTabOrigin()
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
                    .fill(isActive ? Color.accentColor : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
        .accessibilityValue(isActive ? "Selected" : "")
        .accessibilityHint("\(RadixNavigationGuideTopic.settings.summary) Tap Settings again to show its guide.")
    }
}
