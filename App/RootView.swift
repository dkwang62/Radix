import SwiftUI

/*
 RADIX - ROOT UI ARCHITECTURE
 =================================
 RootView serves as the primary container and layout orchestrator for the app.
 It owns global app chrome, sheets, file import/export lifecycle, and routes the
 main iPad/phone layouts through focused extension files.
*/

struct RootView: View {
    static let stableStrokeToken = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
    let dataExportService = DataExportService()
    let localSnapshotStore = LocalDataSnapshotStore()
    @EnvironmentObject var store: RadixStore
    @EnvironmentObject var entitlement: EntitlementManager
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.scenePhase) var scenePhase
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
    @State var showSettings = false
    @State var isQuickSavingMemory = false
    @State var isQuickRestoringMemory = false
    @State var quickLocalSnapshots: [LocalDataSnapshot] = []

    var body: some View {
        Group {
            if sizeClass == .compact {
                iPhoneView
            } else {
                iPadView
            }
        }
        #if targetEnvironment(macCatalyst)
        .dynamicTypeSize(.accessibility3)
        #endif
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
                SettingsView {
                    showSettings = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        hasSeenWelcome = false
                    }
                }
                    .environmentObject(store)
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
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                store.flushPendingDataEditAutoSave()
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
        }
    }

}
