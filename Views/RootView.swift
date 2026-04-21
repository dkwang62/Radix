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
            if store.route == .aiLink { return 4 }
            if store.route == .lineage { return 2 }
            return store.homeTab.index
        }()
        let title: String = {
            switch selection {
            case 0: return "Search"
            case 1: return "Browse"
            case 2: return "Roots"
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
                    case 0: SmartSearchTab()
                    case 1: FilterGridTab()
                    case 2: ComponentsExplorerShell()
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
                            if entitlement.requiresPro(.aiLink) {
                                ProLockedView(
                                    featureName: EntitlementManager.FeatureGate.aiLink.rawValue,
                                    onUpgrade: { store.showPaywall(for: .aiLink) }
                                )
                            } else {
                                AILinkView(item: item)
                            }
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

                // Custom compact tab bar (fits 6 items, no "More")
                HStack(spacing: 6) {
                    tabButton(id: 0, title: "Search", system: "magnifyingglass")
                    tabButton(id: 1, title: "Browse", system: "square.grid.2x2")
                    tabButton(id: 2, title: "Roots", system: "tree")
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
                    if entitlement.requiresPro(.aiLink) {
                        ProLockedView(
                        featureName: EntitlementManager.FeatureGate.aiLink.rawValue,
                        onUpgrade: { presentPaywall(for: .aiLink) }
                    )
                    } else if let current = store.previewCharacter ?? store.selectedCharacter,
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
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
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
                        title: "Roots",
                        systemImage: "tree",
                        isActive: store.route == .lineage
                    ) {
                        store.enterLineage()
                    }
                    sidebarIconButton(
                        title: entitlement.requiresPro(.aiLink) ? "AI Link 🔒" : "AI Link",
                        systemImage: "sparkles",
                        isActive: store.route == .aiLink
                    ) {
                        if entitlement.requiresPro(.aiLink) {
                            presentPaywall(for: .aiLink)
                        } else {
                            store.enterAILink()
                        }
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
                            statusLabel: "Preview",
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

                if !entitlement.isProUnlocked {
                    Button("Upgrade to Pro") {
                        presentPaywall(for: .aiLink)
                    }
                    .font(ResponsiveFont.headline)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .center)
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
            if store.route == .aiLink { return id == 4 }
            if store.route == .lineage { return id == 2 }
            return store.homeTab.index == id
        }()

        return Button {
            #if !targetEnvironment(macCatalyst)
            if UIDevice.current.userInterfaceIdiom == .phone {
                store.previewCharacter = nil
                store.showiPhoneDetail = false
            }
            #endif
            switch id {
            case 4:
                store.route = .aiLink
            case 2:
                store.route = .lineage
                store.showComponentHelp = true
            case 5:
                store.goToDataEdit()
            default:
                store.route = .search
                store.homeTab = HomeTab.fromIndex(id)
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
        statusLabel: "Preview",
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

private struct SmartSearchTab: View {
    @EnvironmentObject private var store: RadixStore
    @FocusState private var isSearchFocused: Bool
    @State private var localQuery: String = ""
    @State private var searchGridPage: Int = 0
    @State private var searchPreviewCharacter: String? = nil
    @State private var searchDetailPreviewCharacter: String? = nil
    @State private var searchDrilldownPhrases: [PhraseItem] = []
    @State private var showAppleSetupGuide = false
    @State private var showAppleStrokeHelp = false
    @State private var searchCardVariantIndex: Int = 0

    private var isRunningOnMac: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        if #available(iOS 14.0, *) {
            return ProcessInfo.processInfo.isiOSAppOnMac
        }
        return false
        #endif
    }

    @ViewBuilder
    private var gridInteractionHintRow: some View {
        HStack(spacing: 10) {
            hintChip(icon: "cursorarrow", text: isRunningOnMac ? "Click Preview" : "Tap Preview")
            hintChip(icon: "cursorarrow.click.2", text: isRunningOnMac ? "Double-click or Add to memory" : "Double-tap or Add to memory")
            HStack(spacing: 4) {
                Text(isRunningOnMac ? "Right-click" : "Long-press")
                Image(systemName: "doc.on.doc")
            }
            .font(ResponsiveFont.caption)
            .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private func hintChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(ResponsiveFont.caption)
        .foregroundStyle(.secondary)
    }

    private func runSearch(_ query: String) {
        searchGridPage = 0
        searchPreviewCharacter = nil
        searchDetailPreviewCharacter = nil
        searchDrilldownPhrases = []
        store.performSearch(customQuery: query)
    }

    private func syncSearchPreviewFromStore() {
        guard store.hasPerformedSearch, searchPreviewCharacter == nil else { return }
        searchDetailPreviewCharacter = store.previewCharacter
    }

    private func setSearchDrilldownAnchor(_ character: String) {
        searchPreviewCharacter = character
        searchDetailPreviewCharacter = character
        searchDrilldownPhrases = store.phraseMatches(for: character, length: store.phraseLength)
    }

    private var initialPhraseMatchesForSelectedLength: [PhraseItem] {
        store.filteredSmartPhraseResults.filter { $0.word.count == store.phraseLength }
    }

    private var phraseLengthPicker: some View {
        HStack {
            Picker("Length", selection: $store.phraseLength) {
                Text("2-char").tag(2)
                Text("3-char").tag(3)
                Text("4-char").tag(4)
            }
            .font(ResponsiveFont.subheadline)
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)
            Spacer()
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Color.clear.frame(height: 0).id("searchTop")
                VStack(alignment: .center, spacing: 15) {
                    HStack(spacing: 12) {
                        HStack {
                            TextField("See examples", text: $localQuery)
                                .font(ResponsiveFont.body)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($isSearchFocused)
                                .submitLabel(.search)
                                .onSubmit {
                                    runSearch(localQuery)
                                }
                            
                            if !localQuery.isEmpty {
                                Button {
                                    localQuery = ""
                                    searchGridPage = 0
                                    searchPreviewCharacter = nil
                                    searchDetailPreviewCharacter = nil
                                    searchDrilldownPhrases = []
                                    store.clearSearch()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(ResponsiveFont.body)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSearchFocused ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                        .shadow(color: isSearchFocused ? Color.accentColor.opacity(0.2) : Color.clear, radius: 4)
                        
                    Button {
                        runSearch(localQuery)
                        isSearchFocused = false
                    } label: {
                        Text("Search")
                            .font(ResponsiveFont.headline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.top, 10)

                }
                .padding(.vertical, isRunningOnMac ? 30 : 16)
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))

                if store.hasPerformedSearch {
                    VStack(alignment: .leading, spacing: 15) {
                        // Preview/Info card for current previewed/selected character (phones only; sidebar shows it on iPad/Mac)
                        #if !targetEnvironment(macCatalyst)
                        if UIDevice.current.userInterfaceIdiom == .phone,
                           let current = searchDetailPreviewCharacter ?? searchPreviewCharacter,
                           store.item(for: current) != nil {
                            standardPhoneCharacterPreview(
                                character: current,
                                selectedCharacter: store.selectedCharacter,
                                onClear: {
                                    searchPreviewCharacter = nil
                                    searchDetailPreviewCharacter = nil
                                    store.previewCharacter = nil
                                }
                            )
                        }
                        #endif
                        HStack {
                            Text("\(store.filteredResults.count) characters for \"\(store.lastSearchQuery)\"")
                                .font(ResponsiveFont.title3)
                            Spacer()
                            CompactScriptFilterControl(selection: store.scriptFilter) { store.setScriptFilter($0) }
                            Button("Clear Results") {
                                    searchGridPage = 0
                                    searchPreviewCharacter = nil
                                    searchDetailPreviewCharacter = nil
                                    searchDrilldownPhrases = []
                                    store.clearSearch()
                            }
                            .font(ResponsiveFont.caption)
                        }

                        gridInteractionHintRow

                        SmartResultsGrid(
                            items: store.filteredResults,
                            currentPage: $searchGridPage,
                            onPreview: { character in
                                setSearchDrilldownAnchor(character)
                            },
                            onSelect: { withAnimation { proxy.scrollTo("searchTop", anchor: .top) } }
                        )

                        if let current = searchPreviewCharacter,
                           store.item(for: current) != nil {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Phrase Drilldown")
                                    .font(ResponsiveFont.headline)
                                Text("Preview a character from the grid to update this phrase layer. Characters inside phrases only update the preview card.")
                                    .font(ResponsiveFont.caption)
                                    .foregroundStyle(.secondary)

                                phraseLengthPicker

                                if searchDrilldownPhrases.isEmpty {
                                    Text("No \(store.phraseLength)-character phrase matches are available yet for \(current).")
                                        .font(ResponsiveFont.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(.secondarySystemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                } else {
                                    LazyVStack(alignment: .leading, spacing: 8) {
                                        ForEach(searchDrilldownPhrases.prefix(30)) { phrase in
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(phrase.word)
                                                    .font(ResponsiveFont.title3)
                                                    .phraseContextMenu(phrase)
                                                if !phrase.pinyin.isEmpty {
                                                    Text(phrase.pinyin)
                                                        .font(ResponsiveFont.subheadline)
                                                        .foregroundStyle(.secondary)
                                                }
                                                if !phrase.meanings.isEmpty {
                                                    Text(phrase.meanings)
                                                        .font(ResponsiveFont.caption)
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(2)
                                                }

                                                let chars = phrase.word.map(String.init).filter { store.item(for: $0) != nil }
                                                if !chars.isEmpty {
                                                    ScrollView(.horizontal, showsIndicators: false) {
                                                        HStack(spacing: 6) {
                                                            ForEach(Array(chars.enumerated()), id: \.offset) { _, ch in
                                                                Button(ch) {
                                                                    searchDetailPreviewCharacter = ch
                                                                    store.preview(character: ch)
                                                                    withAnimation { proxy.scrollTo("searchTop", anchor: .top) }
                                                                }
                                                                .copyCharacterContextMenu(ch, pinyin: store.item(for: ch)?.pinyinText)
                                                                .buttonStyle(.bordered)
                                                                .controlSize(.small)
                                                                .font(ResponsiveFont.body)
                                                            }
                                                        }
                                                    }
                                                    .padding(.top, 2)
                                                }
                                            }
                                            .padding(10)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color(.secondarySystemBackground))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                    }
                                }
                            }
                        }

                        if searchPreviewCharacter == nil && !store.filteredSmartPhraseResults.isEmpty {
                            Divider().padding(.vertical, 8)
                            Text("Phrase Matches")
                                .font(ResponsiveFont.headline)
                            phraseLengthPicker
                            if initialPhraseMatchesForSelectedLength.isEmpty {
                                Text("No \(store.phraseLength)-character phrase matches for this search.")
                                    .font(ResponsiveFont.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(initialPhraseMatchesForSelectedLength.prefix(50)) { phrase in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(phrase.word)
                                            .font(ResponsiveFont.title3)
                                            .phraseContextMenu(phrase)
                                        if !phrase.pinyin.isEmpty {
                                            Text(phrase.pinyin)
                                                .font(ResponsiveFont.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                        if !phrase.meanings.isEmpty {
                                            Text(phrase.meanings)
                                                .font(ResponsiveFont.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }

                                        let chars = phrase.word.map(String.init).filter { store.item(for: $0) != nil }
                                        if !chars.isEmpty {
                                            ScrollView(.horizontal, showsIndicators: false) {
                                                HStack(spacing: 6) {
                                                    ForEach(Array(chars.enumerated()), id: \.offset) { _, ch in
                                                        Button(ch) {
                                                            searchDetailPreviewCharacter = ch
                                                            store.preview(character: ch)
                                                            withAnimation { proxy.scrollTo("searchTop", anchor: .top) }
                                                        }
                                                        .copyCharacterContextMenu(ch, pinyin: store.item(for: ch)?.pinyinText)
                                                        .buttonStyle(.bordered)
                                                        .controlSize(.small)
                                                        .font(ResponsiveFont.body)
                                                    }
                                                }
                                            }
                                            .padding(.top, 2)
                                        }
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                        
                        if store.filteredResults.isEmpty && store.filteredSmartPhraseResults.isEmpty {
                            ContentUnavailableView.search(text: store.lastSearchQuery)
                        }
                    }
                } else {
                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Search by English")
                                .font(ResponsiveFont.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                SearchExampleButton(label: "=water ->", query: "水") { _ in
                                    localQuery = "=water"
                                    runSearch("=water")
                                }
                                SearchExampleButton(label: "watery ->", query: "含水") { _ in
                                    localQuery = "watery"
                                    runSearch("watery")
                                }
                            }

                            Text("Search by Pinyin")
                                .font(ResponsiveFont.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                SearchExampleButton(label: "shui ->", query: "水") { _ in
                                    localQuery = "shui"
                                    runSearch("shui")
                                }
                                SearchExampleButton(label: "hanshui ->", query: "含水") { _ in
                                    localQuery = "hanshui"
                                    runSearch("hanshui")
                                }
                            }

                            Text("Search by Apple IME Strokes")
                                .font(ResponsiveFont.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                SearchExampleButton(label: "ノ丶丶フ丨 ->", query: "含") { _ in
                                    localQuery = "ノ丶丶フ丨"
                                    runSearch("ノ丶丶フ丨")
                                }
                                SearchExampleButton(label: "丨フノ丶 ->", query: "水") { _ in
                                    localQuery = "丨フノ丶"
                                    runSearch("丨フノ丶")
                                }
                            }
                        }
                        .padding(isRunningOnMac ? 20 : 14)
                        .background(Color(.secondarySystemBackground).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .frame(maxWidth: {
                            #if targetEnvironment(macCatalyst)
                            return 900
                            #else
                            return 550
                            #endif
                        }())

                        VStack(alignment: .leading, spacing: 12) {
                            DisclosureGroup(isExpanded: $showAppleStrokeHelp) {
                                VStack(alignment: .leading, spacing: 6) {
                                    if isRunningOnMac {
                                        AppleStrokeKeyMap()
                                        AppleStrokeExamplesView()
                                    } else {
                                        AppleStrokeExamplesView(compact: true)
                                    }
                                }
                            } label: {
                                Label("Show IME Chinese Strokes examples", systemImage: "keyboard")
                                    .font(ResponsiveFont.caption.weight(.semibold))
                            }
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)

                            DisclosureGroup(isExpanded: $showAppleSetupGuide) {
                                if isRunningOnMac {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("On Mac")
                                            .font(ResponsiveFont.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                        Text("1. Apple menu > System Settings > Keyboard > Text Input > Edit.")
                                        Text("2. Add Chinese, Simplified - Stroke or Chinese, Traditional - Stroke.")
                                        Text("3. Switch to that input source from the menu bar.")
                                        Text("4. Enter the component or character in the search field above.")
                                    }
                                } else {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("On iPhone or iPad")
                                            .font(ResponsiveFont.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                        Text("1. Go to Settings > General > Keyboard > Keyboards > Add New Keyboard.")
                                        Text("2. Add Chinese, Simplified, Chinese, Traditional, or Chinese Handwriting.")
                                        Text("3. Return to this app and tap the search field above.")
                                        Text("4. Use Apple’s keyboard candidate bar to enter the component or character.")
                                        Text("If you use a hardware keyboard, you can switch keyboards with Control-Space.")
                                    }
                                }
                            } label: {
                                Label("Show keyboard setup", systemImage: "gearshape")
                                    .font(ResponsiveFont.caption.weight(.semibold))
                            }
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(isRunningOnMac ? 14 : 10)
                        .frame(maxWidth: isRunningOnMac ? 760 : .infinity)
                        .background(Color(.secondarySystemBackground).opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, isRunningOnMac ? 40 : 12)
                }
            }
            .padding(.horizontal)
            .onChange(of: store.previewCharacter) { _, _ in
                syncSearchPreviewFromStore()
            }
            .onChange(of: store.selectedCharacter) { _, _ in
                syncSearchPreviewFromStore()
            }
            .onChange(of: store.query) { _, newValue in
                localQuery = newValue
            }
            .onChange(of: store.route) { _, newRoute in
                if newRoute != .search {
                    searchPreviewCharacter = nil
                    searchDetailPreviewCharacter = nil
                    searchDrilldownPhrases = []
                }
            }
            .onChange(of: store.homeTab) { _, newTab in
                if newTab != .smart {
                    searchPreviewCharacter = nil
                    searchDetailPreviewCharacter = nil
                    searchDrilldownPhrases = []
                }
            }
            .onChange(of: store.phraseLength) { _, _ in
                if let current = searchPreviewCharacter {
                    searchDrilldownPhrases = store.phraseMatches(for: current, length: store.phraseLength)
                }
            }
            .onAppear {
                // Keep Search clean on tab entry; show preview only after explicit tap.
                searchPreviewCharacter = nil
                searchDetailPreviewCharacter = nil
                searchDrilldownPhrases = []
                localQuery = store.query
            }
        }
    }
}
}
private struct AppleStrokeKeyMap: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stroke Keys: U I O / J K L")
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                ForEach(AppleStrokeKeyGuide.topRow) { item in
                    AppleStrokeKeyCapsule(item: item)
                }
            }

            HStack(spacing: 4) {
                Spacer(minLength: 18)
                ForEach(AppleStrokeKeyGuide.bottomRow) { item in
                    AppleStrokeKeyCapsule(item: item)
                }
            }
        }
    }
}

private struct AppleStrokeKeyCapsule: View {
    let item: AppleStrokeKeyGuide

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.14), lineWidth: 1)

            VStack(spacing: 10) {
                HStack {
                    Spacer()
                    Text(item.stroke)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text(item.key)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity, minHeight: 88)
        .shadow(color: Color.black.opacity(0.08), radius: 1.5, y: 1)
    }
}

private struct AppleStrokeExamplesView: View {
    let compact: Bool

    private let examples: [(character: String, code: String)] = [
        ("含", "ノ丶丶フ丨"),
        ("水", "丨フノ丶"),
        ("天", "一一丿"),
        ("下", "一丨丶"),
        ("扌", "一丨一"),
        ("中", "丨乛一"),
        ("川", "丿丨丨"),
        ("人", "丿丶"),
        ("久", "丿乛丶"),
        ("父", "丿丶丿"),
        ("文", "丶一丿"),
        ("方", "丶一乛"),
        ("又", "乛丶"),
        ("子", "乛丨一")
    ]

    private let columns = Array(repeating: GridItem(.flexible(minimum: 96, maximum: 140), spacing: 4), count: 6)

    init(compact: Bool = false) {
        self.compact = compact
    }

    var body: some View {
        if compact {
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(examples, id: \.character) { example in
                        HStack(spacing: 10) {
                            Text(example.character)
                                .font(.system(size: 24, weight: .bold))
                                .frame(width: 28, alignment: .leading)
                            Text(example.code)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .frame(maxHeight: 220)
        } else {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
                ForEach(examples, id: \.character) { example in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(example.character)
                            .font(.system(size: 28, weight: .bold))
                        Text(example.code)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

private struct AppleStrokeKeyGuide: Identifiable {
    let stroke: String
    let key: String

    var id: String { stroke + key }

    static let topRow: [AppleStrokeKeyGuide] = [
        .init(stroke: "丶", key: "U"),
        .init(stroke: "乛", key: "I"),
        .init(stroke: "*", key: "O")
    ]

    static let bottomRow: [AppleStrokeKeyGuide] = [
        .init(stroke: "一", key: "J"),
        .init(stroke: "丨", key: "K"),
        .init(stroke: "丿", key: "L")
    ]
}

private struct SearchExampleButton: View {
    let label: String
    let query: String
    let desc: String?
    let action: (String) -> Void

    private var isPhone: Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        return UIDevice.current.userInterfaceIdiom == .phone
        #endif
    }

    init(label: String, query: String, desc: String? = nil, action: @escaping (String) -> Void) {
        self.label = label
        self.query = query
        self.desc = desc
        self.action = action
    }

    var body: some View {
        Button {
            action(query)
        } label: {
            VStack(alignment: .leading, spacing: isPhone ? 6 : 4) {
                HStack(spacing: 4) {
                    Text(label)
                        .font(isPhone ? ResponsiveFont.body : ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(query)
                        .font(isPhone ? ResponsiveFont.title3.bold() : ResponsiveFont.caption.bold())
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                if let desc = desc {
                    Text(desc)
                        .font(isPhone ? .system(size: 12) : .system(size: 9))
                        .foregroundStyle(.tertiary)
                        .italic()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(.horizontal, isPhone ? 14 : 12)
            .padding(.vertical, isPhone ? 12 : 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.accentColor.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct FilterGridTab: View {
    @EnvironmentObject private var store: RadixStore
    @Environment(\.horizontalSizeClass) var sizeClass
    @State private var showBrowseFilters = false

    private var isRunningOnMac: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        if #available(iOS 14.0, *) {
            return ProcessInfo.processInfo.isiOSAppOnMac
        }
        return false
        #endif
    }

    @ViewBuilder
    private var browseInteractionHintRow: some View {
        HStack(spacing: 10) {
            hintChip(icon: "cursorarrow", text: isRunningOnMac ? "Click Preview" : "Tap Preview")
            hintChip(icon: "cursorarrow.click.2", text: isRunningOnMac ? "Double-click or Add to memory" : "Double-tap or Add to memory")
            HStack(spacing: 4) {
                Text(isRunningOnMac ? "Right-click" : "Long-press")
                Image(systemName: "doc.on.doc")
            }
            .font(ResponsiveFont.caption)
            .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    
    private var columns: [GridItem] {
        #if targetEnvironment(macCatalyst)
        return Array(repeating: GridItem(.flexible(minimum: 40, maximum: 80), spacing: 10), count: 15)
        #else
        // iPhone: fewer columns (8) to give pinyin room to stay on one line
        return Array(repeating: GridItem(.flexible(minimum: 32, maximum: 64), spacing: 8), count: 8)
        #endif
    }

    private var fontSize: CGFloat {
        #if targetEnvironment(macCatalyst)
        return 28
        #else
        return 24
        #endif
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Color.clear.frame(height: 0).id("browseTop")
                    // Animation Preview (phones only; sidebar handles iPad/Mac)
                    #if !targetEnvironment(macCatalyst)
                    if UIDevice.current.userInterfaceIdiom == .phone,
                       let previewChar = store.previewCharacter {
                        standardPhoneCharacterPreview(
                            character: previewChar,
                            selectedCharacter: store.selectedCharacter,
                            onClear: { store.previewCharacter = nil }
                        )
                    }
                    #endif

                    HStack(alignment: .center, spacing: 12) {
                        Picker("Sort", selection: Binding(get: {
                            store.gridSortMode
                        }, set: { store.setGridSortMode($0) })) {
                            ForEach(GridSortMode.allCases) { mode in
                                Text(browseSortLabel(for: mode)).tag(mode)
                            }
                        }
                        .font(ResponsiveFont.subheadline)
                        .pickerStyle(.segmented)

                        CompactScriptFilterControl(selection: store.gridScriptFilter) { store.setGridScriptFilter($0) }

                        Button {
                            showBrowseFilters = true
                        } label: {
                            Label(filterButtonTitle, systemImage: activeBrowseFilterCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                .font(ResponsiveFont.subheadline.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.gridSortMode == .componentFrequency ? 
                             "Characters most often used as components first." :
                             "Most common characters first.")
                            .font(ResponsiveFont.caption2)
                            .italic()
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                        browseInteractionHintRow
                            .padding(.horizontal, 4)
                    }
                    .padding(.bottom, 4)

                    HStack {
                        Button("◀ Prev") { store.previousGridPage() }
                            .font(ResponsiveFont.subheadline)
                            .disabled(store.gridPage == 0)
                        Spacer()
                        Text("\(store.gridPage * store.gridBatchSize + 1)-\(min((store.gridPage + 1) * store.gridBatchSize, store.allGridItems.count)) of \(store.allGridItems.count)")
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Next ▶") { store.nextGridPage() }
                            .font(ResponsiveFont.subheadline)
                            .disabled(store.gridPage + 1 >= store.gridPageCount)
                    }

                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(store.pagedGridItems, id: \.character) { item in
                            let isActive = item.character == store.previewCharacter || item.character == store.selectedCharacter
                            Button {
                                store.preview(character: item.character)
                                withAnimation {
                                    proxy.scrollTo("browseTop", anchor: .top)
                                }
                            } label: {
                                VStack(spacing: 2) {
                                    Text(item.character)
                                        .font(.system(size: fontSize))
                                        .copyCharacterContextMenu(item.character, pinyin: item.pinyinText)
                                    Text(item.pinyinText.isEmpty ? " " : item.pinyinText)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(isActive ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2)
                                )
                                .overlay(alignment: .topTrailing) {
                                    if store.isFavorite(item.character) {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.yellow)
                                            .padding(6)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(
                                TapGesture(count: 2).onEnded {
                                    store.select(character: item.character)
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal)
                .onChange(of: store.strokeMinFilter) { _, _ in store.gridPage = 0 }
                .onChange(of: store.strokeMaxFilter) { _, _ in store.gridPage = 0 }
                .onChange(of: store.selectedRadicalFilter) { _, _ in store.gridPage = 0 }
                .onChange(of: store.selectedStructureFilter) { _, _ in store.gridPage = 0 }
                .onChange(of: store.previewCharacter) { _, _ in
                    withAnimation {
                        proxy.scrollTo("browseTop", anchor: .top)
                    }
                }
            }
            .sheet(isPresented: $showBrowseFilters) {
                browseFiltersSheet
            }
        }
    }

    private func browseSortLabel(for mode: GridSortMode) -> String {
        switch mode {
        case .componentFrequency:
            return "Components (\(store.gridFilteredComponentCount))"
        case .characterFrequency:
            return "All (\(store.gridFilteredAllCount))"
        }
    }

    private func hintChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(ResponsiveFont.caption)
        .foregroundStyle(.secondary)
    }

    private var activeBrowseFilterCount: Int {
        var count = 0
        if store.strokeMinFilter > 0 { count += 1 }
        if store.selectedRadicalFilter != "none" { count += 1 }
        if store.selectedStructureFilter != "none" { count += 1 }
        return count
    }

    private var filterButtonTitle: String {
        activeBrowseFilterCount > 0 ? "Filters (\(activeBrowseFilterCount))" : "Filters"
    }

    private var browseFiltersSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Minimum Strokes")
                            .font(ResponsiveFont.caption.bold())
                            .foregroundStyle(.secondary)
                        StrokeRangeSlider(minValue: $store.strokeMinFilter, maxValue: $store.strokeMaxFilter)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        radicalPicker
                        structurePicker
                    }
                }
                .padding()
            }
            .navigationTitle("Browse Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if activeBrowseFilterCount > 0 {
                        Button("Reset") {
                            store.strokeMinFilter = 0
                            store.selectedRadicalFilter = "none"
                            store.selectedStructureFilter = "none"
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showBrowseFilters = false
                    }
                }
            }
            .presentationDetents(sizeClass == .compact ? [.medium, .large] : [.large])
        }
    }

    private var radicalPicker: some View {
        HStack(spacing: 8) {
            Text("Radical")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
            Picker("Radical", selection: $store.selectedRadicalFilter) {
                ForEach(store.availableRadicalFilters, id: \.self) { radical in
                    Text(store.radicalFilterLabel(radical)).tag(radical)
                }
            }
            .font(ResponsiveFont.body)
            .pickerStyle(.menu)
            .frame(minWidth: 80)
        }
        .padding(.horizontal, 8)
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var structurePicker: some View {
        HStack(spacing: 8) {
            Text("Structure")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
            Picker("Structure", selection: $store.selectedStructureFilter) {
                ForEach(store.availableStructureFilters, id: \.self) { structKey in
                    Text(structKey).tag(structKey)
                }
            }
            .font(ResponsiveFont.body)
            .pickerStyle(.menu)
            .frame(minWidth: 80)
        }
        .padding(.horizontal, 8)
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct FavouritesTab: View {
    private static let addedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    @EnvironmentObject private var store: RadixStore
    @EnvironmentObject private var entitlement: EntitlementManager
    let onExportProfile: () -> Void
    let onImportProfile: () -> Void
    let onRequirePro: (EntitlementManager.FeatureGate) -> Void

    private var isPhone: Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        return UIDevice.current.userInterfaceIdiom == .phone
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("My Collection (\(store.favoriteItems.count + store.favoritePhrasesItems.count))")
                    .font(ResponsiveFont.title3.bold())
                Spacer()
                HStack(spacing: 12) {
                    Button(action: onExportProfile) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Button(action: onImportProfile) {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
                .font(ResponsiveFont.body)
                .foregroundStyle(Color.accentColor)
            }
            .padding()

            if store.favoriteItems.isEmpty && store.favoritePhrasesItems.isEmpty {
                ContentUnavailableView("No Favourites", systemImage: "star.slash", description: Text("Tap the star icon on any character or phrase to add it to this list."))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                    if isPhone, let current = store.previewCharacter {
                        VStack(alignment: .leading, spacing: 8) {
                            standardPhoneCharacterPreview(
                                character: current,
                                selectedCharacter: store.selectedCharacter,
                                showAddToMemoryButton: false,
                                onClear: { store.previewCharacter = nil }
                            )
                        }
                    }

                    if !store.favoriteItems.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Characters (\(store.favoriteItems.count))")
                                .font(ResponsiveFont.caption.bold())
                                .foregroundStyle(.secondary)

                            LazyVGrid(columns: favoriteCharacterColumns, spacing: 8) {
                                ForEach(store.favoriteItems, id: \.character) { item in
                                    favoriteCharacterCell(item)
                                }
                            }
                        }
                    }

                    if !store.favoritePhrasesItems.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Phrases (\(store.favoritePhrasesItems.count))")
                                .font(ResponsiveFont.caption.bold())
                                .foregroundStyle(.secondary)

                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(store.favoritePhrasesItems, id: \.word) { phrase in
                                        favoritePhraseRow(phrase)
                                        Divider()
                                    }
                                }
                            }
                            .frame(height: favoritePhraseViewportHeight)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    private var favoriteCharacterColumns: [GridItem] {
        #if targetEnvironment(macCatalyst)
        return Array(repeating: GridItem(.flexible(minimum: 44, maximum: 82), spacing: 10), count: 10)
        #else
        if isPhone {
            return Array(repeating: GridItem(.flexible(minimum: 44, maximum: 72), spacing: 8), count: 4)
        }
        return Array(repeating: GridItem(.flexible(minimum: 44, maximum: 78), spacing: 8), count: 8)
        #endif
    }

    private func favoriteCharacterCell(_ item: ComponentItem) -> some View {
        let isActive = item.character == store.previewCharacter || item.character == store.selectedCharacter

        return Button {
            store.preview(character: item.character, announce: false)
        } label: {
            VStack(spacing: 2) {
                Text(item.character)
                    .font(.system(size: isPhone ? 28 : 30, weight: .bold))
                    .copyCharacterContextMenu(item.character, pinyin: item.pinyinText)
                Text(item.pinyinText.isEmpty ? " " : item.pinyinText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(isActive ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .overlay(alignment: .topTrailing) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.yellow)
                    .padding(6)
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                store.select(character: item.character)
            }
        )
    }

    private func favoritePhraseRow(_ phrase: PhraseItem) -> some View {
        let leadingColumnWidth: CGFloat = {
            #if targetEnvironment(macCatalyst)
            return 150
            #else
            return isPhone ? 96 : 120
            #endif
        }()

        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(phrase.word)
                    .font(ResponsiveFont.body.bold())
                Text(phrase.pinyin.isEmpty ? "-" : phrase.pinyin)
                    .font(ResponsiveFont.caption)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(.secondary)
            }
            .frame(width: leadingColumnWidth, alignment: .leading)

            Text(phrase.meanings.isEmpty ? "No meaning" : phrase.meanings)
                .font(ResponsiveFont.body)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: favoritePhraseRowHeight, alignment: .leading)
        .contentShape(Rectangle())
        .phraseContextMenu(phrase)
    }

    private var favoritePhraseRowHeight: CGFloat {
        #if targetEnvironment(macCatalyst)
        return 84
        #else
        return isPhone ? 72 : 82
        #endif
    }

    private var favoritePhraseViewportHeight: CGFloat {
        let visibleRows = min(max(store.favoritePhrasesItems.count, 1), 6)
        return (favoritePhraseRowHeight * CGFloat(visibleRows)) + 5
    }

    private func favoriteAddedLabel(for character: String) -> String {
        guard let addedAt = store.favoriteAddedDate(for: character) else {
            return "Saved before dates were tracked"
        }

        let relative = Self.relativeFormatter.localizedString(for: addedAt, relativeTo: Date())
        let absolute = Self.addedDateFormatter.string(from: addedAt)
        return "Added \(relative) (\(absolute))"
    }
}

private struct ProLockedView: View {
    let featureName: String
    let onUpgrade: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 26))
                .foregroundStyle(.secondary)
            Text("\(featureName) is a Pro feature")
                .font(.headline)
            Text("Upgrade to unlock this feature and future Pro updates.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Upgrade to Pro", action: onUpgrade)
                .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct AddPhrasesFileDocument: FileDocument {
    static var contentType: UTType {
        UTType(filenameExtension: "db") ?? .data
    }

    static var readableContentTypes: [UTType] { [contentType, .data] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct BreadcrumbStrip: View {
    @EnvironmentObject private var store: RadixStore

    private var activeCharacter: String? {
        if store.route == .search && store.homeTab == .dataEdit {
            let editingCharacter = store.dataEditCharacter.trimmingCharacters(in: .whitespacesAndNewlines)
            if !editingCharacter.isEmpty {
                return editingCharacter
            }
        }
        return store.previewCharacter ?? store.selectedCharacter
    }

    var body: some View {
        if !store.rootBreadcrumb.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(store.rootBreadcrumb.enumerated()), id: \.offset) { index, character in
                        let isActive = character == activeCharacter || index == store.rootBreadcrumbIndex
                        Button {
                            store.activateBreadcrumbCharacter(character)
                        } label: {
                            Text(character)
                                .font(.system(size: 22, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(isActive ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .copyCharacterContextMenu(character, pinyin: store.item(for: character)?.pinyinText)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .background(Color(.systemBackground))
        }
    }
}

private struct QuickEditSheet: View {
    let destination: QuickEditDestination
    @EnvironmentObject private var store: RadixStore

    var body: some View {
        switch destination {
        case .character(let character):
            QuickCharacterEditorView(character: character, isNew: false)
        case .newCharacter:
            QuickCharacterEditorView(character: "", isNew: true)
        case .phrase(let word):
            QuickPhraseEditorView(word: word, isNew: false)
        case .newPhrase:
            QuickPhraseEditorView(word: "", isNew: true)
        }
    }
}

private struct QuickCharacterEditorView: View {
    let initialCharacter: String
    let isNew: Bool
    @EnvironmentObject private var store: RadixStore
    @Environment(\.dismiss) private var dismiss
    @State private var editorError: String?
    @State private var characterInput: String = ""
    @State private var isLoaded: Bool = false

    init(character: String, isNew: Bool) {
        self.initialCharacter = character
        self.isNew = isNew
    }

    private var editingCharacter: String {
        isNew ? characterInput.trimmingCharacters(in: .whitespacesAndNewlines) : initialCharacter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar
            HStack {
                Text(isNew ? "Add New Character" : "Edit Character: \(initialCharacter)")
                    .font(ResponsiveFont.title3.bold())
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(.systemBackground))

            Divider()

            if isNew && !isLoaded {
                // Step 1 for new characters: enter the character first
                VStack(alignment: .leading, spacing: 16) {
                    Text("Enter the Chinese character you want to add:")
                        .font(ResponsiveFont.body)
                        .foregroundStyle(.secondary)

                    TextField("Single Chinese character", text: $characterInput)
                        .font(.system(size: 36))
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)

                    if let editorError {
                        Text(editorError)
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.red)
                    }

                    Button("Open") {
                        let key = characterInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard key.count == 1 else {
                            editorError = "Enter exactly one Chinese character."
                            return
                        }
                        do {
                            try store.createCustomDictionaryEntry(character: key)
                            editorError = nil
                            isLoaded = true
                        } catch {
                            editorError = error.localizedDescription
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(characterInput.trimmingCharacters(in: .whitespacesAndNewlines).count != 1)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                // Editor form — no ScrollView, compact layout
                editorForm
            }
        }
        .onAppear {
            if !isNew {
                store.loadDataEditEntry(for: initialCharacter)
                isLoaded = true
            }
        }
    }

    private var editorForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let editorError {
                Text(editorError)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            // Row 1: Definition
            formField("Definition / Meanings") {
                TextField("Definition / Meanings", text: $store.dataEditDefinition)
                    .textFieldStyle(.roundedBorder)
            }

            // Row 2: Pinyin
            formField("Pinyin  (one per line)") {
                TextField("e.g. fā, fà", text: $store.dataEditPinyin)
                    .textFieldStyle(.roundedBorder)
            }

            // Row 3: Radical · Strokes · Variant
            HStack(spacing: 10) {
                formField("Radical") {
                    TextField("Radical", text: $store.dataEditRadical)
                        .textFieldStyle(.roundedBorder)
                }
                formField("Strokes") {
                    TextField("Strokes", text: $store.dataEditStrokes)
                        .textFieldStyle(.roundedBorder)
                }
                formField("Variant") {
                    TextField("Variant", text: $store.dataEditVariant)
                        .textFieldStyle(.roundedBorder)
                }
            }

            // Row 4: Additional Variants · Decomposition
            HStack(spacing: 10) {
                formField("Additional Variants") {
                    TextField("e.g. 髮, 臺", text: $store.dataEditAdditionalVariants)
                        .textFieldStyle(.roundedBorder)
                }
                formField("Decomposition") {
                    TextField("Decomposition", text: $store.dataEditDecomposition)
                        .textFieldStyle(.roundedBorder)
                }
            }

            // Row 5: Related Characters · Etymology Hint
            HStack(spacing: 10) {
                formField("Related Characters") {
                    TextField("Comma-separated", text: $store.dataEditRelatedCharacters)
                        .textFieldStyle(.roundedBorder)
                }
                formField("Etymology Hint") {
                    TextField("Hint", text: $store.dataEditEtymHint)
                        .textFieldStyle(.roundedBorder)
                }
            }

            // Row 6: Etymology Details
            formField("Etymology Details") {
                TextField("Details", text: $store.dataEditEtymDetails)
                    .textFieldStyle(.roundedBorder)
            }

            Spacer(minLength: 0)

            Divider()

            // Action row
            HStack(spacing: 10) {
                if store.addedDictionaryCharacters.contains(store.dataEditCharacter) {
                    Button("Delete", role: .destructive) {
                        do {
                            try store.deleteCurrentDataEditEntry()
                            dismiss()
                        } catch {
                            editorError = error.localizedDescription
                        }
                    }
                    .buttonStyle(.bordered)
                } else if store.changedDictionaryCharacters.contains(store.dataEditCharacter) {
                    Button("Revert") {
                        store.restoreFromLibrary()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Save") {
                    do {
                        try store.saveCurrentDictionaryDraft()
                        editorError = nil
                        dismiss()
                    } catch {
                        editorError = error.localizedDescription
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .font(ResponsiveFont.body)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func formField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(ResponsiveFont.caption2)
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct QuickPhraseEditorView: View {
    let initialWord: String
    let isNew: Bool
    @EnvironmentObject private var store: RadixStore
    @Environment(\.dismiss) private var dismiss
    @State private var phraseEditorWord: String = ""
    @State private var phraseEditorPinyin: String = ""
    @State private var phraseEditorMeanings: String = ""
    @State private var phraseEditorIsExistingPhrase: Bool = false
    @State private var editorError: String?

    init(word: String, isNew: Bool) {
        self.initialWord = word
        self.isNew = isNew
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar
            HStack {
                Text(isNew ? "Add New Phrase" : "Edit Phrase")
                    .font(ResponsiveFont.title3.bold())
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(.systemBackground))

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                if let editorError {
                    Text(editorError)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.red)
                }

                // Phrase word — editable for new, display-only for existing
                VStack(alignment: .leading, spacing: 4) {
                    Text("Phrase")
                        .font(ResponsiveFont.caption2)
                        .foregroundStyle(.secondary)
                    if isNew {
                        TextField("Chinese phrase", text: $phraseEditorWord)
                            .font(ResponsiveFont.title3.bold())
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Text(phraseEditorWord)
                            .font(ResponsiveFont.title3.bold())
                            .phraseContextMenu(PhraseItem(word: phraseEditorWord, pinyin: phraseEditorPinyin, meanings: phraseEditorMeanings))
                        Text(phraseEditorIsExistingPhrase ? "Editing existing phrase" : "New phrase")
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Pinyin")
                        .font(ResponsiveFont.caption2)
                        .foregroundStyle(.secondary)
                    TextField("Pinyin", text: $phraseEditorPinyin)
                        .font(ResponsiveFont.body.monospaced())
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("English Meaning")
                        .font(ResponsiveFont.caption2)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $phraseEditorMeanings)
                        .font(ResponsiveFont.body)
                        .frame(minHeight: 160)
                        .padding(8)
                        .background(Color(.secondarySystemBackground).opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.separator), lineWidth: 0.5)
                        )
                }

                Spacer(minLength: 0)

                Divider()

                HStack(spacing: 10) {
                    if !isNew {
                        if phraseEditorIsExistingPhrase {
                            Button("Revert") {
                                store.removeDataEditPhrase(word: phraseEditorWord)
                                dismiss()
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button("Delete", role: .destructive) {
                                store.removeDataEditPhrase(word: phraseEditorWord)
                                dismiss()
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    Spacer()

                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)

                    Button("Save") {
                        do {
                            let wordToSave = isNew
                                ? store.simplifiedText(phraseEditorWord.trimmingCharacters(in: .whitespacesAndNewlines))
                                : phraseEditorWord
                            try store.addCustomPhrase(
                                word: wordToSave,
                                pinyin: phraseEditorPinyin,
                                meanings: phraseEditorMeanings
                            )
                            editorError = nil
                            dismiss()
                        } catch {
                            editorError = error.localizedDescription
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(phraseEditorWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.top, 4)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear {
            if isNew {
                phraseEditorWord = ""
                phraseEditorPinyin = ""
                phraseEditorMeanings = ""
                phraseEditorIsExistingPhrase = false
            } else {
                let simplifiedWord = store.simplifiedText(initialWord)
                if let phrase = store.mergedPhrase(for: simplifiedWord) {
                    phraseEditorWord = phrase.word
                    phraseEditorPinyin = phrase.pinyin
                    phraseEditorMeanings = phrase.meanings
                    phraseEditorIsExistingPhrase = true
                } else {
                    phraseEditorWord = simplifiedWord
                    phraseEditorPinyin = ""
                    phraseEditorMeanings = ""
                    phraseEditorIsExistingPhrase = false
                }
            }
        }
    }
}

private struct DataEditTab: View {

    @EnvironmentObject private var store: RadixStore
    @EnvironmentObject private var entitlement: EntitlementManager
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.openURL) private var openURL
    let onLoadAddPhrases: () -> Void
    let onExportAddPhrases: () -> Void
    let onUseDefaultAddPhrases: () -> Void
    let onRequirePro: (EntitlementManager.FeatureGate) -> Void

    // Backup / Restore state
    @State private var showRestorePicker = false
    @State private var pendingRestoreMode: RestoreMode = .additive
    @State private var backupMessage: String?
    @State private var backupError: String?
    @State private var showBackupAlert = false

    // Advanced Exports state
    @State private var fullDatasetFileName: String = "radix_full_dataset"
    @State private var mergedDictionaryFileName: String = "radix_merged_dictionary"
    @State private var mergedPhrasesFileName: String = "radix_merged_phrases"
    @State private var reuseExportDocument = BinaryFileDocument(data: Data())
    @State private var reuseExportFilename: String = ""
    @State private var reuseExportContentType: UTType = .json
    @State private var showReuseExporter = false
    @State private var reuseExportInProgress = false
    @State private var reuseExportMessage: String?
    private let dataExportService = DataExportService()

    // Status messages
    @State private var editorMessage: String?
    @State private var editorError: String?

    // Dictionary change editor search
    @State private var dictionaryChangeSearch: String = ""

    // Progressive disclosure — all collapsed on launch
    @State private var showAddedCharactersPreview = false
    @State private var showEditedCharactersPreview = false
    @State private var showAddedPhrasesPreview = false
    @State private var showEditedPhrasesPreview = false

    // UI toggles
    @State private var showAdvancedExports = false
    @State private var showHelp = false
    @State private var showSourceSetupGuide = false

    // Scroll-to-top support (phones only)
    @State private var dataEditScrollProxy: ScrollViewProxy?

    private let sourceCodeURL = URL(string: "https://github.com/dkwang62/Radix")!
    private let sourceCloneCommand = "git clone https://github.com/dkwang62/Radix.git"
    private let sourceSetupGuide = """
    # 📦 Radix Project – Setup & Usage Guide

    ## 🧠 Overview

    This project is an Apple (Xcode) app written in Swift.

    You will:

    1. Download the code
    2. Open it in Xcode
    3. Use Codex to work on it

    ---

    # 🖥️ 1. Requirements

    ## Hardware

    * A Mac (MacBook, iMac, Mac mini, etc.)

    ## Software

    1. Install **Xcode (version 26.4 or newer)** from the App Store
    2. Install **ChatGPT (for Codex use)**

    ---

    # 📥 2. Get the Code

    ## Easiest way (no Git needed)

    1. Open this link:
       https://github.com/dkwang62/Radix
    2. Click **Code → Download ZIP**
    3. Unzip the file

    ---

    ## Optional (if using terminal)

    ```bash
    git clone https://github.com/dkwang62/Radix.git
    cd Radix
    ```

    ---

    # ▶️ 3. Run the Project

    1. Open:
       Radix.xcodeproj

    2. Wait for Xcode to load (1–2 minutes first time)

    3. Choose a simulator (e.g. iPhone)

    4. Press ▶️ Run

    ---

    # 🤖 4. Using Codex (Important)

    ## Step 1

    Open ChatGPT

    ## Step 2

    Upload or point Codex to the project folder

    ## Step 3

    Ask Codex things like:

    * “Explain this project”
    * “Fix build errors”
    * “Add a feature”
    * “Refactor this code”

    ---

    ## 🧠 How to think about Codex

    * Codex = junior developer
    * You = decision maker

    Always:

    * review what it changes
    * test the app after changes

    ---

    # 📁 Project Structure (Simplified)

    * App/ → app entry and setup
    * Models/ → data structures
    * ViewModels/ → logic and state
    * Views/ → UI
    * Services/ → helper logic
    * Resources/ → assets
    * Tests/ → tests

    ---

    # ⚠️ Common Issues

    ## 1. First run is slow

    Normal — Xcode is indexing

    ---

    ## 2. Build fails

    In Xcode:

    * Press Shift + Cmd + K (clean)
    * Run again

    ---

    ## 3. Real iPhone not working

    Ignore — simulator works without setup

    ---

    # 🧠 Simple Workflow

    1. Open project
    2. Use Codex to make changes
    3. Run in Xcode
    4. Repeat

    ---

    # 🔥 Golden Rule

    If something breaks:

    * don’t panic
    * undo changes
    * try again

    ---

    # ✅ Summary

    You only need:

    * Mac
    * Xcode
    * This GitHub link

    Everything else is optional.

    ---

    # 📩 Repo Link

    https://github.com/dkwang62/Radix
    """

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Color.clear.frame(height: 0).id("myDataTop")

                // Info card and animation preview (phones only; sidebar shows it on iPad/Mac)
                #if !targetEnvironment(macCatalyst)
                if UIDevice.current.userInterfaceIdiom == .phone {
                    activeCharacterContext
                }
                #endif

                myDataHeader

                if showAdvancedExports {
                    premiumExportsSection
                } else {
                    backupAndRestoreSection
                    whatsInMyBackupSection
                }

                if let editorError {
                    Text(editorError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                if let editorMessage {
                    Text(editorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .fileExporter(
            isPresented: $showReuseExporter,
            document: reuseExportDocument,
            contentType: reuseExportContentType,
            defaultFilename: reuseExportFilename
        ) { result in
            reuseExportInProgress = false
            switch result {
            case .success(let url):
                let base = url.deletingPathExtension().lastPathComponent
                if reuseExportContentType == .json && reuseExportFilename == "radix_unified_backup" {
                    backupMessage = "Backup saved to: \(url.lastPathComponent)"
                    showBackupAlert = true
                } else {
                    reuseExportMessage = "Saved to: \(url.lastPathComponent)"
                    if reuseExportContentType == .json { fullDatasetFileName = base }
                    else if reuseExportFilename.hasPrefix(mergedDictionaryFileName.isEmpty ? "radix_merged_dictionary" : mergedDictionaryFileName) {
                        mergedDictionaryFileName = base
                    } else {
                        mergedPhrasesFileName = base
                    }
                }
            case .failure(let error):
                backupError = error.localizedDescription
                showBackupAlert = true
            }
        }
        .fileImporter(
            isPresented: $showRestorePicker,
            allowedContentTypes: [.json, .data],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let url = try result.get().first else { return }
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                try store.importDataEditData(data, mode: pendingRestoreMode)
                let modeLabel = pendingRestoreMode == .complete ? "Complete restore" : "Additive restore"
                backupMessage = "\(modeLabel) from: \(url.lastPathComponent)"
                showBackupAlert = true
            } catch {
                backupError = error.localizedDescription
                showBackupAlert = true
            }
        }
        .alert("Backup / Restore", isPresented: $showBackupAlert) {
            Button("OK", role: .cancel) {
                backupMessage = nil
                backupError = nil
            }
        } message: {
            if let msg = backupError {
                Text(msg)
            } else if let msg = backupMessage {
                Text(msg)
            }
        }
        .onAppear { dataEditScrollProxy = proxy }
        } // ScrollViewReader
    }

    private var myDataHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("My Data")
                    .font(ResponsiveFont.title.bold())
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showHelp.toggle() }
                } label: {
                    Image(systemName: showHelp ? "questionmark.circle.fill" : "questionmark.circle")
                        .font(ResponsiveFont.body)
                        .foregroundStyle(showHelp ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Help")

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showAdvancedExports.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showAdvancedExports ? "arrow.uturn.backward.circle" : "square.and.arrow.up.on.square")
                        Text(showAdvancedExports ? "Backup & Restore" : "Advanced")
                            .font(ResponsiveFont.caption)
                    }
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(showAdvancedExports ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
            }

            if showHelp {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Backup saves everything you've added or changed — custom characters, phrases, favorites, and AI templates — into a single file.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                    Text("Restore is additive: it merges your backup into the app's existing data rather than replacing it. Nothing is erased when you restore.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .transition(.opacity)
            }
        }
    }

    private var backupAndRestoreSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Button {
                    reuseExportInProgress = true
                    reuseExportMessage = nil
                    Task { @MainActor in
                        do {
                            let data = try dataExportService.exportPortableBackup(store.portableBackupPackage())
                            reuseExportDocument = BinaryFileDocument(data: data)
                            reuseExportFilename = "radix_unified_backup"
                            reuseExportContentType = .json
                            reuseExportInProgress = false
                            showReuseExporter = true
                        } catch {
                            reuseExportInProgress = false
                            backupError = error.localizedDescription
                            showBackupAlert = true
                        }
                    }
                } label: {
                    Label(reuseExportInProgress && reuseExportFilename.contains("backup") ? "Preparing Backup…" : "Back Up My Data", systemImage: "square.and.arrow.up.fill")
                        .font(ResponsiveFont.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(reuseExportInProgress)
            }

            VStack(spacing: 10) {
                Button {
                    pendingRestoreMode = .additive
                    showRestorePicker = true
                } label: {
                    VStack(spacing: 2) {
                        Label("Additive Restore", systemImage: "square.and.arrow.down")
                            .font(ResponsiveFont.subheadline.bold())
                        Text("Adds new data without overwriting existing")
                            .font(ResponsiveFont.caption2)
                            .opacity(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.accentColor.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    pendingRestoreMode = .complete
                    showRestorePicker = true
                } label: {
                    VStack(spacing: 2) {
                        Label("Complete Restore", systemImage: "square.and.arrow.down.fill")
                            .font(ResponsiveFont.subheadline.bold())
                        Text("Replaces all existing data with the backup")
                            .font(ResponsiveFont.caption2)
                            .opacity(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange.opacity(0.1))
                    .foregroundStyle(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var whatsInMyBackupSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's In My Backup")
                .font(ResponsiveFont.headline)

            VStack(alignment: .leading, spacing: 12) {
                DisclosureGroup("Added Characters (\(store.addedDictionaryCharacters.count))", isExpanded: $showAddedCharactersPreview) {
                    backupCharacterRows(store.addedDictionaryCharacters, badge: "Added")
                }

                DisclosureGroup("Added Phrases (\(addedPhraseEntries.count))", isExpanded: $showAddedPhrasesPreview) {
                    backupPhraseRows(addedPhraseEntries, badge: "Added")
                }

                DisclosureGroup("Edited Characters (\(store.editedDictionaryCharacters.count))", isExpanded: $showEditedCharactersPreview) {
                    backupCharacterRows(store.editedDictionaryCharacters, badge: "Edited")
                }

                DisclosureGroup("Edited Phrases (\(editedPhraseEntries.count))", isExpanded: $showEditedPhrasesPreview) {
                    backupPhraseRows(editedPhraseEntries, badge: "Edited")
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var premiumExportsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Advanced Exports")
                    .font(ResponsiveFont.headline)
                Text("Pro")
                    .font(ResponsiveFont.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.16))
                    .clipShape(Capsule())
            }

            if reuseExportInProgress && !reuseExportFilename.contains("backup") {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Preparing advanced export…")
                        .font(ResponsiveFont.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if let msg = reuseExportMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(msg)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Dismiss") { reuseExportMessage = nil }
                        .font(ResponsiveFont.caption)
                }
            }

            sourceCodeHelperSection

            premiumExportOption(
                title: "Full Dataset JSON",
                subtitle: "Best for analysis, transformation, or custom tooling built on both dictionary and phrase data.",
                filename: $fullDatasetFileName,
                fileExtension: ".json",
                systemName: "shippingbox.fill",
                color: .green,
                action: {
                    let name = fullDatasetFileName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let data = try dataExportService.exportFullDataset(store.fullDatasetExportPackage())
                    reuseExportDocument = BinaryFileDocument(data: data)
                    reuseExportFilename = name.isEmpty ? "radix_full_dataset" : name
                    reuseExportContentType = .json
                }
            )

            premiumExportOption(
                title: "Dictionary Database Export",
                subtitle: "Best for extending Radix-like dictionary products or building your own structured reference layer.",
                filename: $mergedDictionaryFileName,
                fileExtension: ".db",
                systemName: "books.vertical.fill",
                color: .blue,
                action: {
                    let name = mergedDictionaryFileName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let data = try dataExportService.exportMergedDictionaryDatabase(records: store.mergedDictionaryExportRecords())
                    reuseExportDocument = BinaryFileDocument(data: data)
                    reuseExportFilename = name.isEmpty ? "radix_merged_dictionary" : name
                    reuseExportContentType = .data
                }
            )

            premiumExportOption(
                title: "Phrase Database Export",
                subtitle: "Best for phrase-study tools, corpora experiments, and custom learning products built from your phrase layer.",
                filename: $mergedPhrasesFileName,
                fileExtension: ".db",
                systemName: "text.book.closed.fill",
                color: .teal,
                action: {
                    let name = mergedPhrasesFileName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let data = try dataExportService.exportMergedPhrasesDatabase(phrases: store.mergedPhrasesForExport())
                    reuseExportDocument = BinaryFileDocument(data: data)
                    reuseExportFilename = name.isEmpty ? "radix_merged_phrases" : name
                    reuseExportContentType = .data
                }
            )
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.08), Color.accentColor.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var sourceCodeHelperSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(ResponsiveFont.title3)
                    .foregroundStyle(Color.indigo)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Source Code")
                        .font(ResponsiveFont.subheadline.bold())
                    Text("Share a copy of the Radix project code from GitHub.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Text(sourceCodeURL.absoluteString)
                .font(ResponsiveFont.caption.monospaced())
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text("No GitHub account needed: open the link, click Code, then Download ZIP.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                Text("Git users can clone with:")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                Text(sourceCloneCommand)
                    .font(ResponsiveFont.caption.monospaced())
                    .textSelection(.enabled)
            }

            DisclosureGroup("Setup & Usage Guide", isExpanded: $showSourceSetupGuide) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(sourceSetupGuide)
                        .font(ResponsiveFont.caption)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        copyToClipboard(sourceSetupGuide)
                        reuseExportMessage = "Setup guide copied."
                    } label: {
                        Label("Copy Guide", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.top, 8)
            }
            .font(ResponsiveFont.subheadline.weight(.semibold))

            HStack(spacing: 10) {
                Button {
                    openURL(sourceCodeURL)
                } label: {
                    Label("Open Repo", systemImage: "safari")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button {
                    copyToClipboard(sourceCodeURL.absoluteString)
                    reuseExportMessage = "Repository URL copied."
                } label: {
                    Label("Copy URL", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    copyToClipboard(sourceCloneCommand)
                    reuseExportMessage = "Clone command copied."
                } label: {
                    Label("Copy Git", systemImage: "terminal")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(14)
        .background(Color.indigo.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.indigo.opacity(0.30), lineWidth: 1)
        )
    }

    private func copyToClipboard(_ value: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = value
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        #endif
    }

    @ViewBuilder
    private func backupCharacterRows(_ characters: [String], badge: String) -> some View {
        let displayed = Array(characters.prefix(80))
        let truncated = characters.count > displayed.count

        VStack(alignment: .leading, spacing: 8) {
            if characters.isEmpty {
                Text("No matching characters.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(displayed, id: \.self) { character in
                        let item = store.item(for: character)
                        backupCharacterRow(character, badge: badge, item: item)
                    }
                }

                if truncated {
                    Text("Showing the first \(displayed.count) of \(characters.count) characters.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func backupCharacterRow(_ character: String, badge: String, item: ComponentItem?) -> some View {
        let pinyin = item?.pinyinText ?? ""
        let definition = item?.definition ?? ""
        let isBuiltInCharacter = store.editedDictionaryCharactersSet.contains(character)

        HStack(alignment: .top, spacing: 10) {
            Text(character)
                .font(ResponsiveFont.title3.bold())
                .copyCharacterContextMenu(character, pinyin: pinyin)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 2) {
                if !pinyin.isEmpty {
                    Text(pinyin)
                        .font(ResponsiveFont.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Text(definition.isEmpty ? "No definition" : definition)
                    .font(ResponsiveFont.caption)
                    .lineLimit(2)
            }

            Spacer()

            HStack(spacing: 6) {
                Button("Edit") {
                    store.openQuickCharacterEditor(character)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                Button(role: isBuiltInCharacter ? nil : .destructive) {
                    if isBuiltInCharacter {
                        store.restoreDictionaryCharacterFromLibrary(character)
                    } else {
                        store.loadDataEditEntry(for: character)
                        try? store.deleteCurrentDataEditEntry()
                    }
                } label: {
                    Text(isBuiltInCharacter ? "Revert" : "Delete")
                        .font(ResponsiveFont.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded {
            store.preview(character: character)
            #if !targetEnvironment(macCatalyst)
            if UIDevice.current.userInterfaceIdiom == .phone {
                withAnimation { dataEditScrollProxy?.scrollTo("myDataTop", anchor: .top) }
            }
            #endif
        })
    }

    @ViewBuilder
    private func backupPhraseRows(_ phrases: [PhraseItem], badge: String) -> some View {
        if phrases.isEmpty {
            Text("No matching phrases.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(phrases) { phrase in
                    backupPhraseRow(phrase, badge: badge)
                }
            }
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func backupPhraseRow(_ phrase: PhraseItem, badge: String) -> some View {
        let isBuiltInPhrase = store.isPhraseInBase(phrase.word)

        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(phrase.word)
                    .font(ResponsiveFont.subheadline.bold())
                    .phraseContextMenu(phrase)

                Spacer()

                HStack(spacing: 6) {
                    Button("Edit") {
                        store.openQuickPhraseEditor(word: phrase.word)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button(role: isBuiltInPhrase ? nil : .destructive) {
                        store.removeDataEditPhrase(word: phrase.word)
                    } label: {
                        Text(isBuiltInPhrase ? "Revert" : "Delete")
                            .font(ResponsiveFont.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }

            if !phrase.pinyin.isEmpty {
                Text(phrase.pinyin)
                    .font(ResponsiveFont.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Text(phrase.meanings.isEmpty ? "No meaning" : phrase.meanings)
                .font(ResponsiveFont.caption)
                .lineLimit(2)
        }
        .padding(10)
        .background(Color(.secondarySystemBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func premiumExportOption(
        title: String,
        subtitle: String,
        filename: Binding<String>,
        fileExtension: String,
        systemName: String,
        color: Color,
        action: @escaping () throws -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("Filename", text: filename)
                    .font(ResponsiveFont.body.monospaced())
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Text(fileExtension)
                    .font(ResponsiveFont.body.monospaced())
                    .foregroundStyle(.secondary)
            }

            Button {
                guard !entitlement.requiresPro(.dataEdit) else {
                    onRequirePro(.dataEdit)
                    return
                }

                reuseExportInProgress = true
                reuseExportMessage = nil
                Task { @MainActor in
                    do {
                        try action()
                        reuseExportInProgress = false
                        showReuseExporter = true
                    } catch {
                        reuseExportInProgress = false
                        reuseExportMessage = "Export failed: \(error.localizedDescription)"
                    }
                }
            } label: {
                exportOptionCard(
                    title: title,
                    subtitle: entitlement.requiresPro(.dataEdit) ? "\(subtitle) Unlock Pro to export." : subtitle,
                    systemName: entitlement.requiresPro(.dataEdit) ? "lock.fill" : systemName,
                    color: color
                )
            }
            .buttonStyle(.plain)
            .disabled(reuseExportInProgress)
        }
    }

    @ViewBuilder
    private var dictionaryDataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label {
                Text("1. Core Dictionary")
                    .font(ResponsiveFont.headline)
            } icon: {
                Image(systemName: "book.closed")
            }
            .foregroundStyle(Color.accentColor)

            // Add New Character button
            Button {
                store.openNewCharacterEditor()
            } label: {
                Label("Add New Character", systemImage: "plus.circle.fill")
                    .font(ResponsiveFont.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            addedDictionarySection
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var phraseIntegrationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label {
                Text("2. Phrases & English Meanings")
                    .font(ResponsiveFont.headline)
            } icon: {
                Image(systemName: "character.bubble")
            }
            .foregroundStyle(Color.accentColor)

            Button {
                store.openNewPhraseEditor()
            } label: {
                Label("Add New Phrase", systemImage: "plus.circle.fill")
                    .font(ResponsiveFont.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            changedPhrasesSection
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var addedPhraseEntries: [PhraseItem] {
        changedPhraseEntries.filter { !store.isPhraseInBase($0.word) }
    }

    private var editedPhraseEntries: [PhraseItem] {
        changedPhraseEntries.filter { store.isPhraseInBase($0.word) }
    }

    private var changedPhraseEntries: [PhraseItem] {
        var merged: [PhraseItem] = []
        for phrase in store.addedPhrases + store.dataEditPhrases {
            if let index = merged.firstIndex(where: { $0.word == phrase.word }) {
                merged[index] = phrase
            } else {
                merged.append(phrase)
            }
        }
        return merged
    }

    private var changedPhrasesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Changed Phrases")
                .font(ResponsiveFont.subheadline.bold())

            Text("Added phrases are new. Edited phrases are built-in phrases you changed for your own copy.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)

            if changedPhraseEntries.isEmpty {
                Text("No changed phrases yet.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            } else {
                if !addedPhraseEntries.isEmpty {
                    changedPhraseGroup(title: "Added", phrases: addedPhraseEntries)
                }
                if !editedPhraseEntries.isEmpty {
                    changedPhraseGroup(title: "Edited", phrases: editedPhraseEntries)
                }
            }
        }
    }

    private func changedPhraseGroup(title: String, phrases: [PhraseItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(title) (\(phrases.count))")
                .font(ResponsiveFont.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(phrases) { phrase in
                editablePhraseCard(phrase)
            }
        }
    }

    private func editablePhraseCard(_ phrase: PhraseItem) -> some View {
        let isBuiltInPhrase = store.isPhraseInBase(phrase.word)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(phrase.word)
                    .font(ResponsiveFont.headline)
                    .phraseContextMenu(phrase)
                Spacer()
                Button("Edit") {
                    store.openQuickPhraseEditor(word: phrase.word)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                Button(role: isBuiltInPhrase ? nil : .destructive) {
                    store.removeDataEditPhrase(word: phrase.word)
                } label: {
                    Text(isBuiltInPhrase ? "Revert" : "Delete")
                        .font(ResponsiveFont.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

            Text(phrase.pinyin)
                .font(ResponsiveFont.body.monospaced())

            Text(phrase.meanings)
                .font(ResponsiveFont.body)
        }
        .padding(10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var aiTemplatesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label {
                Text("3. AI Prompt Templates")
                    .font(ResponsiveFont.headline)
            } icon: {
                Image(systemName: "sparkles")
            }
            .foregroundStyle(Color.accentColor)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Prompt Preamble")
                    .font(ResponsiveFont.caption.bold())
                TextEditor(text: Binding(
                    get: { store.promptConfig.preamble },
                    set: { store.setPromptPreamble($0) }
                ))
                .font(ResponsiveFont.body)
                .frame(height: 120)
                .padding(6)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                ForEach(store.promptConfig.tasks) { task in
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Task Title", text: Binding(
                                get: { store.promptConfig.tasks.first(where: { $0.id == task.id })?.title ?? "" },
                                set: { store.setPromptTaskTitle(taskID: task.id, title: $0) }
                            ))
                            .font(ResponsiveFont.body)
                            .textFieldStyle(.roundedBorder)
                            
                            TextEditor(text: Binding(
                                get: { store.promptConfig.tasks.first(where: { $0.id == task.id })?.template ?? "" },
                                set: { store.setPromptTaskTemplate(taskID: task.id, template: $0) }
                            ))
                            .font(ResponsiveFont.body)
                            .frame(height: 150)
                            .padding(6)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(.vertical, 4)
                    } label: {
                        Text(task.title)
                            .font(ResponsiveFont.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func exportFormatDetail(title: String, path: String, intendedUse: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(ResponsiveFont.caption.bold())
                .foregroundStyle(.secondary)
            Text(path)
                .font(ResponsiveFont.caption.monospaced())
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text("Best for: \(intendedUse)")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func exportOptionCard(title: String, subtitle: String, systemName: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemName)
                .font(ResponsiveFont.title3)
                .foregroundStyle(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(ResponsiveFont.subheadline.bold())
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.35), lineWidth: 1)
        )
    }

    private var addedDictionarySection: some View {
        let totalChangedCount = store.changedDictionaryCharacters.count

        return VStack(alignment: .leading, spacing: 16) {
            Text("Changed Characters")
                .font(ResponsiveFont.subheadline.bold())

            Text("Saved character changes are grouped here. Added characters can be deleted. Edited built-in characters can be reverted.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)

            if totalChangedCount == 0 {
                Text("No dictionary changes yet.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            } else {
                TextField("Search changed characters", text: $dictionaryChangeSearch)
                    .font(ResponsiveFont.body)
                    .textFieldStyle(.roundedBorder)

                if !displayedAddedDictionaryCharacters.isEmpty {
                    changedCharacterGroup(
                        title: "Added (\(filteredAddedDictionaryCharacters.count))",
                        characters: displayedAddedDictionaryCharacters,
                        badge: "Added"
                    )
                }

                if !displayedEditedDictionaryCharacters.isEmpty {
                    changedCharacterGroup(
                        title: "Edited (\(filteredEditedDictionaryCharacters.count))",
                        characters: displayedEditedDictionaryCharacters,
                        badge: "Edited"
                    )
                }

                if filteredAddedDictionaryCharacters.count > displayedAddedDictionaryCharacters.count ||
                    filteredEditedDictionaryCharacters.count > displayedEditedDictionaryCharacters.count {
                    Text("Showing the first 80 results. Refine your search to narrow the list.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func changedCharacterGroup(title: String, characters: [String], badge: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(ResponsiveFont.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(characters, id: \.self) { character in
                // Resolve item once here so editableCharacterCard doesn't call
                // store.item(for:) a second time on every render.
                let item = store.item(for: character)
                editableCharacterCard(character, badge: badge, item: item)
            }
        }
    }

    private var filteredAddedDictionaryCharacters: [String] {
        filterChangedDictionaryCharacters(store.addedDictionaryCharacters)
    }

    private var filteredEditedDictionaryCharacters: [String] {
        filterChangedDictionaryCharacters(store.editedDictionaryCharacters)
    }

    private var displayedAddedDictionaryCharacters: [String] {
        cappedChangedDictionaryCharacters(filteredAddedDictionaryCharacters)
    }

    private var displayedEditedDictionaryCharacters: [String] {
        cappedChangedDictionaryCharacters(filteredEditedDictionaryCharacters)
    }

    private func filterChangedDictionaryCharacters(_ characters: [String]) -> [String] {
        let query = dictionaryChangeSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return characters }
        return characters.filter { character in
            if character.lowercased().contains(query) {
                return true
            }
            guard let item = store.item(for: character) else { return false }
            return item.pinyinText.lowercased().contains(query) || item.definition.lowercased().contains(query)
        }
    }

    private func cappedChangedDictionaryCharacters(_ characters: [String]) -> [String] {
        // Cap at 80 unconditionally — even with a search query active — to prevent
        // the LazyVStack rendering thousands of cards on a broad search.
        return Array(characters.prefix(80))
    }

    private func editableCharacterCard(_ character: String, badge: String, item: ComponentItem?) -> some View {
        // O(1) Set lookup — replaces the O(n) [String].contains scan.
        let isBuiltInCharacter = store.editedDictionaryCharactersSet.contains(character)
        let pinyin = item?.pinyinText ?? ""
        let definition = item?.definition ?? ""

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(character)
                    .font(ResponsiveFont.headline)
                    .copyTextContextMenu(character, buttonTitle: "Copy Character", secondaryText: pinyin, secondaryButtonTitle: "Copy Pinyin")
                Spacer()
                Text(badge)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)

                Button("Edit") {
                    store.openQuickCharacterEditor(character)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                Button(role: isBuiltInCharacter ? nil : .destructive) {
                    if isBuiltInCharacter {
                        store.restoreDictionaryCharacterFromLibrary(character)
                    } else {
                        store.loadDataEditEntry(for: character)
                        do {
                            try store.deleteCurrentDataEditEntry()
                        } catch {}
                    }
                } label: {
                    Text(isBuiltInCharacter ? "Revert" : "Delete")
                        .font(ResponsiveFont.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

            if !pinyin.isEmpty {
                Text(pinyin)
                    .font(ResponsiveFont.body.monospaced())
            }

            if !definition.isEmpty {
                Text(definition)
                    .font(ResponsiveFont.body)
            }
        }
        .padding(10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded {
            store.preview(character: character)
            #if !targetEnvironment(macCatalyst)
            if UIDevice.current.userInterfaceIdiom == .phone {
                withAnimation { dataEditScrollProxy?.scrollTo("myDataTop", anchor: .top) }
            }
            #endif
        })
    }

    private var activeCharacterContext: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let current = store.previewCharacter {
                standardPhoneCharacterPreview(
                    character: current,
                    selectedCharacter: store.selectedCharacter,
                    onClear: { store.previewCharacter = nil }
                )
            }
        }
    }

    private func varianceGrid(items: [DictionaryVariance]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 8) {
            ForEach(items) { variance in
                Button {
                    // For phrases, we try to load the first character of the word into the studio
                    let target = String(variance.character.prefix(1))
                    store.loadDataEditEntry(for: target)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(variance.character)
                                .font(ResponsiveFont.subheadline.bold())
                                .lineLimit(1)
                            Spacer()
                            varianceIcon(for: variance.type)
                        }
                        Text(variance.type.rawValue)
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(varianceColor(for: variance.type).opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func varianceIcon(for type: DictionaryVariance.VarianceType) -> some View {
        switch type {
        case .added:
            return Image(systemName: "plus.circle.fill").font(ResponsiveFont.body).foregroundStyle(.green)
        case .missing:
            return Image(systemName: "exclamationmark.circle.fill").font(ResponsiveFont.body).foregroundStyle(.red)
        }
    }

    private func varianceColor(for type: DictionaryVariance.VarianceType) -> Color {
        switch type {
        case .added: return .green
        case .missing: return .red
        }
    }

    private func explainerGridRow(title: String, desc: String) -> some View {
        let titleWidth: CGFloat = {
            #if targetEnvironment(macCatalyst)
            return 110 // Wider for Mac to prevent "Restore" from wrapping
            #else
            return 80
            #endif
        }()
        
        return GridRow {
            Text(title)
                .font(ResponsiveFont.subheadline.bold())
                .frame(width: titleWidth, alignment: .leading)
            Text(desc)
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func explainerRow(title: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(ResponsiveFont.subheadline.bold())
            Text(desc)
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func labeledEditor(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: text)
                .font(ResponsiveFont.body)
                .frame(minHeight: 100, maxHeight: 180)
                .padding(6)
                .background(Color(.secondarySystemBackground).opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct CharacterRow: View {
    let item: ComponentItem
    let isFavorite: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(item.character)
                .font(.system(size: 26))
                .frame(width: 34)
                .copyCharacterContextMenu(item.character, pinyin: item.pinyinText)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.pinyinText.isEmpty ? "-" : item.pinyinText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(item.definition.isEmpty ? "No definition" : item.definition)
                    .font(.callout)
                    .lineLimit(1)
            }
            Spacer()
            if isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
            }
        }
    }
}

private struct SmartResultsGrid: View {
    @EnvironmentObject private var store: RadixStore
    let items: [ComponentItem]
    @Binding var currentPage: Int
    var onPreview: ((String) -> Void)? = nil
    var onSelect: (() -> Void)? = nil
    
    // Dynamic column calculation for Mac vs iPad
    private var columns: [GridItem] {
        #if targetEnvironment(macCatalyst)
        return Array(repeating: GridItem(.flexible(minimum: 40, maximum: 80), spacing: 10), count: 15)
        #else
        // iPhone: reduce to 8 columns to avoid pinyin wrapping
        return Array(repeating: GridItem(.flexible(minimum: 32, maximum: 64), spacing: 8), count: 8)
        #endif
    }

    private var fontSize: CGFloat {
        #if targetEnvironment(macCatalyst)
        return 28
        #else
        return 24
        #endif
    }

    private var columnsPerPage: Int {
        #if targetEnvironment(macCatalyst)
        return 15
        #else
        return 8
        #endif
    }

    private let rowsPerPage = 5

    private var pageSize: Int {
        columnsPerPage * rowsPerPage
    }

    private var pageCount: Int {
        max(1, Int(ceil(Double(items.count) / Double(pageSize))))
    }

    private var safePage: Int {
        min(currentPage, pageCount - 1)
    }

    private var pagedItems: ArraySlice<ComponentItem> {
        let start = safePage * pageSize
        let end = min(start + pageSize, items.count)
        return items[start..<end]
    }

    var body: some View {
        if items.isEmpty {
            Text("No results for current filters.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                if pageCount > 1 {
                    HStack {
                        Spacer()
                        Button("◀ Prev") {
                            currentPage = max(0, safePage - 1)
                        }
                        .font(ResponsiveFont.caption)
                        .disabled(safePage == 0)

                        Text("Page \(safePage + 1) of \(pageCount)")
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 80)

                        Button("Next ▶") {
                            currentPage = min(pageCount - 1, safePage + 1)
                        }
                        .font(ResponsiveFont.caption)
                        .disabled(safePage + 1 >= pageCount)
                    }
                }

                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(pagedItems, id: \.character) { item in
                        let isActive = item.character == store.previewCharacter || item.character == store.selectedCharacter
                        Button {
                            onPreview?(item.character)
                            store.preview(character: item.character)
                            onSelect?()
                        } label: {
                            VStack(spacing: 2) {
                                Text(item.character)
                                    .font(.system(size: fontSize))
                                    .copyCharacterContextMenu(item.character, pinyin: item.pinyinText)
                                Text(item.pinyinText.isEmpty ? " " : item.pinyinText)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(isActive ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                            .overlay(alignment: .topTrailing) {
                                if store.isFavorite(item.character) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.yellow)
                                        .padding(6)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(
                            TapGesture(count: 2).onEnded {
                                store.select(character: item.character)
                            }
                        )
                    }
                }
                .frame(maxHeight: {
                    #if targetEnvironment(macCatalyst)
                    return 5 * 56
                    #else
                    return 5 * 52
                    #endif
                }())
            }
            .padding(.vertical, 10)
            .onChange(of: items.count) { _, _ in
                if currentPage >= pageCount {
                    currentPage = max(0, pageCount - 1)
                }
            }
        }
    }

}

struct StrokeRangeSlider: View {
    @Binding var minValue: Int
    @Binding var maxValue: Int
    private let lowerBound = 0
    private let upperBound = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Min: \(minValue) strokes")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Max: \(upperBound) strokes")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: { Double(minValue) },
                    set: { newValue in
                        let newMin = Int(newValue.rounded())
                        minValue = min(max(newMin, lowerBound), min(maxValue, upperBound))
                    }
                ),
                in: Double(lowerBound)...Double(upperBound),
                step: 1
            )
        }
        .onAppear { maxValue = upperBound }
        .onChange(of: minValue) { _, _ in maxValue = upperBound }
    }
}
