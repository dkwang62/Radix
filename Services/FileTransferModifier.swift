import SwiftUI

struct FileTransferModifier: ViewModifier {
    @Binding var profileExportDocument: JSONFileDocument
    @Binding var addPhrasesExportDocument: AddPhrasesFileDocument
    @Binding var showProfileExporter: Bool
    @Binding var showProfileImporter: Bool
    @Binding var showAddPhrasesExporter: Bool
    @Binding var showAddPhrasesImporter: Bool
    @Binding var importExportError: String?
    @Binding var importExportMessage: String?
    @Binding var showImportExportAlert: Bool

    let onProfileImport: (Data) throws -> Void
    let onAddPhrasesImport: (URL) throws -> Void

    private var alertTitle: String {
        guard let message = importExportMessage?.lowercased() else {
            return "Radix"
        }

        if message.contains("snapshot") || message.contains("saved locally") || message.contains("restored local") {
            return "Snapshot"
        }

        if message.contains("backup") {
            return "Backup"
        }

        if message.contains("phrase") {
            return "Phrases"
        }

        return "Radix"
    }

    func body(content: Content) -> some View {
        content
            .fileExporter(
                isPresented: $showProfileExporter,
                document: profileExportDocument,
                contentType: RadixFileTypes.json,
                defaultFilename: "radix_user_data"
            ) { result in
                switch result {
                case .success(let url):
                    importExportMessage = "Profile backup saved successfully to: \(url.lastPathComponent)"
                    showImportExportAlert = true
                case .failure(let error):
                    importExportError = error.localizedDescription
                }
            }
            .fileImporter(
                isPresented: $showProfileImporter,
                allowedContentTypes: RadixFileTypes.backupImports,
                allowsMultipleSelection: false
            ) { result in
                do {
                    guard let url = try result.get().first else { return }
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    let data = try Data(contentsOf: url)
                    try onProfileImport(data)
                    importExportMessage = "Profile successfully imported from: \(url.lastPathComponent)"
                    showImportExportAlert = true
                } catch {
                    importExportError = error.localizedDescription
                }
            }
            .fileExporter(
                isPresented: $showAddPhrasesExporter,
                document: addPhrasesExportDocument,
                contentType: AddPhrasesFileDocument.contentType,
                defaultFilename: "phrases_add.db"
            ) { result in
                switch result {
                case .success(let url):
                    importExportMessage = "Phrases additions file exported to: \(url.lastPathComponent)"
                    showImportExportAlert = true
                case .failure(let error):
                    importExportError = error.localizedDescription
                }
            }
            .fileImporter(
                isPresented: $showAddPhrasesImporter,
                allowedContentTypes: AddPhrasesFileDocument.readableContentTypes,
                allowsMultipleSelection: false
            ) { result in
                do {
                    guard let url = try result.get().first else { return }
                    try onAddPhrasesImport(url)
                    importExportMessage = "Using phrase additions file: \(url.lastPathComponent)"
                    showImportExportAlert = true
                } catch {
                    importExportError = error.localizedDescription
                }
            }
            .alert(alertTitle, isPresented: $showImportExportAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                if let msg = importExportMessage { Text(msg) }
            }
            .alert("Transfer Error", isPresented: Binding(
                get: { importExportError != nil },
                set: { if !$0 { importExportError = nil } }
            )) {
                Button("OK", role: .cancel) { importExportError = nil }
            } message: {
                Text(importExportError ?? "")
            }
    }
}
