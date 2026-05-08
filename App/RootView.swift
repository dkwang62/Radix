import SwiftUI
import UniformTypeIdentifiers

/*
 RADIX - ROOT UI ARCHITECTURE
 =================================
 RootView serves as the primary container and layout orchestrator for the iPad app.
 It implements a NavigationSplitView (Sidebar + Detail) pattern.
 
 RESPONSIBILITIES:
 1. Sidebar: Primary navigation (Search, Browse, Favorites, Lineage, AI, DataEdit).
 2. Detail Pane: Dynamic view switching based on 'RadixStore.route'.
 3. Global Sheets: Manages Paywalls, Lineage Explorers, and Data Transfer Alerts.
 4. File Lifecycle: Handles JSON Export/Import via system file pickers.
*/

struct RootView: View {
    private static let stableStrokeToken = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
    private let dataExportService = DataExportService()
    @EnvironmentObject private var store: RadixStore
    @EnvironmentObject private var entitlement: EntitlementManager
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var scenePhase
    @State private var profileExportDocument = JSONFileDocument(data: Data())
    @State private var addPhrasesExportDocument = AddPhrasesFileDocument(data: Data())
    @State private var showProfileExporter = false
    @State private var showProfileImporter = false
    @State private var showAddPhrasesExporter = false
    @State private var showAddPhrasesImporter = false
    @State private var importExportError: String?
    @State private var importExportMessage: String?
    @State private var showImportExportAlert = false
    @State private var showSettings = false

    private func readImportedFileData(from url: URL) throws -> Data {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try Data(contentsOf: url)
    }

    var body: some View {
        Group {
            if sizeClass == .compact {
                iPhoneView
            } else {
                iPadView
            }
        }
        #if targetEnvironment(macCatalyst)
        .dynamicTypeSize(.accessibility3) // Force system-wide large fonts
        #endif
        .fileExporter(
            isPresented: $showProfileExporter,
            document: profileExportDocument,
            contentType: .json,
            defaultFilename: "radix_user_data"
        ) { result in
            switch result {
            case .success(let url):
                importExportMessage = "Profile backup saved successfully to: \(url.lastPathComponent)"
                showImportExportAlert = true
            case .failure(let error):
                importExportError = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $showProfileImporter,
            allowedContentTypes: [.json, .data],
            allowsMultipleSelection: false
        ) { result in
            do {
                let url = try result.get().first
                guard let url else { return }
                let data = try readImportedFileData(from: url)
                try store.importProfileData(data)
                importExportMessage = "Profile successfully imported from: \(url.lastPathComponent)"
                showImportExportAlert = true
            } catch {
                importExportError = error.localizedDescription
            }
        }
        .fileExporter(
            isPresented: $showAddPhrasesExporter,
            document: addPhrasesExportDocument,
            contentType: AddPhrasesFileDocument.contentType,
            defaultFilename: "phrases_add.db"
        ) { result in
            switch result {
            case .success(let url):
                importExportMessage = "Phrases additions file exported to: \(url.lastPathComponent)"
                showImportExportAlert = true
            case .failure(let error):
                importExportError = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $showAddPhrasesImporter,
            allowedContentTypes: AddPhrasesFileDocument.readableContentTypes,
            allowsMultipleSelection: false
        ) { result in
            do {
                let url = try result.get().first
                guard let url else { return }
                try store.setAddPhrasesFile(url: url)
                importExportMessage = "Using phrase additions file: \(url.lastPathComponent)"
                showImportExportAlert = true
            } catch {
                importExportError = error.localizedDescription
            }
        }
        .alert("Data Transfer", isPresented: $showImportExportAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            if let msg = importExportMessage {
                Text(msg)
            }
        }
        .alert("Transfer Error", isPresented: Binding(get: {
            importExportError != nil
        }, set: { newValue in
            if !newValue { importExportError = nil }
        })) {
            Button("OK", role: .cancel) { importExportError = nil }
        } message: {
            Text(importExportError ?? "")
        }
        .sheet(isPresented: $store.showPaywall) {
            PaywallView(featureName: store.paywallFeatureName)
                .environmentObject(entitlement)
        }
        .sheet(item: $store.quickEditDestination) { destination in
            QuickEditSheet(destination: destination)
                .environmentObject(store)
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
                    .environmentObject(store)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                store.flushPendingDataEditAutoSave()
            }
        }
    }

    private var iPadView: some View {
        NavigationSplitView {
            sidebar
                .navigationTitle("Radix")
                .navigationSplitViewColumnWidth(min: 320, ideal: 360, max: 420)
        } detail: {
            detailPane
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var iPhoneView: some View {
        let selection: Int = {
            if store.route == .capture { return 0 }
            if store.route == .aiLink { return 4 }
            if store.route == .lineage { return -1 }
            switch store.homeTab {
            case .smart: return 1
            case .filter: return 2
            case .favourites: return 3
            case .dataEdit: return 5
            }
        }()
        let title: String = {
            switch selection {
            case -1: return "Components"
            case 0: return "Image"
            case 1: return "Search"
            case 2: return store.selectedBrowseCollection.map { "Browse – \($0.name)" } ?? "Browse – Dictionary"
            case 3: return "Favorites"
            case 4: return "AI"
            case 5: return "My Data"
            default: return "Radix"
            }
        }()

        NavigationStack {
            VStack(spacing: 0) {
                BreadcrumbStrip()
                // Content
                Group {
                    switch selection {
                    case -1: ComponentsExplorerShell()
                    case 0: CaptureTab()
                    case 1: SmartSearchTab()
                    case 2: FilterGridTab()
                    case 3:
                        FavouritesTab(
                            onExportProfile: {
                                if entitlement.requiresPro(.profileTransfer) {
                                    store.showPaywall(for: .profileTransfer)
                                    return
                                }
                                do {
                                    profileExportDocument = JSONFileDocument(data: try store.exportProfileData())
                                    showProfileExporter = true
                                } catch { importExportError = error.localizedDescription }
                            },
                            onImportProfile: {
                                if entitlement.requiresPro(.profileTransfer) {
                                    store.showPaywall(for: .profileTransfer)
                                    return
                                }
                                showProfileImporter = true
                            },
                            onRequirePro: { gate in store.showPaywall(for: gate) }
                        )
                    case 4:
                        if let current = store.previewCharacter,
                           let item = store.item(for: current) {
                            AILinkView(item: item)
                        } else if store.selectedAICollection != nil {
                            AILinkView(item: nil)
                        } else {
                            emptyStateCard(
                                systemImage: "sparkles",
                                title: "No Subject",
                                message: "Choose a character for Tasks 1-3 or a page for Tasks 4-5."
                            )
                        }
                    case 5:
                        DataEditTab(
                            onLoadAddPhrases: {
                                if entitlement.requiresPro(.dataEdit) {
                                    store.showPaywall(for: .dataEdit)
                                    return
                                }
                                showAddPhrasesImporter = true
                            },
                            onExportAddPhrases: {
                                if entitlement.requiresPro(.dataEdit) {
                                    store.showPaywall(for: .dataEdit)
                                    return
                                }
                                do {
                                    addPhrasesExportDocument = AddPhrasesFileDocument(data: try store.exportAddPhrasesDB())
                                    showAddPhrasesExporter = true
                                } catch {
                                    importExportError = error.localizedDescription
                                }
                            },
                            onUseDefaultAddPhrases: {
                                if entitlement.requiresPro(.dataEdit) {
                                    store.showPaywall(for: .dataEdit)
                                    return
                                }
                                do {
                                    try store.restoreDefaultAddPhrasesFile()
                                    importExportMessage = "Using the default phrases_add.db file."
                                    showImportExportAlert = true
                                } catch {
                                    importExportError = error.localizedDescription
                                }
                            },
                            onRequirePro: { gate in store.showPaywall(for: gate) }
                        )
                    default:
                        SmartSearchTab()
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)

                // Custom compact tab bar (keeps core workflow one tap away)
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
            .navigationTitle(title)
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
            .navigationDestination(isPresented: $store.showiPhoneDetail) {
                if let current = store.previewCharacter,
                   let item = store.item(for: current) {
                    VStack(spacing: 12) {
                        BreadcrumbStrip()
                        CharacterDetailView(item: item)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        let exportProfile = {
            if entitlement.requiresPro(.profileTransfer) {
                presentPaywall(for: .profileTransfer)
                return
            }
            do {
                profileExportDocument = JSONFileDocument(data: try store.exportProfileData())
                showProfileExporter = true
            } catch {
                importExportError = error.localizedDescription
            }
        }
        let importProfile = {
            if entitlement.requiresPro(.profileTransfer) {
                presentPaywall(for: .profileTransfer)
                return
            }
            showProfileImporter = true
        }
        let requirePro: (EntitlementManager.FeatureGate) -> Void = { gate in
            presentPaywall(for: gate)
        }

        VStack(spacing: 12) {
            BreadcrumbStrip()
            if let error = store.loadingError {
                ContentUnavailableView("Failed to Load", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                switch store.route {
                case .capture:
                    CaptureTab()
                case .search:
                    SearchHomeView(
                    onExportProfile: exportProfile,
                    onImportProfile: importProfile,
                    onLoadAddPhrases: {
                        if entitlement.requiresPro(.dataEdit) {
                            presentPaywall(for: .dataEdit)
                            return
                        }
                        showAddPhrasesImporter = true
                    },
                    onExportAddPhrases: {
                        if entitlement.requiresPro(.dataEdit) {
                            presentPaywall(for: .dataEdit)
                            return
                        }
                        do {
                            addPhrasesExportDocument = AddPhrasesFileDocument(data: try store.exportAddPhrasesDB())
                            showAddPhrasesExporter = true
                        } catch {
                            importExportError = error.localizedDescription
                        }
                    },
                    onUseDefaultAddPhrases: {
                        if entitlement.requiresPro(.dataEdit) {
                            presentPaywall(for: .dataEdit)
                            return
                        }
                        do {
                            try store.restoreDefaultAddPhrasesFile()
                            importExportMessage = "Using the default phrases_add.db file."
                            showImportExportAlert = true
                        } catch {
                            importExportError = error.localizedDescription
                        }
                    },
                    onRequirePro: requirePro
                    )
                case .lineage:
                    if store.previewCharacter == nil {
                        emptyStateCard(
                        systemImage: "tree",
                        title: "No Character",
                        message: "Choose a character from Search or Browse to explore Components."
                    )
                    } else {
                        ComponentsExplorerShell(seedOverride: store.previewCharacter)
                    }
                case .favourites:
                    FavouritesTab(
                    onExportProfile: exportProfile,
                    onImportProfile: importProfile,
                    onRequirePro: requirePro
                )
                case .aiLink:
                    if let current = store.previewCharacter,
                       let item = store.item(for: current) {
                        AILinkView(item: item)
                    } else if store.selectedAICollection != nil {
                        AILinkView(item: nil)
                    } else {
                        emptyStateCard(
                            systemImage: "sparkles",
                            title: "No Subject",
                            message: "Choose a character for Tasks 1-3 or a page for Tasks 4-5."
                        )
                    }
                }
            }
        }
        .navigationTitle(detailPaneTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var detailPaneTitle: String {
        switch store.route {
        case .capture:   return "Image"
        case .search:
            switch store.homeTab {
            case .smart:      return "Search"
            case .filter:     return store.selectedBrowseCollection.map { "Browse – \($0.name)" } ?? "Browse – Dictionary"
            case .favourites: return "Favorites"
            case .dataEdit:   return "My Data"
            }
        case .lineage:    return "Components"
        case .favourites: return "Favorites"
        case .aiLink:     return "AI Link"
        }
    }

    private var sidebar: some View {
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
                                    isVertical: true // Always use vertical stacking in the narrow sidebar
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
            }
            .padding(8) // Reduced from 12
        }
    }

    private func sidebarIconButton(
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

    private func presentPaywall(for gate: EntitlementManager.FeatureGate) {
        store.showPaywall(for: gate)
    }
    
    private func tabButton(id: Int, title: String, icon: String, usesSystemImage: Bool = true) -> some View {
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
                if id == 2 {
                    store.prepareBrowseReturnScrollTarget()
                } else {
                    store.previewCharacter = nil
                }
                store.showiPhoneDetail = false
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
                store.prepareBrowseReturnScrollTarget()
                store.clearBrowsePreview()
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
