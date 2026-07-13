import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: RadixStore
    @State private var showResetMemoryConfirmation = false
    @State private var showRefreshSentencePhraseLinksConfirmation = false
    @State private var showDatabaseSafetyDetails = false
    @State private var resetMemoryStatus: String?
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
                storageHealthSummary

                Button {
                    showRefreshSentencePhraseLinksConfirmation = true
                } label: {
                    if store.databaseOptimizationInProgress {
                        Label("Optimizing Database", systemImage: "hourglass")
                    } else {
                        Label("Optimize Database", systemImage: "externaldrive.badge.timemachine")
                    }
                }
                .disabled(store.databaseOptimizationInProgress)

                Text("Keeps Study fast, search accurate, and sentence phrase highlights up to date after large imports or cleanup.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)

                if let databaseOptimizationStatusText {
                    Text(databaseOptimizationStatusText)
                        .font(ResponsiveFont.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                DisclosureGroup(isExpanded: $showDatabaseSafetyDetails) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Radix quietly keeps local recovery copies before import, restore, cleanup, and optimization. Portable backups are still the full-app backup.")
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
                    Label("Recovery Copies", systemImage: "externaldrive.badge.timemachine")
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
        .alert("Optimize Database?", isPresented: $showRefreshSentencePhraseLinksConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Optimize") {
                refreshSentencePhraseLinks()
            }
        } message: {
            Text("Radix will clean and prepare study data in the background so search, sentence lists, and phrase highlights stay fast and consistent. You can keep using the app while it works.")
        }
        .alert(item: $pendingDatabaseSnapshotRestore) { snapshot in
            Alert(
                title: Text("Restore \(snapshot.kind.title)?"),
                message: Text("Radix will first create a fresh safety copy, then restore \(snapshot.kind.title.lowercased()) from \(snapshotDateText(snapshot))."),
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

    private var storageHealthSummary: some View {
        let health = store.storageHealth()
        return VStack(alignment: .leading, spacing: 10) {
            Label("Storage Health", systemImage: health.hasWarnings ? "exclamationmark.triangle" : "checkmark.circle")
                .font(ResponsiveFont.subheadline.weight(.semibold))
                .foregroundStyle(health.hasWarnings ? Color.orange : RadixAccent.primary)

            VStack(alignment: .leading, spacing: 6) {
                storageHealthRow("Sentences", "\(health.sentenceCount)", detail: fileSizeText(health.sentenceDatabaseByteCount))
                storageHealthRow("Added phrases", "\(health.addedPhraseCount)", detail: fileSizeText(health.addedPhraseDatabaseByteCount))
                storageHealthRow("Extracted pages", "\(health.extractedPageCount)", detail: largestPageText(health))
                storageHealthRow("Optimization", optimizationStatusText(health), detail: lastOptimizedText(health))
            }

            ForEach(storageHealthWarnings(health), id: \.self) { warning in
                Text(warning)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(Color.orange)
            }
        }
        .padding(.vertical, 4)
    }

    private func storageHealthRow(_ title: String, _ value: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .font(ResponsiveFont.caption)
    }

    private func storageHealthWarnings(_ health: RadixStorageHealth) -> [String] {
        var warnings: [String] = []
        if health.optimizationMayBeNeeded {
            warnings.append("Optimization is recommended after recent imports or cleanup.")
        }
        if health.hasLargeSentenceLibrary {
            warnings.append("Large sentence library: keep using paged lists and avoid full exports during active study.")
        }
        if health.hasLargeAddedPhraseLibrary {
            warnings.append("Large added-phrase library: phrase review and search should stay paged.")
        }
        if health.hasLargeExtractedPage {
            warnings.append("One extracted page has many sentences; very large pages may take longer to import or back up.")
        }
        if health.hasLargeDatabaseFiles {
            warnings.append("Database files are large; backups may take longer.")
        }
        return warnings
    }

    private func optimizationStatusText(_ health: RadixStorageHealth) -> String {
        if store.databaseOptimizationInProgress { return "Running" }
        return health.optimizationMayBeNeeded ? "Recommended" : "OK"
    }

    private func largestPageText(_ health: RadixStorageHealth) -> String {
        guard health.largestExtractedPageSentenceCount > 0 else { return "No extracted sentences" }
        return "Largest page: \(health.largestExtractedPageSentenceCount) sentences"
    }

    private func lastOptimizedText(_ health: RadixStorageHealth) -> String {
        guard let lastOptimizedAt = health.lastOptimizedAt else { return "Not yet optimized" }
        return "Last: \(lastOptimizedAt.formatted(date: .abbreviated, time: .shortened))"
    }

    private func fileSizeText(_ byteCount: Int64) -> String {
        byteCount > 0 ? ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file) : "No file yet"
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

    private func refreshSentencePhraseLinks() {
        store.startDatabaseOptimization(reason: "Optimization", includeStorageCleanup: true)
        RadixHaptics.success()
    }

    private var databaseOptimizationStatusText: String? {
        store.databaseOptimizationMessage
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
