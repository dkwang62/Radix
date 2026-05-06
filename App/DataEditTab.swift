import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import UniformTypeIdentifiers

struct DataEditTab: View {

    @EnvironmentObject private var store: RadixStore
    @EnvironmentObject private var entitlement: EntitlementManager
    @Environment(\.horizontalSizeClass) var sizeClass
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
    @State private var xcodeDataFilesFileName: String = "radix_xcode_data_files"
    @State private var projectArchiveFileName: String = DataEditTab.projectArchiveBaseName()
    @State private var reuseExportDocument = BinaryFileDocument(data: Data())
    @State private var reuseExportFilename: String = ""
    @State private var reuseExportContentType: UTType = .json
    @State private var showReuseExporter = false
    @State private var reuseExportInProgress = false
    @State private var reuseExportMessage: String?
    @State private var activeZipExportKind: AdvancedZipExportKind = .xcodeDataFiles
    @State private var advancedToolsTip: AdvancedExportToolsTip?
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
    @State private var showSavedPagesPreview = false
    @State private var showFavoritesPreview = false
    @State private var showAITemplatesPreview = false
    @State private var showAppStatePreview = false

    // UI toggles
    @State private var showAdvancedExports = false
    @State private var showHelp = false
    // Scroll-to-top support (phones only)
    @State private var dataEditScrollProxy: ScrollViewProxy?

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
                    if reuseExportContentType == .zipArchive {
                        if activeZipExportKind == .projectArchive {
                            projectArchiveFileName = base
                        } else {
                            xcodeDataFilesFileName = base
                        }
                    } else if reuseExportContentType == .json { fullDatasetFileName = base }
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
                    Text("Backup saves everything you've added or changed — custom characters, phrases, saved images, favorites, and AI templates — into a single file.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                    Text("Additive restore merges dictionary, phrase, and saved image changes. Complete restore replaces the app's overlay data, saved images, favorites, memory, search history, settings, and AI templates with the backup.")
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
                    pendingRestoreMode = .additive
                    showRestorePicker = true
                } label: {
                    backupActionButton(
                        title: "Additive Restore",
                        subtitle: "Keeps current data",
                        systemName: "square.and.arrow.down",
                        foreground: Color.accentColor,
                        background: Color.accentColor.opacity(0.1),
                        border: Color.accentColor.opacity(0.35)
                    )
                }
                .buttonStyle(.plain)

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
                    backupActionButton(
                        title: reuseExportInProgress && reuseExportFilename.contains("backup") ? "Preparing Backup…" : "Back Up My Data",
                        subtitle: "Exports your saved data",
                        systemName: "square.and.arrow.up.fill",
                        foreground: .white,
                        background: Color.accentColor,
                        border: Color.accentColor
                    )
                }
                .buttonStyle(.plain)
                .disabled(reuseExportInProgress)

                Button {
                    pendingRestoreMode = .complete
                    showRestorePicker = true
                } label: {
                    backupActionButton(
                        title: "Complete Restore",
                        subtitle: "Replaces data",
                        systemName: "square.and.arrow.down.fill",
                        foreground: Color.orange,
                        background: Color.orange.opacity(0.1),
                        border: Color.orange.opacity(0.35)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var whatsInMyBackupSection: some View {
        DataBackupPreviewSection(
            addedPhraseEntries: addedPhraseEntries,
            editedPhraseEntries: editedPhraseEntries,
            onPreviewCharacter: previewBackupCharacter,
            showSavedPagesPreview: $showSavedPagesPreview,
            showFavoritesPreview: $showFavoritesPreview,
            showAITemplatesPreview: $showAITemplatesPreview,
            showAppStatePreview: $showAppStatePreview,
            showAddedCharactersPreview: $showAddedCharactersPreview,
            showAddedPhrasesPreview: $showAddedPhrasesPreview,
            showEditedCharactersPreview: $showEditedCharactersPreview,
            showEditedPhrasesPreview: $showEditedPhrasesPreview
        )
    }

    private var advancedExportProgressRow: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Preparing advanced export…")
                .font(ResponsiveFont.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func advancedExportMessageRow(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(message)
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Dismiss") { reuseExportMessage = nil }
                .font(ResponsiveFont.caption)
        }
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
                advancedExportProgressRow
            } else if let msg = reuseExportMessage {
                advancedExportMessageRow(msg)
            }

            premiumExportOption(
                title: "Entire Project ZIP",
                subtitle: "A complete copy of Radix for changing app features, including your latest created or edited characters and phrases.",
                toolsTip: AdvancedExportToolsTip(
                    title: "Tools for Entire Project ZIP",
                    message: "Mac, Xcode/Swift, and AI coding help such as Codex, ChatGPT, or Claude Code."
                ),
                systemName: "folder.badge.plus",
                color: .indigo,
                action: {
                    let createdAt = Date()
                    let name = projectArchiveFileName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let stampedName = DataEditTab.stampedProjectArchiveBaseName(name.isEmpty ? "radix_project" : name, for: createdAt)
                    let data = try dataExportService.exportProjectDirectoryArchive(createdAt: createdAt)
                    reuseExportDocument = BinaryFileDocument(data: data)
                    reuseExportFilename = stampedName
                    reuseExportContentType = .zipArchive
                    activeZipExportKind = .projectArchive
                    projectArchiveFileName = reuseExportFilename
                }
            )

            premiumExportOption(
                title: "Xcode Data Files ZIP",
                subtitle: "The core Radix data files, including your latest created or edited characters and phrases, without the Swift code.",
                toolsTip: AdvancedExportToolsTip(
                    title: "Tools for Xcode Data Files ZIP",
                    message: "Mac and Xcode. Codex or ChatGPT can help place the files correctly."
                ),
                systemName: "doc.zipper",
                color: .purple,
                action: {
                    let name = xcodeDataFilesFileName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let addPhrasesData = try? store.exportAddPhrasesDB()
                    let data = try dataExportService.exportXcodeDataFiles(addPhrasesDBData: addPhrasesData)
                    reuseExportDocument = BinaryFileDocument(data: data)
                    reuseExportFilename = name.isEmpty ? "radix_xcode_data_files" : name
                    reuseExportContentType = .zipArchive
                    activeZipExportKind = .xcodeDataFiles
                }
            )

            premiumExportOption(
                title: "Full Dataset JSON",
                subtitle: "A readable all-in-one file for inspecting or reusing Radix data, including your latest created or edited entries.",
                toolsTip: AdvancedExportToolsTip(
                    title: "Tools for Full Dataset JSON",
                    message: "VS Code, Python, Excel or Numbers after conversion, or other data tools."
                ),
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
                subtitle: "The character dictionary as a database, including your latest created or edited characters.",
                toolsTip: AdvancedExportToolsTip(
                    title: "Tools for Dictionary Database",
                    message: "SQLite database tools, Python, VS Code database extensions, or other database apps."
                ),
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
                subtitle: "The phrase list as a database, including your latest created or edited phrases.",
                toolsTip: AdvancedExportToolsTip(
                    title: "Tools for Phrase Database",
                    message: "SQLite database tools, Python, VS Code database extensions, or other database apps."
                ),
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
        .alert(item: $advancedToolsTip) { tip in
            Alert(
                title: Text(tip.title),
                message: Text(tip.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private static func projectArchiveBaseName(for date: Date = Date()) -> String {
        stampedProjectArchiveBaseName("radix_project", for: date)
    }

    private static func stampedProjectArchiveBaseName(_ baseName: String, for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        let cleanBase = baseName.replacingOccurrences(
            of: #"_\d{4}-\d{2}-\d{2}-\d{4}$"#,
            with: "",
            options: .regularExpression
        )
        return "\(cleanBase)_\(formatter.string(from: date))"
    }

    private func previewBackupCharacter(_ character: String) {
        store.preview(character: character)
        #if !targetEnvironment(macCatalyst)
        if UIDevice.current.userInterfaceIdiom == .phone {
            withAnimation { dataEditScrollProxy?.scrollTo("myDataTop", anchor: .top) }
        }
        #endif
    }

    private func backupActionButton(
        title: String,
        subtitle: String,
        systemName: String,
        foreground: Color,
        background: Color,
        border: Color
    ) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemName)
                .font(ResponsiveFont.body.bold())
            Text(title)
                .font(ResponsiveFont.caption.bold())
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(subtitle)
                .font(ResponsiveFont.caption2)
                .multilineTextAlignment(.center)
                .opacity(0.85)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 84)
        .padding(.horizontal, 8)
        .background(background)
        .foregroundStyle(foreground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(border, lineWidth: 1)
        )
    }

    private func premiumExportOption(
        title: String,
        subtitle: String,
        toolsTip: AdvancedExportToolsTip,
        systemName: String,
        color: Color,
        action: @escaping () throws -> Void
    ) -> some View {
        HStack(spacing: 10) {
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

            Button {
                advancedToolsTip = toolsTip
            } label: {
                Image(systemName: "info.circle")
                    .font(ResponsiveFont.body)
                    .foregroundStyle(color)
                    .frame(width: 34, height: 34)
                    .background(color.opacity(0.10))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tools needed for \(title)")
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

            DataChangedDictionarySection(
                searchText: $dictionaryChangeSearch,
                onPreviewCharacter: previewBackupCharacter
            )
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

            DataChangedPhrasesSection(
                changedPhraseEntries: changedPhraseEntries,
                addedPhraseEntries: addedPhraseEntries,
                editedPhraseEntries: editedPhraseEntries
            )
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

    private var activeCharacterContext: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let current = store.previewCharacter {
                standardPhoneCharacterPreview(
                    character: current,
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

private enum AdvancedZipExportKind {
    case projectArchive
    case xcodeDataFiles
}

private struct AdvancedExportToolsTip: Identifiable {
    let title: String
    let message: String

    var id: String { title }
}
