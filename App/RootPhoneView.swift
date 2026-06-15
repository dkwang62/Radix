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
        case 2: return "Browse"
        case 3: return "Study"
        case 4: return "AI Link"
        case 5: return "My Data"
        default: return "Radix"
        }
    }

    @ViewBuilder
    var iPhoneView: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BreadcrumbStrip()
                phoneGlobalActionRow
                phoneContent
                    .frame(maxHeight: .infinity, alignment: .top)
                phoneTabBar
            }
            .navigationTitle(phoneTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: RadixIcon.settings)
                    }
                    .accessibilityLabel("Settings")
                }
            }
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
                onSaveSnapshot: quickSaveMemory,
                onRestoreSnapshot: quickRestoreMemory(from:),
                onRefreshSnapshots: refreshQuickLocalSnapshots,
                localSnapshots: quickLocalSnapshots,
                isSavingSnapshot: isQuickSavingMemory,
                isRestoringSnapshot: isQuickRestoringMemory
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
        default:
            SmartSearchTab()
        }
    }

    var phoneSnapshotSaveBar: some View {
        let datedCopiesLocked = entitlement.requiresPro(.datedCopies)

        return VStack(spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                Button(action: quickSaveMemory) {
                    phoneSnapshotBarLabel(
                        title: isQuickSavingMemory ? "Saving..." : "Save",
                        systemImage: isQuickSavingMemory ? "hourglass" : (datedCopiesLocked ? "lock.fill" : "tray.and.arrow.down"),
                        lockBadge: datedCopiesLocked ? "Plus" : nil
                    )
                }
                .buttonStyle(.plain)
                .disabled(isQuickSavingMemory || isQuickRestoringMemory)
                .accessibilityLabel(isQuickSavingMemory ? "Saving" : "Save")

                if datedCopiesLocked {
                    Button {
                        presentPaywall(for: .datedCopies)
                    } label: {
                        phoneSnapshotBarLabel(
                            title: "Restore",
                            systemImage: "lock.fill",
                            lockBadge: "Plus"
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isQuickSavingMemory || isQuickRestoringMemory)
                    .accessibilityLabel("Restore")
                } else {
                    Menu {
                        restoreSnapshotMenuContent
                    } label: {
                        phoneSnapshotBarLabel(
                            title: isQuickRestoringMemory ? "Restoring..." : "Restore",
                            systemImage: isQuickRestoringMemory ? "hourglass" : "arrow.counterclockwise",
                            lockBadge: nil
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isQuickSavingMemory || isQuickRestoringMemory)
                    .accessibilityLabel("Restore")
                    .onAppear {
                        refreshQuickLocalSnapshots()
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    var phoneGlobalActionRow: some View {
        HStack(spacing: 8) {
            Button {
                store.goToSearchRoot()
                store.showiPhoneDetail = false
            } label: {
                phoneGlobalActionLabel(
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
                phoneGlobalActionLabel(
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

    func phoneGlobalActionLabel(
        title: String,
        subtitle: String,
        systemImage: String,
        isPrimary: Bool
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 34, height: 34)
                .foregroundStyle(isPrimary ? Color.white : Color.accentColor)
                .background(isPrimary ? Color.white.opacity(0.18) : Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(ResponsiveFont.subheadline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(subtitle)
                    .font(ResponsiveFont.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .opacity(isPrimary ? 0.86 : 0.72)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .foregroundStyle(isPrimary ? Color.white : Color.primary)
        .background(isPrimary ? Color.accentColor : RadixTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    func phoneSnapshotBarLabel(title: String, systemImage: String, lockBadge: String?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(ResponsiveFont.caption.weight(.semibold))
            Text(title)
                .font(ResponsiveFont.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let lockBadge {
                Text(lockBadge)
                    .font(ResponsiveFont.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .foregroundStyle(Color.accentColor)
        .background(Color.accentColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var phoneTabBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 4) {
                tabButton(.browse)
                tabButton(.study)
                tabButton(.aiLink)
                tabButton(.myData)
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
        let showsTitle = store.sidebarNavigationStyle == .descriptive
        let isActive = {
            if store.route == .capture { return id == 0 }
            if store.route == .favourites { return id == 3 }
            if store.route == .aiLink { return id == 4 }
            if store.route == .lineage { return false }
            switch store.homeTab {
            case .smart: return id == 1
            case .filter: return id == 2
            case .favourites: return id == 3
            case .dataEdit: return id == 5
            }
        }()

        return Button {
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
    }
}
