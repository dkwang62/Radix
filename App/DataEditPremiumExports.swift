import SwiftUI

extension DataEditTab {
    var premiumExportsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Advanced Exports")
                    .font(ResponsiveFont.headline)
                Text("$99")
                    .font(ResponsiveFont.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if entitlement.requiresPro(.advanced) {
                Label("You can inspect every Advanced export option. Exporting unlocks with Advanced.", systemImage: "lock.open")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
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
                    activeAdvancedExportKind = .xcodeDataFiles
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
                    activeAdvancedExportKind = .fullDataset
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
                    activeAdvancedExportKind = .dictionaryDatabase
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
