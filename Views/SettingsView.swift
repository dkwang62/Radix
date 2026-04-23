import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section("About") {
                NavigationLink("Credits / Data Sources / Legal") {
                    CreditsView()
                }
            }
        }
        .navigationTitle("Settings")
    }
}
