import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: RadixStore
    @State private var showResetMemoryConfirmation = false
    @State private var showNormalizeChineseStorageConfirmation = false
    @State private var showRefreshSentencePhraseLinksConfirmation = false
    @State private var showDatabaseSafetyDetails = false
    @State private var resetMemoryStatus: String?
    @State private var normalizeChineseStorageStatus: String?
    @State private var refreshSentencePhraseLinksStatus: String?
    @State private var databaseSnapshotStatus: String?
    @State private var pendingDatabaseSnapshotRestore: RadixDatabaseSnapshotMetadata?
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

                    Text("Use `{prompt}` where Radix should place the AI prompt in a custom URL.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(store.defaultAIBaseURLString)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                apiKeyField("Gemini API key", text: storeBinding(\.geminiAPIKey))
                geminiKeyHealthRow

                TextField("Gemini model", text: storeBinding(\.geminiModelID))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                geminiModelHealthRow

                DisclosureGroup("Get a Gemini API key") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Google AI Studio")
                            .font(ResponsiveFont.caption.weight(.semibold))

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
            } header: {
                Text("Automatic AI")
            } footer: {
                Text("Optional. Uses Gemini to let Radix check OCR, extract phrases, translate pages, create quizzes, extract sentences, and create page-inspired practice automatically.")
            }

            Section {
                DisclosureGroup(isExpanded: $areAPIKeysExpanded) {
                    apiKeyField("OpenAI API key", text: storeBinding(\.openAIAPIKey))
                    apiKeyField("Claude API key", text: storeBinding(\.claudeAPIKey))
                    apiKeyField("DeepSeek API key", text: storeBinding(\.deepSeekAPIKey))
                    apiKeyField("Custom AI API key", text: storeBinding(\.customAIAPIKey))
                } label: {
                    HStack(spacing: 8) {
                        Label("Manual AI Keys", systemImage: "key.fill")
                        Spacer()
                        Text("\(manualAIKeysSavedCount) saved")
                            .font(ResponsiveFont.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .font(ResponsiveFont.subheadline.weight(.semibold))
                }
            } footer: {
                Text("For manual copy-and-paste AI Link workflows. These keys are not required for automatic Gemini features.")
            }

            Section {
                Button {
                    showNormalizeChineseStorageConfirmation = true
                } label: {
                    Label("Normalize Chinese Storage", systemImage: "arrow.triangle.2.circlepath")
                }

                Text("Rewrites Radix-owned sentence and phrase storage into Simplified Chinese. Traditional remains available as a display choice.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)

                if let normalizeChineseStorageStatus {
                    Text(normalizeChineseStorageStatus)
                        .font(ResponsiveFont.caption.weight(.semibold))
                        .foregroundStyle(normalizeChineseStorageStatus.hasPrefix("Could not") ? .red : .secondary)
                }

                Button {
                    showRefreshSentencePhraseLinksConfirmation = true
                } label: {
                    Label("Refresh Sentence Phrase Links", systemImage: "link")
                }

                Text("Repairs stored phrase hints for sentence highlighting and sentence phrase lists using the current phrase library. Sentence screens never do this repair while you are studying.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)

                if let refreshSentencePhraseLinksStatus {
                    Text(refreshSentencePhraseLinksStatus)
                        .font(ResponsiveFont.caption.weight(.semibold))
                        .foregroundStyle(refreshSentencePhraseLinksStatus.hasPrefix("Could not") ? .red : .secondary)
                }

                DisclosureGroup(isExpanded: $showDatabaseSafetyDetails) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Radix quietly keeps internal database copies before import, restore, cleanup, and sentence maintenance. These are local recovery points; portable backups are still the full-app backup.")
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)

                        ForEach(RadixDatabaseSnapshotKind.allCases) { kind in
                            databaseSnapshotRow(kind)
                        }

                        Button {
                            createDatabaseSafetyCopy()
                        } label: {
                            Label("Create Safety Copy Now", systemImage: "externaldrive.badge.plus")
                        }

                        if let databaseSnapshotStatus {
                            Text(databaseSnapshotStatus)
                                .font(ResponsiveFont.caption.weight(.semibold))
                                .foregroundStyle(databaseSnapshotStatus.hasPrefix("Could not") ? .red : .secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } label: {
                    Label("Database Recovery", systemImage: "externaldrive.badge.timemachine")
                        .font(ResponsiveFont.subheadline.weight(.semibold))
                }
            } header: {
                Text("Storage")
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
        .alert("Normalize Chinese Storage?", isPresented: $showNormalizeChineseStorageConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Normalize", role: .destructive) {
                normalizeChineseStorage()
            }
        } message: {
            Text("This rewrites Radix-owned Study Sentences, extracted sentence pages, added phrases, and phrase favorites into Simplified Chinese. This is a raw data conversion, not just a display switch.")
        }
        .alert("Refresh Sentence Phrase Links?", isPresented: $showRefreshSentencePhraseLinksConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Refresh") {
                refreshSentencePhraseLinks()
            }
        } message: {
            Text("This scans the stored sentence database once and rewrites phrase hints using the current phrase library. Normal sentence and phrase-card access will continue to use stored hints only.")
        }
        .alert(item: $pendingDatabaseSnapshotRestore) { snapshot in
            Alert(
                title: Text("Restore \(snapshot.kind.title)?"),
                message: Text("Radix will first create a fresh safety copy, then replace the current \(snapshot.kind.title.lowercased()) database with the copy from \(snapshotDateText(snapshot))."),
                primaryButton: .destructive(Text("Restore")) {
                    restoreDatabaseSnapshot(snapshot)
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func apiKeyField(_ title: String, text: Binding<String>) -> some View {
        SecureField(title, text: text)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
    }

    private func databaseSnapshotRow(_ kind: RadixDatabaseSnapshotKind) -> some View {
        let snapshot = store.latestDatabaseSnapshot(kind: kind)
        return HStack(spacing: 12) {
            Label(kind.title, systemImage: kind == .sentenceExamples ? "text.quote" : "text.badge.plus")
                .font(ResponsiveFont.subheadline.weight(.semibold))

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                if let snapshot {
                    Text(snapshotDateText(snapshot))
                    Text(snapshotSizeText(snapshot))
                } else {
                    Text("No safety copy yet")
                }
            }
            .font(ResponsiveFont.caption)
            .foregroundStyle(.secondary)

            Button("Restore") {
                pendingDatabaseSnapshotRestore = snapshot
            }
            .buttonStyle(.bordered)
            .disabled(snapshot == nil)
        }
    }

    private func createDatabaseSafetyCopy() {
        do {
            let snapshots = try store.createDatabaseSafetySnapshots(reason: "Manual safety copy")
            databaseSnapshotStatus = "Created \(snapshots.count) safety cop\(snapshots.count == 1 ? "y" : "ies")."
            RadixHaptics.success()
        } catch {
            databaseSnapshotStatus = "Could not create safety copy: \(error.localizedDescription)"
            RadixHaptics.error()
        }
    }

    private func restoreDatabaseSnapshot(_ snapshot: RadixDatabaseSnapshotMetadata) {
        do {
            try store.restoreDatabaseSnapshot(snapshot)
            databaseSnapshotStatus = "Restored \(snapshot.kind.title) from \(snapshotDateText(snapshot))."
            RadixHaptics.success()
        } catch {
            databaseSnapshotStatus = "Could not restore \(snapshot.kind.title): \(error.localizedDescription)"
            RadixHaptics.error()
        }
    }

    private func snapshotDateText(_ snapshot: RadixDatabaseSnapshotMetadata) -> String {
        snapshot.createdAt.formatted(date: .abbreviated, time: .shortened)
    }

    private func snapshotSizeText(_ snapshot: RadixDatabaseSnapshotMetadata) -> String {
        ByteCountFormatter.string(fromByteCount: snapshot.byteCount, countStyle: .file)
    }

    private var manualAIKeysSavedCount: Int {
        [store.openAIAPIKey, store.claudeAPIKey, store.deepSeekAPIKey, store.customAIAPIKey]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
    }

    private func revealRequestedAPIKeySettings() {
        guard store.shouldRevealAPIKeys else { return }
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
            RadixHaptics.success()
        } catch {
            resetMemoryStatus = "Could not erase my data: \(error.localizedDescription)"
            RadixHaptics.error()
        }
    }

    private func normalizeChineseStorage() {
        do {
            let result = try store.normalizeChineseStorageToSimplified()
            normalizeChineseStorageStatus = "Normalized \(result.sentenceCount) sentence\(result.sentenceCount == 1 ? "" : "s") and \(result.phraseCount) added phrase\(result.phraseCount == 1 ? "" : "s")."
            RadixHaptics.success()
        } catch {
            normalizeChineseStorageStatus = "Could not normalize Chinese storage: \(error.localizedDescription)"
            RadixHaptics.error()
        }
    }

    private func refreshSentencePhraseLinks() {
        let result = store.refreshSentencePhraseLinks()
        refreshSentencePhraseLinksStatus = "Refreshed \(result.sentenceCount) sentence\(result.sentenceCount == 1 ? "" : "s") and \(result.extractedPageCount) extracted page\(result.extractedPageCount == 1 ? "" : "s")."
        RadixHaptics.success()
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
        .radixSurface(color.opacity(0.1))
    }

    private var settingsSummaryCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(RadixAccent.primary)
                .radixIconButtonSurface(
                    size: 42,
                    background: RadixAccent.primary.opacity(0.12)
                )

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
                detail: "Add one for automatic OCR checking, phrase extraction, translation, quizzes, sentence extraction, and page-inspired practice.",
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
            detail: "Ready for automatic OCR checking, phrase extraction, translation, quizzes, sentence extraction, and page-inspired practice.",
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
