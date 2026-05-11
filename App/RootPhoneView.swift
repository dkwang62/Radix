import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
        case -1: return "Components"
        case 0: return "Image"
        case 1: return "Search"
        case 2: return store.selectedBrowseCollection.map { "Browse – \($0.name)" } ?? "Browse – Dictionary"
        case 3: return "Favorites"
        case 4: return "AI"
        case 5: return "My Data"
        default: return "Radix"
        }
    }

    @ViewBuilder
    var iPhoneView: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BreadcrumbStrip()
                phoneContent
                    .frame(maxHeight: .infinity, alignment: .top)
                phoneTabBar
            }
            .navigationTitle(phoneTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
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
            CaptureTab()
        case 1:
            SmartSearchTab()
        case 2:
            FilterGridTab()
        case 3:
            FavouritesTab(
                onExportProfile: exportProfile,
                onImportProfile: importProfile,
                onRequirePro: { gate in store.showPaywall(for: gate) }
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

    var phoneTabBar: some View {
        HStack(spacing: 6) {
            tabButton(id: 0, title: "Image", icon: "camera")
            tabButton(id: 2, title: "Browse", icon: "square.grid.2x2")
            tabButton(id: 1, title: "Search", icon: "magnifyingglass")
            tabButton(id: 3, title: "Favs", icon: "star")
            tabButton(id: 4, title: "AI", icon: "sparkles")
            tabButton(id: 5, title: "My Data", icon: "pencil.and.outline")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(.systemBackground).opacity(0.95))
        .overlay(Divider(), alignment: .top)
    }

    func tabButton(id: Int, title: String, icon: String, usesSystemImage: Bool = true) -> some View {
        let isActive = {
            if store.route == .capture { return id == 0 }
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
            #if !targetEnvironment(macCatalyst)
            if UIDevice.current.userInterfaceIdiom == .phone {
                if id != 2 {
                    store.previewCharacter = nil
                    store.showiPhoneDetail = false
                }
            }
            #endif
            switch id {
            case 0:
                store.route = .capture
            case 4:
                store.route = .aiLink
            case 5:
                store.goToDataEdit()
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
            default:
                store.route = .search
                store.homeTab = .smart
            }
        } label: {
            VStack(spacing: 2) {
                if usesSystemImage {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                } else {
                    Text(icon)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Color.accentColor.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
