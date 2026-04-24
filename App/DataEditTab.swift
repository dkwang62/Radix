import SwiftUI
import UniformTypeIdentifiers

struct DataEditTab: View {

    @EnvironmentObject private var store: RadixStore
    @EnvironmentObject private var entitlement: EntitlementManager
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.openURL) private var openURL
    let onLoadAddPhrases: () -> Void
    let onExportAddPhrases: () -> Void
    let onUseDefaultAddPhrases: () -> Void
    let onRequirePro: (EntitlementManager.FeatureGate) -> Void

    // Backup / Restore state
    @State private var showRestorePicker = false
    @State private var pendingRestoreMode: RestoreMode = .additive
    @State private var backupMessage: String?
    @State private var backupError: String?
    @State private var showBackupAlert = false

    // Advanced Exports state
    @State private var fullDatasetFileName: String = "radix_full_dataset"
    @State private var mergedDictionaryFileName: String = "radix_merged_dictionary"
    @State private var mergedPhrasesFileName: String = "radix_merged_phrases"
    @State private var reuseExportDocument = BinaryFileDocument(data: Data())
    @State private var reuseExportFilename: String = ""
    @State private var reuseExportContentType: UTType = .json
    @State private var showReuseExporter = false
    @State private var reuseExportInProgress = false
    @State private var reuseExportMessage: String?
    private let dataExportService = DataExportService()

    // Status messages
    @State private var editorMessage: String?
    @State private var editorError: String?

    // Dictionary change editor search
    @State private var dictionaryChangeSearch: String = ""

    // Progressive disclosure — all collapsed on launch
    @State private var showAddedCharactersPreview = false
    @State private var showEditedCharactersPreview = false
    @State private var showAddedPhrasesPreview = false
    @State private var showEditedPhrasesPreview = false

    // UI toggles
    @State private var showAdvancedExports = false
    @State private var showHelp = false
    @State private var showSourceSetupGuide = false
    @State private var showSettings = false

    // Scroll-to-top support (phones only)
    @State private var dataEditScrollProxy: ScrollViewProxy?

    private let sourceCodeURL = URL(string: "https://github.com/dkwang62/Radix")!
    private let sourceCloneCommand = "git clone https://github.com/dkwang62/Radix.git"
    private let sourceSetupGuide = """
    # 📦 Radix Project – Setup & Usage Guide

    ## 🧠 Overview

    This project is an Apple (Xcode) app written in Swift.

    You will:

    1. Download the code
    2. Open it in Xcode
    3. Use Codex to work on it

    ---

    # 🖥️ 1. Requirements

    ## Hardware

    * A Mac (MacBook, iMac, Mac mini, etc.)

    ## Software

    1. Install **Xcode (version 26.4 or newer)** from the App Store
    2. Install **ChatGPT (for Codex use)**

    ---

    # 📥 2. Get the Code

    ## Easiest way (no Git needed)

    1. Open this link:
       https://github.com/dkwang62/Radix
    2. Click **Code → Download ZIP**
    3. Unzip the file

    ---

    ## Optional (if using terminal)

    ```bash
    git clone https://github.com/dkwang62/Radix.git
    cd Radix
    ```

    ---

    # ▶️ 3. Run the Project

    1. Open:
       Radix.xcodeproj

    2. Wait for Xcode to load (1–2 minutes first time)

    3. Choose a simulator (e.g. iPhone)

    4. Press ▶️ Run

    ---

    # 🤖 4. Using Codex (Important)

    ## Step 1

    Open ChatGPT

    ## Step 2

    Upload or point Codex to the project folder

    ## Step 3

    Ask Codex things like:

    * “Explain this project”
    * “Fix build errors”
    * “Add a feature”
    * “Refactor this code”

    ---

    ## 🧠 How to think about Codex

    * Codex = junior developer
    * You = decision maker

    Always:

    * review what it changes
    * test the app after changes

    ---

    # 📁 Project Structure (Simplified)

    * App/ → app entry and setup
    * Models/ → data structures
    * ViewModels/ → logic and state
    * Views/ → UI
    * Services/ → helper logic
    * Resources/ → assets
    * Tests/ → tests

    ---

    # ⚠️ Common Issues

    ## 1. First run is slow

    Normal — Xcode is indexing

    ---

    ## 2. Build fails

    In Xcode:

    * Press Shift + Cmd + K (clean)
    * Run again

    ---

    ## 3. Real iPhone not working

    Ignore — simulator works without setup

    ---

    # 🧠 Simple Workflow

    1. Open project
    2. Use Codex to make changes
    3. Run in Xcode
    4. Repeat

    ---

    # 🔥 Golden Rule

    If something breaks:

    * don’t panic
    * undo changes
    * try again

    ---

    # ✅ Summary

    You only need:

    * Mac
    * Xcode
    * This GitHub link

    Everything else is optional.

    ---

    # 📩 Repo Link

    https://github.com/dkwang62/Radix
    """

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Color.clear.frame(height: 0).id("myDataTop")

                // Info card and animation preview (phones only; sidebar shows it on iPad/Mac)
                #if !targetEnvironment(macCatalyst)
                if UIDevice.current.userInterfaceIdiom == .phone {
                    activeCharacterContext
                }
                #endif

                myDataHeader

                if showAdvancedExports {
                    premiumExportsSection
                } else {
                    backupAndRestoreSection
                    whatsInMyBackupSection
                }

                if let editorError {
                    Text(editorError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                if let editorMessage {
                    Text(editorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .fileExporter(
            isPresented: $showReuseExporter,
            document: reuseExportDocument,
            contentType: reuseExportContentType,
            defaultFilename: reuseExportFilename
        ) { result in
            reuseExportInProgress = false
            switch result {
            case .success(let url):
                let base = url.deletingPathExtension().lastPathComponent
                if reuseExportContentType == .json && reuseExportFilename == "radix_unified_backup" {
                    backupMessage = "Backup saved to: \(url.lastPathComponent)"
                    showBackupAlert = true
                } else {
                    reuseExportMessage = "Saved to: \(url.lastPathComponent)"
                    if reuseExportContentType == .json { fullDatasetFileName = base }
                    else if reuseExportFilename.hasPrefix(mergedDictionaryFileName.isEmpty ? "radix_merged_dictionary" : mergedDictionaryFileName) {
                        mergedDictionaryFileName = base
                    } else {
                        mergedPhrasesFileName = base
                    }
                }
            case .failure(let error):
                backupError = error.localizedDescription
                showBackupAlert = true
            }
        }
        .fileImporter(
            isPresented: $showRestorePicker,
            allowedContentTypes: [.json, .data],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let url = try result.get().first else { return }
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                try store.importDataEditData(data, mode: pendingRestoreMode)
                let modeLabel = pendingRestoreMode == .complete ? "Complete restore" : "Additive restore"
                backupMessage = "\(modeLabel) from: \(url.lastPathComponent)"
                showBackupAlert = true
            } catch {
                backupError = error.localizedDescription
                showBackupAlert = true
            }
        }
        .alert("Backup / Restore", isPresented: $showBackupAlert) {
            Button("OK", role: .cancel) {
                backupMessage = nil
                backupError = nil
            }
        } message: {
            if let msg = backupError {
                Text(msg)
            } else if let msg = backupMessage {
                Text(msg)
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .onAppear { dataEditScrollProxy = proxy }
        } // ScrollViewReader
    }

    private var myDataHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showHelp.toggle() }
                } label: {
                    Image(systemName: showHelp ? "questionmark.circle.fill" : "questionmark.circle")
                        .font(ResponsiveFont.body)
                        .foregroundStyle(showHelp ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Help")

                Button {
                    showSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                        .font(ResponsiveFont.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.secondary)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showAdvancedExports.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showAdvancedExports ? "arrow.uturn.backward.circle" : "square.and.arrow.up.on.square")
                        Text(showAdvancedExports ? "Backup & Restore" : "Advanced")
                            .font(ResponsiveFont.caption)
                    }
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(showAdvancedExports ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
            }

            if showHelp {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Backup saves everything you've added or changed — custom characters, phrases, favorites, and AI templates — into a single file.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                    Text("Restore is additive: it merges your backup into the app's existing data rather than replacing it. Nothing is erased when you restore.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .transition(.opacity)
            }
        }
    }

    private var backupAndRestoreSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Button {
                    reuseExportInProgress = true
                    reuseExportMessage = nil
                    Task { @MainActor in
                        do {
                            let data = try dataExportService.exportPortableBackup(store.portableBackupPackage())
                            reuseExportDocument = BinaryFileDocument(data: data)
                            reuseExportFilename = "radix_unified_backup"
                            reuseExportContentType = .json
                            reuseExportInProgress = false
                            showReuseExporter = true
                        } catch {
                            reuseExportInProgress = false
                            backupError = error.localizedDescription
                            showBackupAlert = true
                        }
                    }
                } label: {
                    Label(reuseExportInProgress && reuseExportFilename.contains("backup") ? "Preparing Backup…" : "Back Up My Data", systemImage: "square.and.arrow.up.fill")
                        .font(ResponsiveFont.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(reuseExportInProgress)
            }

            VStack(spacing: 10) {
                Button {
                    pendingRestoreMode = .additive
                    showRestorePicker = true
                } label: {
                    VStack(spacing: 2) {
                        Label("Additive Restore", systemImage: "square.and.arrow.down")
                            .font(ResponsiveFont.subheadline.bold())
                        Text("Adds new data without overwriting existing")
                            .font(ResponsiveFont.caption2)
                            .opacity(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.accentColor.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    pendingRestoreMode = .complete
                    showRestorePicker = true
                } label: {
                    VStack(spacing: 2) {
                        Label("Complete Restore", systemImage: "square.and.arrow.down.fill")
                            .font(ResponsiveFont.subheadline.bold())
                        Text("Replaces all existing data with the backup")
                            .font(ResponsiveFont.caption2)
                            .opacity(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange.opacity(0.1))
                    .foregroundStyle(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var whatsInMyBackupSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's In My Backup")
                .font(ResponsiveFont.headline)

            VStack(alignment: .leading, spacing: 12) {
                DisclosureGroup("Added Characters (\(store.addedDictionaryCharacters.count))", isExpanded: $showAddedCharactersPreview) {
                    backupCharacterRows(store.addedDictionaryCharacters, badge: "Added")
                }

                DisclosureGroup("Added Phrases (\(addedPhraseEntries.count))", isExpanded: $showAddedPhrasesPreview) {
                    backupPhraseRows(addedPhraseEntries, badge: "Added")
                }

                DisclosureGroup("Characters With Notes (\(store.editedDictionaryCharacters.count))", isExpanded: $showEditedCharactersPreview) {
                    backupCharacterRows(store.editedDictionaryCharacters, badge: "Notes Added")
                }

                DisclosureGroup("Edited Phrases (\(editedPhraseEntries.count))", isExpanded: $showEditedPhrasesPreview) {
                    backupPhraseRows(editedPhraseEntries, badge: "Edited")
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var premiumExportsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Advanced Exports")
                    .font(ResponsiveFont.headline)
                Text("Pro")
                    .font(ResponsiveFont.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.16))
                    .clipShape(Capsule())
            }

            if reuseExportInProgress && !reuseExportFilename.contains("backup") {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Preparing advanced export…")
                        .font(ResponsiveFont.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if let msg = reuseExportMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(msg)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Dismiss") { reuseExportMessage = nil }
                        .font(ResponsiveFont.caption)
                }
            }

            sourceCodeHelperSection

            premiumExportOption(
                title: "Full Dataset JSON",
                subtitle: "Best for analysis, transformation, or custom tooling built on both dictionary and phrase data.",
                filename: $fullDatasetFileName,
                fileExtension: ".json",
                systemName: "shippingbox.fill",
                color: .green,
                action: {
                    let name = fullDatasetFileName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let data = try dataExportService.exportFullDataset(store.fullDatasetExportPackage())
                    reuseExportDocument = BinaryFileDocument(data: data)
                    reuseExportFilename = name.isEmpty ? "radix_full_dataset" : name
                    reuseExportContentType = .json
                }
            )

            premiumExportOption(
                title: "Dictionary Database Export",
                subtitle: "Best for extending Radix-like dictionary products or building your own structured reference layer.",
                filename: $mergedDictionaryFileName,
                fileExtension: ".db",
                systemName: "books.vertical.fill",
                color: .blue,
                action: {
                    let name = mergedDictionaryFileName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let data = try dataExportService.exportMergedDictionaryDatabase(records: store.mergedDictionaryExportRecords())
                    reuseExportDocument = BinaryFileDocument(data: data)
                    reuseExportFilename = name.isEmpty ? "radix_merged_dictionary" : name
                    reuseExportContentType = .data
                }
            )

            premiumExportOption(
                title: "Phrase Database Export",
                subtitle: "Best for phrase-study tools, corpora experiments, and custom learning products built from your phrase layer.",
                filename: $mergedPhrasesFileName,
                fileExtension: ".db",
                systemName: "text.book.closed.fill",
                color: .teal,
                action: {
                    let name = mergedPhrasesFileName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let data = try dataExportService.exportMergedPhrasesDatabase(phrases: store.mergedPhrasesForExport())
                    reuseExportDocument = BinaryFileDocument(data: data)
                    reuseExportFilename = name.isEmpty ? "radix_merged_phrases" : name
                    reuseExportContentType = .data
                }
            )
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.08), Color.accentColor.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var sourceCodeHelperSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(ResponsiveFont.title3)
                    .foregroundStyle(Color.indigo)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Source Code")
                        .font(ResponsiveFont.subheadline.bold())
                    Text("Share a copy of the Radix project code from GitHub.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Text(sourceCodeURL.absoluteString)
                .font(ResponsiveFont.caption.monospaced())
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text("No GitHub account needed: open the link, click Code, then Download ZIP.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                Text("Git users can clone with:")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                Text(sourceCloneCommand)
                    .font(ResponsiveFont.caption.monospaced())
                    .textSelection(.enabled)
            }

            DisclosureGroup("Setup & Usage Guide", isExpanded: $showSourceSetupGuide) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(sourceSetupGuide)
                        .font(ResponsiveFont.caption)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        copyToClipboard(sourceSetupGuide)
                        reuseExportMessage = "Setup guide copied."
                    } label: {
                        Label("Copy Guide", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.top, 8)
            }
            .font(ResponsiveFont.subheadline.weight(.semibold))

            HStack(spacing: 10) {
                Button {
                    openURL(sourceCodeURL)
                } label: {
                    Label("Open Repo", systemImage: "safari")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button {
                    copyToClipboard(sourceCodeURL.absoluteString)
                    reuseExportMessage = "Repository URL copied."
                } label: {
                    Label("Copy URL", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    copyToClipboard(sourceCloneCommand)
                    reuseExportMessage = "Clone command copied."
                } label: {
                    Label("Copy Git", systemImage: "terminal")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(14)
        .background(Color.indigo.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.indigo.opacity(0.30), lineWidth: 1)
        )
    }

    private func copyToClipboard(_ value: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = value
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        #endif
    }

    @ViewBuilder
    private func backupCharacterRows(_ characters: [String], badge: String) -> some View {
        let displayed = Array(characters.prefix(80))
        let truncated = characters.count > displayed.count

        VStack(alignment: .leading, spacing: 8) {
            if characters.isEmpty {
                Text("No matching characters.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(displayed, id: \.self) { character in
                        let item = store.item(for: character)
                        backupCharacterRow(character, badge: badge, item: item)
                    }
                }

                if truncated {
                    Text("Showing the first \(displayed.count) of \(characters.count) characters.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func backupCharacterRow(_ character: String, badge: String, item: ComponentItem?) -> some View {
        let pinyin = item?.pinyinText ?? ""
        let definition = item?.definition ?? ""
        let isBuiltInCharacter = store.editedDictionaryCharactersSet.contains(character)

        HStack(alignment: .top, spacing: 10) {
            Text(character)
                .font(ResponsiveFont.title3.bold())
                .copyCharacterContextMenu(character, pinyin: pinyin)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 2) {
                if !pinyin.isEmpty {
                    Text(pinyin)
                        .font(ResponsiveFont.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Text(definition.isEmpty ? "No definition" : definition)
                    .font(ResponsiveFont.caption)
                    .lineLimit(2)
            }

            Spacer()

            HStack(spacing: 6) {
                Button(store.characterNotesActionTitle(for: character)) {
                    store.openQuickCharacterEditor(character)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                Button(role: isBuiltInCharacter ? nil : .destructive) {
                    if isBuiltInCharacter {
                        store.restoreDictionaryCharacterFromLibrary(character)
                    } else {
                        store.loadDataEditEntry(for: character)
                        try? store.deleteCurrentDataEditEntry()
                    }
                } label: {
                    Text(isBuiltInCharacter ? "Revert" : "Delete")
                        .font(ResponsiveFont.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded {
            store.preview(character: character)
            #if !targetEnvironment(macCatalyst)
            if UIDevice.current.userInterfaceIdiom == .phone {
                withAnimation { dataEditScrollProxy?.scrollTo("myDataTop", anchor: .top) }
            }
            #endif
        })
    }

    @ViewBuilder
    private func backupPhraseRows(_ phrases: [PhraseItem], badge: String) -> some View {
        if phrases.isEmpty {
            Text("No matching phrases.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(phrases) { phrase in
                    backupPhraseRow(phrase, badge: badge)
                }
            }
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func backupPhraseRow(_ phrase: PhraseItem, badge: String) -> some View {
        let isBuiltInPhrase = store.isPhraseInBase(phrase.word)

        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(phrase.word)
                    .font(ResponsiveFont.subheadline.bold())
                    .phraseContextMenu(phrase)

                Spacer()

                HStack(spacing: 6) {
                    Button("Edit") {
                        store.openQuickPhraseEditor(word: phrase.word)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button(role: isBuiltInPhrase ? nil : .destructive) {
                        store.removeDataEditPhrase(word: phrase.word)
                    } label: {
                        Text(isBuiltInPhrase ? "Revert" : "Delete")
                            .font(ResponsiveFont.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }

            if !phrase.pinyin.isEmpty {
                Text(phrase.pinyin)
                    .font(ResponsiveFont.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Text(phrase.meanings.isEmpty ? "No meaning" : phrase.meanings)
                .font(ResponsiveFont.caption)
                .lineLimit(2)
        }
        .padding(10)
        .background(Color(.secondarySystemBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func premiumExportOption(
        title: String,
        subtitle: String,
        filename: Binding<String>,
        fileExtension: String,
        systemName: String,
        color: Color,
        action: @escaping () throws -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("Filename", text: filename)
                    .font(ResponsiveFont.body.monospaced())
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Text(fileExtension)
                    .font(ResponsiveFont.body.monospaced())
                    .foregroundStyle(.secondary)
            }

            Button {
                guard !entitlement.requiresPro(.dataEdit) else {
                    onRequirePro(.dataEdit)
                    return
                }

                reuseExportInProgress = true
                reuseExportMessage = nil
                Task { @MainActor in
                    do {
                        try action()
                        reuseExportInProgress = false
                        showReuseExporter = true
                    } catch {
                        reuseExportInProgress = false
                        reuseExportMessage = "Export failed: \(error.localizedDescription)"
                    }
                }
            } label: {
                exportOptionCard(
                    title: title,
                    subtitle: entitlement.requiresPro(.dataEdit) ? "\(subtitle) Unlock Pro to export." : subtitle,
                    systemName: entitlement.requiresPro(.dataEdit) ? "lock.fill" : systemName,
                    color: color
                )
            }
            .buttonStyle(.plain)
            .disabled(reuseExportInProgress)
        }
    }

    @ViewBuilder
    private var dictionaryDataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label {
                Text("1. Core Dictionary")
                    .font(ResponsiveFont.headline)
            } icon: {
                Image(systemName: "book.closed")
            }
            .foregroundStyle(Color.accentColor)

            // Add New Character button
            Button {
                store.openNewCharacterEditor()
            } label: {
                Label("Add New Character", systemImage: "plus.circle.fill")
                    .font(ResponsiveFont.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            addedDictionarySection
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var phraseIntegrationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label {
                Text("2. Phrases & English Meanings")
                    .font(ResponsiveFont.headline)
            } icon: {
                Image(systemName: "character.bubble")
            }
            .foregroundStyle(Color.accentColor)

            Button {
                store.openNewPhraseEditor()
            } label: {
                Label("Add New Phrase", systemImage: "plus.circle.fill")
                    .font(ResponsiveFont.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            changedPhrasesSection
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var addedPhraseEntries: [PhraseItem] {
        changedPhraseEntries.filter { !store.isPhraseInBase($0.word) }
    }

    private var editedPhraseEntries: [PhraseItem] {
        changedPhraseEntries.filter { store.isPhraseInBase($0.word) }
    }

    private var changedPhraseEntries: [PhraseItem] {
        var merged: [PhraseItem] = []
        for phrase in store.addedPhrases + store.dataEditPhrases {
            if let index = merged.firstIndex(where: { $0.word == phrase.word }) {
                merged[index] = phrase
            } else {
                merged.append(phrase)
            }
        }
        return merged
    }

    private var changedPhrasesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Changed Phrases")
                .font(ResponsiveFont.subheadline.bold())

            Text("Added phrases are new. Edited phrases are built-in phrases you changed for your own copy.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)

            if changedPhraseEntries.isEmpty {
                Text("No changed phrases yet.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            } else {
                if !addedPhraseEntries.isEmpty {
                    changedPhraseGroup(title: "Added", phrases: addedPhraseEntries)
                }
                if !editedPhraseEntries.isEmpty {
                    changedPhraseGroup(title: "Edited", phrases: editedPhraseEntries)
                }
            }
        }
    }

    private func changedPhraseGroup(title: String, phrases: [PhraseItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(title) (\(phrases.count))")
                .font(ResponsiveFont.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(phrases) { phrase in
                editablePhraseCard(phrase)
            }
        }
    }

    private func editablePhraseCard(_ phrase: PhraseItem) -> some View {
        let isBuiltInPhrase = store.isPhraseInBase(phrase.word)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(phrase.word)
                    .font(ResponsiveFont.headline)
                    .phraseContextMenu(phrase)
                Spacer()
                Button("Edit") {
                    store.openQuickPhraseEditor(word: phrase.word)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                Button(role: isBuiltInPhrase ? nil : .destructive) {
                    store.removeDataEditPhrase(word: phrase.word)
                } label: {
                    Text(isBuiltInPhrase ? "Revert" : "Delete")
                        .font(ResponsiveFont.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

            Text(phrase.pinyin)
                .font(ResponsiveFont.body.monospaced())

            Text(phrase.meanings)
                .font(ResponsiveFont.body)
        }
        .padding(10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var aiTemplatesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label {
                Text("3. AI Prompt Templates")
                    .font(ResponsiveFont.headline)
            } icon: {
                Image(systemName: "sparkles")
            }
            .foregroundStyle(Color.accentColor)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Prompt Preamble")
                    .font(ResponsiveFont.caption.bold())
                TextEditor(text: Binding(
                    get: { store.promptConfig.preamble },
                    set: { store.setPromptPreamble($0) }
                ))
                .font(ResponsiveFont.body)
                .frame(height: 120)
                .padding(6)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                ForEach(store.promptConfig.tasks) { task in
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Task Title", text: Binding(
                                get: { store.promptConfig.tasks.first(where: { $0.id == task.id })?.title ?? "" },
                                set: { store.setPromptTaskTitle(taskID: task.id, title: $0) }
                            ))
                            .font(ResponsiveFont.body)
                            .textFieldStyle(.roundedBorder)
                            
                            TextEditor(text: Binding(
                                get: { store.promptConfig.tasks.first(where: { $0.id == task.id })?.template ?? "" },
                                set: { store.setPromptTaskTemplate(taskID: task.id, template: $0) }
                            ))
                            .font(ResponsiveFont.body)
                            .frame(height: 150)
                            .padding(6)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(.vertical, 4)
                    } label: {
                        Text(task.title)
                            .font(ResponsiveFont.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func exportFormatDetail(title: String, path: String, intendedUse: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(ResponsiveFont.caption.bold())
                .foregroundStyle(.secondary)
            Text(path)
                .font(ResponsiveFont.caption.monospaced())
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text("Best for: \(intendedUse)")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func exportOptionCard(title: String, subtitle: String, systemName: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemName)
                .font(ResponsiveFont.title3)
                .foregroundStyle(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(ResponsiveFont.subheadline.bold())
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.35), lineWidth: 1)
        )
    }

    private var addedDictionarySection: some View {
        let totalChangedCount = store.changedDictionaryCharacters.count

        return VStack(alignment: .leading, spacing: 16) {
            Text("Changed Characters")
                .font(ResponsiveFont.subheadline.bold())

            Text("Saved character changes are grouped here. Added characters can be deleted. Edited built-in characters can be reverted.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)

            if totalChangedCount == 0 {
                Text("No dictionary changes yet.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            } else {
                TextField("Search changed characters", text: $dictionaryChangeSearch)
                    .font(ResponsiveFont.body)
                    .textFieldStyle(.roundedBorder)

                if !displayedAddedDictionaryCharacters.isEmpty {
                    changedCharacterGroup(
                        title: "Added (\(filteredAddedDictionaryCharacters.count))",
                        characters: displayedAddedDictionaryCharacters,
                        badge: "Added"
                    )
                }

                if !displayedEditedDictionaryCharacters.isEmpty {
                    changedCharacterGroup(
                        title: "Notes Added (\(filteredEditedDictionaryCharacters.count))",
                        characters: displayedEditedDictionaryCharacters,
                        badge: "Notes Added"
                    )
                }

                if filteredAddedDictionaryCharacters.count > displayedAddedDictionaryCharacters.count ||
                    filteredEditedDictionaryCharacters.count > displayedEditedDictionaryCharacters.count {
                    Text("Showing the first 80 results. Refine your search to narrow the list.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func changedCharacterGroup(title: String, characters: [String], badge: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(ResponsiveFont.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(characters, id: \.self) { character in
                // Resolve item once here so editableCharacterCard doesn't call
                // store.item(for:) a second time on every render.
                let item = store.item(for: character)
                editableCharacterCard(character, badge: badge, item: item)
            }
        }
    }

    private var filteredAddedDictionaryCharacters: [String] {
        filterChangedDictionaryCharacters(store.addedDictionaryCharacters)
    }

    private var filteredEditedDictionaryCharacters: [String] {
        filterChangedDictionaryCharacters(store.editedDictionaryCharacters)
    }

    private var displayedAddedDictionaryCharacters: [String] {
        cappedChangedDictionaryCharacters(filteredAddedDictionaryCharacters)
    }

    private var displayedEditedDictionaryCharacters: [String] {
        cappedChangedDictionaryCharacters(filteredEditedDictionaryCharacters)
    }

    private func filterChangedDictionaryCharacters(_ characters: [String]) -> [String] {
        let query = dictionaryChangeSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return characters }
        return characters.filter { character in
            if character.lowercased().contains(query) {
                return true
            }
            guard let item = store.item(for: character) else { return false }
            return item.pinyinText.lowercased().contains(query) || item.definition.lowercased().contains(query)
        }
    }

    private func cappedChangedDictionaryCharacters(_ characters: [String]) -> [String] {
        // Cap at 80 unconditionally — even with a search query active — to prevent
        // the LazyVStack rendering thousands of cards on a broad search.
        return Array(characters.prefix(80))
    }

    private func editableCharacterCard(_ character: String, badge: String, item: ComponentItem?) -> some View {
        // O(1) Set lookup — replaces the O(n) [String].contains scan.
        let isBuiltInCharacter = store.editedDictionaryCharactersSet.contains(character)
        let pinyin = item?.pinyinText ?? ""
        let definition = item?.definition ?? ""

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(character)
                    .font(ResponsiveFont.headline)
                    .copyTextContextMenu(character, buttonTitle: "Copy Character", secondaryText: pinyin, secondaryButtonTitle: "Copy Pinyin")
                Spacer()
                Text(badge)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)

                Button(store.characterNotesActionTitle(for: character)) {
                    store.openQuickCharacterEditor(character)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                Button(role: isBuiltInCharacter ? nil : .destructive) {
                    if isBuiltInCharacter {
                        store.restoreDictionaryCharacterFromLibrary(character)
                    } else {
                        store.loadDataEditEntry(for: character)
                        do {
                            try store.deleteCurrentDataEditEntry()
                        } catch {}
                    }
                } label: {
                    Text(isBuiltInCharacter ? "Revert" : "Delete")
                        .font(ResponsiveFont.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

            if !pinyin.isEmpty {
                Text(pinyin)
                    .font(ResponsiveFont.body.monospaced())
            }

            if !definition.isEmpty {
                Text(definition)
                    .font(ResponsiveFont.body)
            }
        }
        .padding(10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded {
            store.preview(character: character)
            #if !targetEnvironment(macCatalyst)
            if UIDevice.current.userInterfaceIdiom == .phone {
                withAnimation { dataEditScrollProxy?.scrollTo("myDataTop", anchor: .top) }
            }
            #endif
        })
    }

    private var activeCharacterContext: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let current = store.previewCharacter {
                standardPhoneCharacterPreview(
                    character: current,
                    selectedCharacter: store.selectedCharacter,
                    onClear: { store.previewCharacter = nil }
                )
            }
        }
    }

    private func varianceGrid(items: [DictionaryVariance]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 8) {
            ForEach(items) { variance in
                Button {
                    // For phrases, we try to load the first character of the word into the studio
                    let target = String(variance.character.prefix(1))
                    store.loadDataEditEntry(for: target)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(variance.character)
                                .font(ResponsiveFont.subheadline.bold())
                                .lineLimit(1)
                            Spacer()
                            varianceIcon(for: variance.type)
                        }
                        Text(variance.type.rawValue)
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(varianceColor(for: variance.type).opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func varianceIcon(for type: DictionaryVariance.VarianceType) -> some View {
        switch type {
        case .added:
            return Image(systemName: "plus.circle.fill").font(ResponsiveFont.body).foregroundStyle(.green)
        case .missing:
            return Image(systemName: "exclamationmark.circle.fill").font(ResponsiveFont.body).foregroundStyle(.red)
        }
    }

    private func varianceColor(for type: DictionaryVariance.VarianceType) -> Color {
        switch type {
        case .added: return .green
        case .missing: return .red
        }
    }

    private func explainerGridRow(title: String, desc: String) -> some View {
        let titleWidth: CGFloat = {
            #if targetEnvironment(macCatalyst)
            return 110 // Wider for Mac to prevent "Restore" from wrapping
            #else
            return 80
            #endif
        }()
        
        return GridRow {
            Text(title)
                .font(ResponsiveFont.subheadline.bold())
                .frame(width: titleWidth, alignment: .leading)
            Text(desc)
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func explainerRow(title: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(ResponsiveFont.subheadline.bold())
            Text(desc)
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func labeledEditor(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: text)
                .font(ResponsiveFont.body)
                .frame(minHeight: 100, maxHeight: 180)
                .padding(6)
                .background(Color(.secondarySystemBackground).opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
