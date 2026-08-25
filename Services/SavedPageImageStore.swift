import SwiftUI

final class SavedPageImageStore {
    private let fileManager: FileManager
    private let directoryURL: URL

    init(
        fileManager: FileManager = .default,
        directoryURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.directoryURL = directoryURL ?? Self.defaultDirectoryURL(fileManager: fileManager)
    }

    func imageData(for pageID: UUID) -> Data? {
        try? Data(contentsOf: imageURL(for: pageID), options: .mappedIfSafe)
    }

    func store(_ data: Data, for pageID: UUID) throws {
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        try data.write(to: imageURL(for: pageID), options: .atomic)
    }

    func removeImage(for pageID: UUID) {
        let url = imageURL(for: pageID)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try? fileManager.removeItem(at: url)
    }

    func removeAllImages() {
        guard fileManager.fileExists(atPath: directoryURL.path) else { return }
        try? fileManager.removeItem(at: directoryURL)
    }

    func pruneImages(keeping pageIDs: Set<UUID>) {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }

        let retainedNames = Set(pageIDs.map { $0.uuidString.lowercased() })
        for url in urls where url.pathExtension.lowercased() == "jpg" {
            guard !retainedNames.contains(url.deletingPathExtension().lastPathComponent.lowercased()) else { continue }
            try? fileManager.removeItem(at: url)
        }
    }

    private func imageURL(for pageID: UUID) -> URL {
        directoryURL
            .appendingPathComponent(pageID.uuidString.lowercased())
            .appendingPathExtension("jpg")
    }

    private static func defaultDirectoryURL(fileManager: FileManager) -> URL {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return applicationSupport
            .appendingPathComponent("Radix", isDirectory: true)
            .appendingPathComponent("Saved Page Images", isDirectory: true)
    }
}

struct RadixPageIconView: View {
    var size: CGFloat
    var cornerRadius: CGFloat
    var systemImage: String = "photo"
    var color: Color = .secondary

    var body: some View {
        Image(systemName: systemImage)
            .font(ResponsiveFont.body)
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(RadixTheme.background.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
