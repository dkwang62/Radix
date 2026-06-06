import SwiftUI

extension DataEditTab {
    var premiumExportsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Advanced Pro Files")
                    .font(ResponsiveFont.headline)
                Text("$99")
                    .font(ResponsiveFont.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if entitlement.requiresPro(.advanced) {
                Label("You can see every file type here. Creating the files unlocks with Advanced Pro.", systemImage: "lock.open")
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
                title: "App Data Files",
                subtitle: "The main Radix data files, including your latest characters and phrases.",
                toolsTip: AdvancedExportToolsTip(
                    title: "Where This Is Used",
                    message: "For working with the Radix project on a Mac."
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
                title: "All Data Text File",
                subtitle: "One readable file with the Radix data in it.",
                toolsTip: AdvancedExportToolsTip(
                    title: "Where This Is Used",
                    message: "For reading or reusing Radix data in other apps."
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
                title: "Character Database",
                subtitle: "A database file for the character dictionary.",
                toolsTip: AdvancedExportToolsTip(
                    title: "Where This Is Used",
                    message: "For database apps or custom tools."
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
                title: "Phrase Database",
                subtitle: "A database file for saved and edited phrases.",
                toolsTip: AdvancedExportToolsTip(
                    title: "Where This Is Used",
                    message: "For database apps or custom tools."
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
