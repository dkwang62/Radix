import SwiftUI

extension DataEditTab {
    var premiumExportsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Advanced Exports")
                    .font(ResponsiveFont.headline)
            }

            Label(
                "Export the code and structured data foundation that you can give to AI coding agents to study, modify, or use when authoring your own software.",
                systemImage: "hammer"
            )
            .font(ResponsiveFont.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

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
                title: "Xcode Project ZIP",
                subtitle: "Swift source, resources, databases, and a manifest that an AI coding agent can examine when helping you author or adapt an app.",
                toolsTip: AdvancedExportToolsTip(
                    title: "Code foundation",
                    message: "Use this on a Mac with Xcode or in an AI coding workspace. It provides the complete Radix project foundation rather than a normal backup."
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
                title: "Full Dataset (JSON)",
                subtitle: "One structured JSON file an AI agent, script, or new app can read when building features around your Radix data.",
                toolsTip: AdvancedExportToolsTip(
                    title: "AI-friendly data",
                    message: "This is the easiest foundation to give an AI coding agent. It is readable by text editors, code tools, scripts, and any app that understands JSON."
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
                subtitle: "A reusable SQLite character dictionary for an AI agent or your own code to query and build upon.",
                toolsTip: AdvancedExportToolsTip(
                    title: "Reusable SQLite foundation",
                    message: "Ask an AI coding agent to inspect the schema or connect it to your code. You can also use DB Browser for SQLite, TablePlus, or sqlite3."
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
                subtitle: "A reusable SQLite phrase collection for an AI agent or your own code to search, transform, and extend.",
                toolsTip: AdvancedExportToolsTip(
                    title: "Reusable SQLite foundation",
                    message: "Ask an AI coding agent to inspect the schema or connect it to your code. You can also use DB Browser for SQLite, TablePlus, or sqlite3."
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
