import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: RadixStore
    @State private var showResetMemoryConfirmation = false
    @State private var resetMemoryStatus: String?
    @State private var navigationTipsReset = false
    @State private var areAPIKeysExpanded = false
    let showsCloseButton: Bool
    let onShowWelcome: (() -> Void)?

    init(showsCloseButton: Bool = true, onShowWelcome: (() -> Void)? = nil) {
        self.showsCloseButton = showsCloseButton
        self.onShowWelcome = onShowWelcome
    }

    var body: some View {
        List {
            Section {
                settingsSummaryCard
            }

            Section("Playback") {
                Toggle(isOn: $store.speechEnabled) {
                    Label("Read Aloud", systemImage: store.speechMenuSymbolName)
                }
            }

            Section("Navigation") {
                Picker("Navigation buttons", selection: storeBinding(\.sidebarNavigationStyle)) {
                    ForEach(SidebarNavigationStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }

                Text("Icons & Labels keeps the five destinations named. Icons Only gives experienced users more space.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)

                Button {
                    RadixRootPreferences.resetNavigationGuides()
                    navigationTipsReset = true
                } label: {
                    Label("Show Navigation Tips Again", systemImage: RadixIcon.help)
                }

                if navigationTipsReset {
                    Text("Tips will appear once as you next open Browse, Study, AI Link, My Data, and Settings.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("AI Link") {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Open AI links in", systemImage: RadixIcon.aiLink)
                        .font(ResponsiveFont.subheadline.weight(.semibold))

                    Picker("Open AI links in", selection: storeBinding(\.defaultAIPreset)) {
                        ForEach(DefaultAIPreset.allCases, id: \.self) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if store.defaultAIPreset == .custom {
                    TextField(
                        "Custom AI URL",
                        text: storeBinding(\.customAIURLString)
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

                DisclosureGroup(isExpanded: $areAPIKeysExpanded) {
                    apiKeyField("OpenAI API key", text: storeBinding(\.openAIAPIKey))
                    apiKeyField("Gemini API key", text: storeBinding(\.geminiAPIKey))
                    geminiKeyHealthRow
                    apiKeyField("Claude API key", text: storeBinding(\.claudeAPIKey))
                    apiKeyField("DeepSeek API key", text: storeBinding(\.deepSeekAPIKey))
                    apiKeyField("Custom AI API key", text: storeBinding(\.customAIAPIKey))
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

                if areAPIKeysExpanded {
                    Text("A Gemini API key lets Radix check OCR, extract phrases, and translate pages automatically. Copy-and-paste AI workflows do not require a key.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }

                TextField("Gemini model", text: storeBinding(\.geminiModelID))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                geminiModelHealthRow

                DisclosureGroup("Get a Gemini API key") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Google AI Studio")
                            .font(ResponsiveFont.caption.weight(.semibold))

                        Text("Use this only if you want Radix to check OCR, extract phrases, and translate pages automatically.")
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

            Section("Help") {
                NavigationLink {
                    GlossaryView()
                } label: {
                    Label("Glossary", systemImage: "book.closed")
                }

                if let onShowWelcome {
                    Button {
                        if showsCloseButton {
                            dismiss()
                        }
                        onShowWelcome()
                    } label: {
                        Label("Show Welcome", systemImage: RadixIcon.help)
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    showResetMemoryConfirmation = true
                } label: {
                    Label("Erase My Data on This Device", systemImage: "trash")
                }

                Text("Clears current added characters, phrases, saved pages, favorites, recent items, and AI Link templates. Dated copies and API keys are kept.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)

                if let resetMemoryStatus {
                    Text(resetMemoryStatus)
                        .font(ResponsiveFont.caption.weight(.semibold))
                        .foregroundStyle(resetMemoryStatus.hasPrefix("Could not") ? .red : .secondary)
                }
            } header: {
                Text("Reset")
            }

            Section("About") {
                NavigationLink("Credits and Data Sources") {
                    CreditsView()
                }
            }
        }
        .navigationTitle(RadixCopy.settings)
        .onAppear {
            revealRequestedAPIKeySettings()
        }
        .onChange(of: store.shouldRevealAPIKeys) { _, _ in
            revealRequestedAPIKeySettings()
        }
        .toolbar {
            if showsCloseButton {
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
        .alert("Erase My Data on This Device?", isPresented: $showResetMemoryConfirmation) {
            Button("Erase My Data", role: .destructive) {
                resetRadixMemory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This erases added characters, phrases, saved pages, favorites, recent items, and AI Link templates on this device. Device snapshots are kept so you can restore one from My Data.")
        }
    }

    private func apiKeyField(_ title: String, text: Binding<String>) -> some View {
        SecureField(title, text: text)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
    }

    private func revealRequestedAPIKeySettings() {
        guard store.shouldRevealAPIKeys else { return }
        areAPIKeysExpanded = true
        store.shouldRevealAPIKeys = false
    }

    private func storeBinding<Value>(_ keyPath: ReferenceWritableKeyPath<RadixStore, Value>) -> Binding<Value> {
        Binding(
            get: { store[keyPath: keyPath] },
            set: { store[keyPath: keyPath] = $0 }
        )
    }

    private func resetRadixMemory() {
        do {
            try store.resetRadixMemory()
            resetMemoryStatus = "My data was erased. Device snapshots and API keys were kept."
        } catch {
            resetMemoryStatus = "Could not erase my data: \(error.localizedDescription)"
        }
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
            detail: "Used only for direct Gemini page AI tasks.",
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
                detail: "Add one for automatic OCR checking, phrase extraction, and translation.",
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
            detail: "Ready for automatic OCR checking, phrase extraction, and translation.",
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
