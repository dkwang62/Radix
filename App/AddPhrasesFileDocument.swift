import SwiftUI
import UniformTypeIdentifiers

struct AddPhrasesFileDocument: FileDocument {
    static var contentType: UTType {
        UTType(filenameExtension: "db") ?? .data
    }

    static var readableContentTypes: [UTType] { [contentType, .data] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

