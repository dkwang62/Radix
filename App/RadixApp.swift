import SwiftUI

@main
struct RadixApp: App {
    @StateObject private var store = RadixStore()
    @StateObject private var entitlement = EntitlementManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(entitlement)
                .task {
                    await store.initialize()
                }
        }
        #if targetEnvironment(macCatalyst)
        .defaultSize(width: 1320, height: 860)
        .commands {
            SidebarCommands()
            ToolbarCommands()
        }
        #endif
    }
}
