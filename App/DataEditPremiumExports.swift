import SwiftUI

extension DataEditTab {
    var premiumExportsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Advanced Pro Files")
                    .font(ResponsiveFont.headline)
            }

            if entitlement.requiresPro(.advanced) {
                Label("You can see every file type here. Creating the files unlocks with Advanced Pro.", systemImage: "lock.open")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RadixTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if reuseExportInProgress && !reuseExportFilename.contains("backup") {
                AdvancedExportProgressRow()
            } else if let msg = reuseExportMessage {
                AdvancedExportMessageRow(message: msg) {
                    reuseExportMessage = nil
                }
            }

            premiumExportOption(
                title: "App Project Files",
                subtitle: "A ZIP of the Radix Xcode project: Swift source, resources, databases, and manifest for rebuilding on another Mac.",
                toolsTip: AdvancedExportToolsTip(
                    title: "Requires Xcode",
                    message: "Use this on a Mac with Xcode. It is intended to recreate or inspect the Radix project source, not to open inside a normal text editor."
                ),
                systemName: "doc.zipper",
                color: .purple,
                action: {
                    let name = projectArchiveFileName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let data = try dataExportService.exportBundledProjectArchive()
                    reuseExportDocument = BinaryFileDocument(data: data)
                    reuseExportFilename = name.isEmpty ? ProjectArchiveName.baseName() : name
                    reuseExportContentType = .zipArchive
                    activeZipExportKind = .projectArchive
                    activeAdvancedExportKind = .projectArchive
                }
            )

            premiumExportOption(
                title: "All Data Text File",
                subtitle: "One JSON file with Radix learning data that can be read by text editors, scripts, and data tools.",
                toolsTip: AdvancedExportToolsTip(
                    title: "JSON File",
                    message: "This is the easiest export to inspect manually. Open it with a text editor, code editor, or any tool that understands JSON."
                ),
                systemName: "shippingbox.fill",
                color: .green,
                action: {
                    let name = fullDatasetFileName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let data = try dataExportService.exportFullDataset(store.fullDatasetExportPackage())
                    reuseExportDocument = BinaryFileDocument(data: data)
                    reuseExportFilename = name.isEmpty ? "radix_full_dataset" : name
                    reuseExportContentType = RadixFileTypes.json
                    activeAdvancedExportKind = .fullDataset
                }
            )

            premiumExportOption(
                title: "Character Database",
                subtitle: "A SQLite database for the character dictionary. Open with DB Browser for SQLite, sqlite3, or database tools.",
                toolsTip: AdvancedExportToolsTip(
                    title: "SQLite Database",
                    message: "This is not a plain text file. Use DB Browser for SQLite, TablePlus, sqlite3, or a custom app that can read SQLite databases."
                ),
                systemName: "books.vertical.fill",
                color: .blue,
                action: {
                    let name = mergedDictionaryFileName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let data = try dataExportService.exportMergedDictionaryDatabase(records: store.mergedDictionaryExportRecords())
                    reuseExportDocument = BinaryFileDocument(data: data)
                    reuseExportFilename = name.isEmpty ? "radix_merged_dictionary" : name
                    reuseExportContentType = RadixFileTypes.data
                    activeAdvancedExportKind = .dictionaryDatabase
                }
            )

            premiumExportOption(
                title: "Phrase Database",
                subtitle: "A SQLite database for saved and edited phrases. Open with DB Browser for SQLite, sqlite3, or database tools.",
                toolsTip: AdvancedExportToolsTip(
                    title: "SQLite Database",
                    message: "This is not a plain text file. Use DB Browser for SQLite, TablePlus, sqlite3, or a custom app that can read SQLite databases."
                ),
                systemName: "text.book.closed.fill",
                color: .teal,
                action: {
                    let name = mergedPhrasesFileName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let data = try dataExportService.exportMergedPhrasesDatabase(phrases: store.mergedPhrasesForExport())
                    reuseExportDocument = BinaryFileDocument(data: data)
                    reuseExportFilename = name.isEmpty ? "radix_merged_phrases" : name
                    reuseExportContentType = RadixFileTypes.data
                    activeAdvancedExportKind = .phraseDatabase
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
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .alert(item: $advancedToolsTip) { tip in
            Alert(
                title: Text(tip.title),
                message: Text(tip.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    func premiumExportOption(
        title: String,
        subtitle: String,
        toolsTip: AdvancedExportToolsTip,
        systemName: String,
        color: Color,
        action: @escaping () throws -> Void
    ) -> some View {
        AdvancedExportOptionRow(
            title: title,
            subtitle: subtitle,
            toolsTip: toolsTip,
            systemName: systemName,
            color: color,
            isLocked: entitlement.requiresPro(.advanced),
            isDisabled: reuseExportInProgress,
            onExport: {
                guard !entitlement.requiresPro(.advanced) else {
                    onRequirePro(.advanced)
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
            },
            onShowTools: { advancedToolsTip = $0 }
        )
    }

}
