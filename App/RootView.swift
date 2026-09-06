import SwiftUI

/*
 RADIX - ROOT UI ARCHITECTURE
 =================================
 RootView serves as the primary container and layout orchestrator for the app.
 It owns global app chrome, sheets, file import/export lifecycle, and routes the
 main iPad/phone layouts through focused extension files.
*/

struct RootView: View {
    let dataExportService = DataExportService()
    let localSnapshotStore = LocalDataSnapshotStore()
    @EnvironmentObject var store: RadixStore
    @EnvironmentObject var entitlement: EntitlementManager
    @Environment(\.horizontalSizeClass) var sizeClass
    @State var hasSeenWelcome = RadixRootPreferences.hasSeenWelcome
    @State var hasUsedSidebarNavigation = RadixRootPreferences.hasUsedSidebarNavigation
    @State var profileExportDocument = JSONFileDocument(data: Data())
    @State var addPhrasesExportDocument = AddPhrasesFileDocument(data: Data())
    @State var showProfileExporter = false
    @State var showProfileImporter = false
    @State var showAddPhrasesExporter = false
    @State var showAddPhrasesImporter = false
    @State var importExportError: String?
    @State var importExportMessage: String?
    @State var showImportExportAlert = false
    @State var isQuickSavingMemory = false
    @State var isQuickRestoringMemory = false
    @State var quickLocalSnapshots: [LocalDataSnapshot] = []
    @State var pendingSidebarCheckpointReturn: LocalDataSnapshot?
    @State var navigationGuideTopic: RadixNavigationGuideTopic?

    var body: some View {
        rootContent
        .background {
            RadixSceneLifecycleObserver(
                onResignActive: {
                    store.flushPendingDataEditAutoSave()
                },
                onBecomeActive: {
                    importPendingSharedInputsIfNeeded()
                }
            )
        }
        .modifier(FileTransferModifier(
            profileExportDocument: $profileExportDocument,
            addPhrasesExportDocument: $addPhrasesExportDocument,
            showProfileExporter: $showProfileExporter,
            showProfileImporter: $showProfileImporter,
            showAddPhrasesExporter: $showAddPhrasesExporter,
            showAddPhrasesImporter: $showAddPhrasesImporter,
            importExportError: $importExportError,
            importExportMessage: $importExportMessage,
            showImportExportAlert: $showImportExportAlert,
            onProfileImport: { data in
                try store.importProfileData(data)
            },
            onAddPhrasesImport: { url in
                try store.setAddPhrasesFile(url: url)
            }
        ))
        .sheet(isPresented: store.presentationBinding(\.showPaywall)) {
            PaywallView(featureName: store.paywallFeatureName)
                .environmentObject(entitlement)
                .presentationDetents([.large])
        }
        .sheet(item: store.presentationBinding(\.quickEditDestination)) { destination in
            QuickEditSheet(destination: destination)
                .environmentObject(store)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: store.presentationBinding(\.showLatestAIResult)) {
            LatestAIResultReader()
                .environmentObject(store)
                .presentationDetents([.large])
        }
        .alert("Return to Checkpoint?", isPresented: Binding(
            get: { pendingSidebarCheckpointReturn != nil },
            set: { if !$0 { pendingSidebarCheckpointReturn = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                pendingSidebarCheckpointReturn = nil
            }
            Button("Return to Checkpoint", role: .destructive) {
                let checkpoint = pendingSidebarCheckpointReturn
                pendingSidebarCheckpointReturn = nil
                quickRestoreMemory(from: checkpoint)
            }
        } message: {
            Text(pendingSidebarCheckpointReturn?.restoreScopeMessage ?? "The selected checkpoint is unavailable.")
        }
        .popover(item: $navigationGuideTopic, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) { topic in
            NavigationGuidePopover(topic: topic) {
                dismissNavigationGuide(topic)
            }
        }
        .sheet(isPresented: Binding(
            get: { !hasSeenWelcome },
            set: { isPresented in
                if !isPresented { hasSeenWelcome = true }
            }
        )) {
            RadixWelcomeView {
                hasSeenWelcome = true
            }
            .presentationDetents([.large])
        }
        .onOpenURL { url in
            if let query = searchQuery(from: url) {
                openSearch(query: query)
            } else if RadixSharedImageImport.isImportURL(url) {
                importPendingSharedImagesIfNeeded()
            } else if RadixSharedImageImport.isTextImportURL(url) {
                importPendingSharedTextIfNeeded()
            }
        }
        .onChange(of: hasSeenWelcome) { _, newValue in
            RadixRootPreferences.hasSeenWelcome = newValue
        }
        .onChange(of: hasUsedSidebarNavigation) { _, newValue in
            RadixRootPreferences.hasUsedSidebarNavigation = newValue
        }
        .onAppear {
            hasSeenWelcome = RadixRootPreferences.hasSeenWelcome
            hasUsedSidebarNavigation = RadixRootPreferences.hasUsedSidebarNavigation
            store.prepareFirstInteractionWarmup()
            refreshQuickLocalSnapshots()
            importPendingSharedInputsIfNeeded()
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        #if targetEnvironment(macCatalyst)
        iPadView
        #else
        if sizeClass == .compact {
            iPhoneView
        } else {
            iPadView
        }
        #endif
    }

    @MainActor
    private func openSearch(query: String) {
        store.goToSearchRoot()
        store.query = query
        store.performSearch(customQuery: query)
    }

    private func searchQuery(from url: URL) -> String? {
        guard url.scheme == "radix", url.host == "search" else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let query = components?.queryItems?.first { $0.name == "q" }?.value ?? ""
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func importPendingSharedImagesIfNeeded() {
        guard !RadixSharedImageImport.pendingImageURLs().isEmpty else { return }
        Task {
            await store.importPendingSharedImagesFromShareExtension()
        }
    }

    private func importPendingSharedInputsIfNeeded() {
        if !importPendingSharedTextIfNeeded() {
            importPendingSharedImagesIfNeeded()
        }
    }

    @discardableResult
    private func importPendingSharedTextIfNeeded() -> Bool {
        guard !RadixSharedImageImport.pendingTextURLs().isEmpty else { return false }
        store.importPendingSharedTextFromShareExtension()
        return true
    }

}

private struct RadixSceneLifecycleObserver: View {
    @Environment(\.scenePhase) private var scenePhase
    let onResignActive: () -> Void
    let onBecomeActive: () -> Void

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .inactive || newPhase == .background {
                    onResignActive()
                } else if newPhase == .active {
                    onBecomeActive()
                }
            }
    }
}
