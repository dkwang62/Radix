import SwiftUI
import UniformTypeIdentifiers

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
    @EnvironmentObject var store: RadixStore
    @EnvironmentObject var entitlement: EntitlementManager
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.scenePhase) var scenePhase
    @AppStorage("hasSeenRadixWelcomeV1") var hasSeenWelcome = false
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
        .onAppear {
            store.prepareFirstInteractionWarmup()
        }
    }

    private func readImportedFileData(from url: URL) throws -> Data {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try Data(contentsOf: url)
    }
}
