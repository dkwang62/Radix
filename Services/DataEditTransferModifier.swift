import SwiftUI

struct DataEditTransferModifier: ViewModifier {
    @Binding var reuseExportDocument: BinaryFileDocument
    @Binding var reuseExportContentType: RadixFileType
    @Binding var reuseExportFilename: String
    @Binding var showReuseExporter: Bool
    @Binding var reuseExportInProgress: Bool
    @Binding var backupError: String?
    @Binding var showBackupAlert: Bool

    let onExportSuccess: (URL) -> Void

    func body(content: Content) -> some View {
        content
            .fileExporter(
                isPresented: $showReuseExporter,
                document: reuseExportDocument,
                contentType: reuseExportContentType,
                defaultFilename: reuseExportFilename
            ) { result in
                reuseExportInProgress = false
                switch result {
                case .success(let url):
                    onExportSuccess(url)
                case .failure(let error):
                    backupError = error.localizedDescription
                    showBackupAlert = true
                }
            }
    }
}
