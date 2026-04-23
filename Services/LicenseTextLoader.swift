import Foundation

enum LicenseTextLoader {
    static func loadText(
        fileName: String,
        fileExtension: String = "txt",
        subdirectory: String = "Licenses"
    ) -> String {
        guard let url = Bundle.main.url(
            forResource: fileName,
            withExtension: fileExtension,
            subdirectory: subdirectory
        ) else {
            return "License file not found: \(fileName).\(fileExtension)"
        }

        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            return "Unable to load license text for \(fileName)."
        }
    }
}

