import SwiftUI
import UniformTypeIdentifiers

// MARK: - FileTransferModifier
//
// Usage: replace the four .fileExporter / .fileImporter / .alert blocks
// in RootView.body with a single:
//
//   .modifier(FileTransferModifier(
//       profileExportDocument:    $profileExportDocument,
//       addPhrasesExportDocument: $addPhrasesExportDocument,
//       showProfileExporter:      $showProfileExporter,
//       showProfileImporter:      $showProfileImporter,
//       showAddPhrasesExporter:   $showAddPhrasesExporter,
//       showAddPhrasesImporter:   $showAddPhrasesImporter,
//       importExportError:        $importExportError,
//       importExportMessage:      $importExportMessage,
//       showImportExportAlert:    $showImportExportAlert,
//       onProfileImport:          { data in try store.importProfileData(data) },
//       onAddPhrasesImport:       { url in try store.setAddPhrasesFile(url: url) }
//   ))
//
// All @State properties stay in RootView exactly as they are today.
// The modifier just moves the modifier chain out of body.

struct FileTransferModifier: ViewModifier {

    // Bindings to RootView's existing @State
    @Binding var profileExportDocument: JSONFileDocument
    @Binding var addPhrasesExportDocument: AddPhrasesFileDocument
    @Binding var showProfileExporter: Bool
    @Binding var showProfileImporter: Bool
    @Binding var showAddPhrasesExporter: Bool
    @Binding var showAddPhrasesImporter: Bool
    @Binding var importExportError: String?
    @Binding var importExportMessage: String?
    @Binding var showImportExportAlert: Bool

    // Callbacks that need store access (caller provides these closures)
    let onProfileImport: (Data) throws -> Void
    let onAddPhrasesImport: (URL) throws -> Void

    func body(content: Content) -> some View {
        content
            // ── Profile export ────────────────────────────────────────────
            .fileExporter(
                isPresented: $showProfileExporter,
                document: profileExportDocument,
                contentType: .json,
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
            // ── Profile import ────────────────────────────────────────────
            .fileImporter(
                isPresented: $showProfileImporter,
                allowedContentTypes: [.json, .data],
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
            // ── Add-phrases export ────────────────────────────────────────
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
            // ── Add-phrases import ────────────────────────────────────────
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
            // ── Success alert ─────────────────────────────────────────────
            .alert("Data Transfer", isPresented: $showImportExportAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                if let msg = importExportMessage { Text(msg) }
            }
            // ── Error alert ───────────────────────────────────────────────
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
