import SwiftUI
import UniformTypeIdentifiers

/*
 RADIX - ROOT UI ARCHITECTURE
 =================================
 RootView serves as the primary container and layout orchestrator for the iPad app.
 It implements a NavigationSplitView (Sidebar + Detail) pattern.
 
 RESPONSIBILITIES:
 1. Sidebar: Primary navigation (Search, Browse, Favourites, Lineage, AI, DataEdit).
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
            case -1: return "Roots"
            case 0: return "Camera"
            case 1: return "Search"
            case 2: return "Browse"
            case 3: return "Favourites"
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
                        } else {
                            emptyStateCard(
                                systemImage: "sparkles",
                                title: "No Character",
                                message: "Choose a character from Search or Browse to use AI Link."
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
                    tabButton(id: 0, title: "Camera", system: "camera")
                    tabButton(id: 1, title: "Search", system: "magnifyingglass")
                    tabButton(id: 2, title: "Browse", system: "square.grid.2x2")
                    tabButton(id: 3, title: "Favs", system: "star")
                    tabButton(id: 4, title: "AI", system: "sparkles")
                    tabButton(id: 5, title: "My Data", system: "pencil.and.outline")
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(Color(.systemBackground).opacity(0.95))
                .overlay(Divider(), alignment: .top)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $store.showiPhoneDetail) {
                if let current = store.previewCharacter ?? store.selectedCharacter,
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
                    if store.previewCharacter == nil && store.selectedCharacter == nil {
                        emptyStateCard(
                        systemImage: "tree",
                        title: "No Character",
                        message: "Choose a character from Search or Browse to explore Roots."
                    )
                    } else {
                        ComponentsExplorerShell(seedOverride: store.previewCharacter ?? store.selectedCharacter)
                    }
                case .favourites:
                    FavouritesTab(
                    onExportProfile: exportProfile,
                    onImportProfile: importProfile,
                    onRequirePro: requirePro
                )
                case .aiLink:
                    if let current = store.previewCharacter ?? store.selectedCharacter,
                       let item = store.item(for: current) {
                        AILinkView(item: item)
                    } else {
                        emptyStateCard(
                            systemImage: "sparkles",
                            title: "No Character",
                            message: "Choose a character from Search or Browse to use AI Link."
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
        case .capture:   return "Camera"
        case .search:
            switch store.homeTab {
            case .smart:      return "Search"
            case .filter:     return "Browse"
            case .favourites: return "Favorites"
            case .dataEdit:   return "My Data"
            }
        case .lineage:    return "Roots"
        case .favourites: return "Favorites"
        case .aiLink:     return "AI Link"
        }
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    sidebarIconButton(
                        title: "Camera",
                        systemImage: "camera",
                        isActive: store.route == .capture
                    ) {
                        store.route = .capture
                    }
                    sidebarIconButton(
                        title: "Search",
                        systemImage: "magnifyingglass",
                        isActive: store.route == .search && store.homeTab == .smart
                    ) {
                        store.goToSearchRoot()
                    }
                    sidebarIconButton(
                        title: "Browse",
                        systemImage: "square.grid.2x2",
                        isActive: store.route == .search && store.homeTab == .filter
                    ) {
                        store.goToBrowse()
                    }
                    sidebarIconButton(
                        title: "Favourites",
                        systemImage: "star",
                        isActive: store.route == .search && store.homeTab == .favourites
                    ) {
                        store.goToFavourites()
                    }
                    sidebarIconButton(
                        title: "AI Link",
                        systemImage: "sparkles",
                        isActive: store.route == .aiLink
                    ) {
                        store.enterAILink()
                    }
                    sidebarIconButton(
                        title: "My Data",
                        systemImage: "pencil.and.outline",
                        isActive: store.route == .search && store.homeTab == .dataEdit
                    ) {
                        store.goToDataEdit()
                    }
                }
                .padding(10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                if let current = store.previewCharacter ?? store.selectedCharacter {
                    VStack(alignment: .leading, spacing: 8) {
                        CharacterPreviewHeader(
                            character: current,
                            showClearButton: false,
                            showAddToMemoryButton: !(store.route == .search && store.homeTab == .favourites),
                            isVertical: true // Always use vertical stacking in the narrow sidebar
                        )
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
        systemImage: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(ResponsiveFont.headline)
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
    
    private func tabButton(id: Int, title: String, system: String) -> some View {
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
                store.previewCharacter = nil
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
            case 3:
                store.route = .search
                store.homeTab = .favourites
            default:
                store.route = .search
                store.homeTab = .smart
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: system)
                    .font(.system(size: 15, weight: .semibold))
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

private struct SearchHomeView: View {
    @EnvironmentObject private var store: RadixStore
    @EnvironmentObject private var entitlement: EntitlementManager
    let onExportProfile: () -> Void
    let onImportProfile: () -> Void
    let onLoadAddPhrases: () -> Void
    let onExportAddPhrases: () -> Void
    let onUseDefaultAddPhrases: () -> Void
    let onRequirePro: (EntitlementManager.FeatureGate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch store.homeTab {
            case .smart:
                SmartSearchTab()
            case .filter:
                FilterGridTab()
            case .favourites:
                FavouritesTab(
                    onExportProfile: onExportProfile,
                    onImportProfile: onImportProfile,
                    onRequirePro: onRequirePro
                )
            case .dataEdit:
                DataEditTab(
                    onLoadAddPhrases: onLoadAddPhrases,
                    onExportAddPhrases: onExportAddPhrases,
                    onUseDefaultAddPhrases: onUseDefaultAddPhrases,
                    onRequirePro: onRequirePro
                )
            }
        }
        .padding(.vertical, 8)
    }
}

private func emptyStateCard(systemImage: String, title: String, message: String) -> some View {
    VStack(spacing: 8) {
        Image(systemName: systemImage)
            .font(.system(size: 44, weight: .light))
            .foregroundStyle(.secondary)
        Text(title)
            .font(ResponsiveFont.title3.bold())
        Text(message)
            .font(ResponsiveFont.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .center)
    .background(Color(.secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .padding()
}

@MainActor
func standardPhoneCharacterPreview(
    character: String,
    selectedCharacter: String?,
    showAddToMemoryButton: Bool = true,
    onClear: @escaping () -> Void
) -> some View {
    CharacterPreviewHeader(
        character: character,
        showClearButton: true,
        showAddToMemoryButton: showAddToMemoryButton,
        onClear: onClear
    )
    .padding(.bottom, 10)
}

struct CompactScriptFilterControl: View {
    let selection: ScriptFilter
    let onChange: (ScriptFilter) -> Void

    private var simplifiedActive: Bool {
        selection == .any || selection == .simplified
    }

    private var traditionalActive: Bool {
        selection == .any || selection == .traditional
    }

    var body: some View {
        HStack(spacing: 4) {
            scriptButton("简", isActive: simplifiedActive) {
                switch selection {
                case .any:
                    onChange(.simplified)
                case .simplified:
                    onChange(.any)
                case .traditional:
                    onChange(.any)
                }
            }

            scriptButton("繁", isActive: traditionalActive) {
                switch selection {
                case .any:
                    onChange(.traditional)
                case .simplified:
                    onChange(.any)
                case .traditional:
                    onChange(.any)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Character set")
        .accessibilityValue(selection.rawValue)
    }

    private func scriptButton(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(ResponsiveFont.subheadline.weight(.semibold))
                .frame(width: 34, height: 34)
                .background(isActive ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundStyle(isActive ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }
}
