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

                apiKeyField("OpenAI API key", text: $store.openAIAPIKey)
                apiKeyField("Gemini API key", text: $store.geminiAPIKey)
                apiKeyField("Claude API key", text: $store.claudeAPIKey)
                apiKeyField("DeepSeek API key", text: $store.deepSeekAPIKey)
                apiKeyField("Custom AI API key", text: $store.customAIAPIKey)

                TextField("Gemini model", text: $store.geminiModelID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Text("Used by AI Link's Gemini JSON Phrases task for direct API extraction and automatic phrase addition.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)

                DisclosureGroup("How to get a Gemini API key") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Option 1: The Quickest Way (Google AI Studio)")
                            .font(ResponsiveFont.caption.weight(.semibold))

                        Text("This is the fastest path for individual developers and for testing.")
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("1. Visit aistudio.google.com.")
                            Text("2. Sign in with your standard Google account.")
                            Text("3. Click Get API key in the top-left sidebar.")
                            Text("4. If you're new, choose Create API key in new project. If you already have a Google Cloud project, select it from the list.")
                            Text("5. Copy your key and keep it private. Do not share it publicly or check it into GitHub.")
                        }
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
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

    private func apiKeyField(_ title: String, text: Binding<String>) -> some View {
        SecureField(title, text: text)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
    }
}
