import SwiftUI

extension DataEditTab {
    var premiumExportsSection: some View {
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
                AdvancedExportProgressRow()
            } else if let msg = reuseExportMessage {
                AdvancedExportMessageRow(message: msg) {
                    reuseExportMessage = nil
                }
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
                    let stampedName = ProjectArchiveName.stampedBaseName(name.isEmpty ? "radix_project" : name, for: createdAt)
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
            isLocked: entitlement.requiresPro(.dataEdit),
            isDisabled: reuseExportInProgress,
            onExport: {
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
            },
            onShowTools: { advancedToolsTip = $0 }
        )
    }
}
