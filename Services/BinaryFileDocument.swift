import SwiftUI
import UniformTypeIdentifiers

struct BinaryFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data, RadixFileTypes.database, RadixFileTypes.sqlite] }
    static var writableContentTypes: [UTType] { [.data, .json, .plainText, .commaSeparatedText, .zipArchive, RadixFileTypes.database, RadixFileTypes.sqlite] }

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

extension UTType {
    static var zipArchive: UTType {
        UTType(filenameExtension: "zip") ?? .data
    }
}
