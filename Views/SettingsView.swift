import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: RadixStore

    var body: some View {
        List {
            Section("Playback") {
                Toggle(isOn: $store.speechEnabled) {
                    Label("Sound", systemImage: store.speechMenuSymbolName)
                }
            }

            Section("AI") {
                Picker("Default AI", selection: $store.defaultAIPreset) {
                    ForEach(DefaultAIPreset.allCases, id: \.self) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }

                if store.defaultAIPreset == .custom {
                    TextField(
                        "Custom AI URL",
                        text: $store.customAIURLString
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                    Text("Use `{prompt}` in a custom URL if direct prompt prefilling is supported.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(store.defaultAIBaseURLString)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("About") {
                NavigationLink("Credits / Data Sources / Legal") {
                    CreditsView()
                }
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("Close")
            }
        }
    }
}
