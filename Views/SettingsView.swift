import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: RadixStore
    let onShowWelcome: (() -> Void)?

    init(onShowWelcome: (() -> Void)? = nil) {
        self.onShowWelcome = onShowWelcome
    }

    var body: some View {
        List {
            Section {
                settingsSummaryCard
            }

            Section("Playback") {
                Toggle(isOn: $store.speechEnabled) {
                    Label("Sound", systemImage: store.speechMenuSymbolName)
                }
            }

            Section("AI Link") {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Open AI links in", systemImage: RadixIcon.aiLink)
                        .font(ResponsiveFont.subheadline.weight(.semibold))

                    Picker("Open AI links in", selection: $store.defaultAIPreset) {
                        ForEach(DefaultAIPreset.allCases, id: \.self) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if store.defaultAIPreset == .custom {
                    TextField(
                        "Custom AI URL",
                        text: $store.customAIURLString
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                    Text("Use `{prompt}` where Radix should place the instruction in a custom URL.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(store.defaultAIBaseURLString)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }

                DisclosureGroup {
                    apiKeyField("OpenAI API key", text: $store.openAIAPIKey)
                    apiKeyField("Gemini API key", text: $store.geminiAPIKey)
                    geminiKeyHealthRow
                    apiKeyField("Claude API key", text: $store.claudeAPIKey)
                    apiKeyField("DeepSeek API key", text: $store.deepSeekAPIKey)
                    apiKeyField("Custom AI API key", text: $store.customAIAPIKey)
                } label: {
                    HStack(spacing: 8) {
                        Label("Private API Keys", systemImage: "key.fill")
                        Spacer()
                        Text("\(store.currentAPIKeyBackup().savedCount) saved")
                            .font(ResponsiveFont.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .font(ResponsiveFont.subheadline.weight(.semibold))
                }

                TextField("Gemini model", text: $store.geminiModelID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                geminiModelHealthRow

                DisclosureGroup("Get a Gemini API key") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Google AI Studio")
                            .font(ResponsiveFont.caption.weight(.semibold))

                        Text("Use this only if you want Radix to extract phrases directly with the Gemini API.")
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("1. Visit aistudio.google.com.")
                            Text("2. Sign in with your standard Google account.")
                            Text("3. Choose Get API key.")
                            Text("4. If you're new, choose Create API key in new project. If you already have a Google Cloud project, select it from the list.")
                            Text("5. Paste the key here and keep it private.")
                        }
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
            }

            if let onShowWelcome {
                Section("Help") {
                    Button {
                        dismiss()
                        onShowWelcome()
                    } label: {
                        Label("Show Welcome", systemImage: RadixIcon.help)
                    }
                }
            }

            Section("About") {
                NavigationLink("Credits and Data Sources") {
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

    private var geminiKeyHealthRow: some View {
        settingsHealthRow(
            title: geminiKeyHealth.title,
            detail: geminiKeyHealth.detail,
            systemImage: geminiKeyHealth.systemImage,
            color: geminiKeyHealth.color
        )
    }

    private var geminiModelHealthRow: some View {
        settingsHealthRow(
            title: geminiModelHealth.title,
            detail: "Used only for direct Gemini phrase extraction.",
            systemImage: geminiModelHealth.systemImage,
            color: geminiModelHealth.color
        )
    }

    private func settingsHealthRow(title: String, detail: String, systemImage: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(ResponsiveFont.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var settingsSummaryCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 42)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text("Preferences")
                    .font(ResponsiveFont.headline)
                Text(settingsSummaryText)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }

    private var settingsSummaryText: String {
        let sound = store.speechEnabled ? "sound on" : "sound off"
        let keys = store.currentAPIKeyBackup().savedCount
        return "\(store.defaultAIName) selected, \(keys) API keys saved, \(sound)."
    }

    private var geminiKeyHealth: SettingsHealth {
        let trimmed = store.geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return SettingsHealth(
                title: "Gemini key not saved",
                detail: "Only needed for direct phrase extraction.",
                systemImage: "key.slash",
                color: .orange
            )
        }
        if trimmed.count < 30 {
            return SettingsHealth(
                title: "Gemini key looks incomplete",
                detail: "Paste the full key from Google AI Studio.",
                systemImage: "exclamationmark.triangle",
                color: .orange
            )
        }
        return SettingsHealth(
            title: "Gemini key saved",
            detail: "Ready for direct phrase extraction.",
            systemImage: "checkmark.circle",
            color: .green
        )
    }

    private var geminiModelHealth: SettingsHealth {
        let trimmed = store.geminiModelID.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return SettingsHealth(
                title: "Gemini model missing",
                detail: "",
                systemImage: "exclamationmark.triangle",
                color: .orange
            )
        }
        return SettingsHealth(
            title: "Gemini model: \(trimmed)",
            detail: "",
            systemImage: "cpu",
            color: .secondary
        )
    }
}

private struct SettingsHealth {
    let title: String
    let detail: String
    let systemImage: String
    let color: Color
}
