import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        importSharedItem()
    }

    private func configureView() {
        view.backgroundColor = .systemBackground
        statusLabel.text = "Sending to Radix..."
        statusLabel.textAlignment = .center
        statusLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func importSharedItem() {
        if let provider = firstImageProvider() {
            loadImageData(from: provider)
            return
        }

        if let textProvider = firstTextProvider() {
            loadText(from: textProvider)
            return
        }

        finish(message: "Share an image or selected text.", openURL: nil)
    }

    private func firstImageProvider() -> NSItemProvider? {
        extensionContext?.inputItems
            .compactMap { $0 as? NSExtensionItem }
            .flatMap { $0.attachments ?? [] }
            .first { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }
    }

    private func firstTextProvider() -> NSItemProvider? {
        extensionContext?.inputItems
            .compactMap { $0 as? NSExtensionItem }
            .flatMap { $0.attachments ?? [] }
            .first { provider in
                provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
                    || provider.hasItemConformingToTypeIdentifier(UTType.text.identifier)
            }
    }

    @MainActor
    private func handleLoadedImageData(_ result: Result<Data, Error>) {
        switch result {
        case .failure:
            finish(message: "Unable to read image.", openURL: nil)
        case .success(let data):
            guard let destinationURL = RadixSharedImageImport.makeIncomingImageURL(fileExtension: "jpg") else {
                finish(message: "Unable to access Radix storage.", openURL: nil)
                return
            }

            do {
                try data.write(to: destinationURL, options: [.atomic])
                finish(message: "Image sent. Open Radix to create the page.", openURL: RadixSharedImageImport.importURL)
            } catch {
                finish(message: "Unable to send image.", openURL: nil)
            }
        }
    }

    @MainActor
    private func handleLoadedText(_ result: Result<String, Error>) {
        switch result {
        case .failure:
            finish(message: "Unable to read selected text.", openURL: nil)
        case .success(let text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                finish(message: "Selected text was empty.", openURL: nil)
                return
            }

            guard let destinationURL = RadixSharedImageImport.makeIncomingTextURL() else {
                finish(message: "Unable to access Radix storage.", openURL: nil)
                return
            }

            do {
                try trimmed.write(to: destinationURL, atomically: true, encoding: .utf8)
                finish(message: "Text sent. Open Radix to create the page.", openURL: RadixSharedImageImport.textImportURL)
            } catch {
                finish(message: "Unable to send text.", openURL: nil)
            }
        }
    }

    private func loadImageData(from provider: NSItemProvider) {
        let typeIdentifier = UTType.image.identifier
        guard provider.hasItemConformingToTypeIdentifier(typeIdentifier) else {
            finish(message: "No image found.", openURL: nil)
            return
        }

        let sendableProvider = SendableItemProvider(provider)
        sendableProvider.provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self, sendableProvider] url, error in
            if let data = Self.makeImageData(fromFileURL: url, error: error) {
                Task { @MainActor in
                    self?.handleLoadedImageData(.success(data))
                }
                return
            }

            sendableProvider.provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { [weak self, sendableProvider] data, error in
                if let data {
                    Task { @MainActor in
                        self?.handleLoadedImageData(.success(data))
                    }
                    return
                }

                sendableProvider.provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { [weak self] item, itemError in
                    let result = Self.makeImageData(from: item, error: itemError ?? error)
                    Task { @MainActor in
                        self?.handleLoadedImageData(result)
                    }
                }
            }
        }
    }

    private func loadText(from provider: NSItemProvider) {
        let typeIdentifier = provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
            ? UTType.plainText.identifier
            : UTType.text.identifier
        guard provider.hasItemConformingToTypeIdentifier(typeIdentifier) else {
            finish(message: "No selected text found.", openURL: nil)
            return
        }

        let sendableProvider = SendableItemProvider(provider)
        sendableProvider.provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { [weak self] item, error in
            let result = Self.makeText(from: item, error: error)
            Task { @MainActor in
                self?.handleLoadedText(result)
            }
        }
    }

    nonisolated private static func makeImageData(fromFileURL url: URL?, error: Error?) -> Data? {
        guard error == nil, let url else { return nil }
        let canAccess = url.startAccessingSecurityScopedResource()
        defer {
            if canAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try? Data(contentsOf: url)
    }

    nonisolated private static func makeImageData(from item: NSSecureCoding?, error: Error?) -> Result<Data, Error> {
        if let error {
            return .failure(error)
        }

        do {
            return .success(try imageData(from: item))
        } catch {
            return .failure(error)
        }
    }

    nonisolated private static func imageData(from item: NSSecureCoding?) throws -> Data {
        if let data = item as? Data {
            return data
        }

        if let image = item as? UIImage,
           let data = image.jpegData(compressionQuality: 0.95) ?? image.pngData() {
            return data
        }

        if let url = item as? URL {
            let canAccess = url.startAccessingSecurityScopedResource()
            defer {
                if canAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            return try Data(contentsOf: url)
        }

        throw NSError(domain: "RadixShareExtension", code: 1)
    }

    nonisolated private static func makeText(from item: NSSecureCoding?, error: Error?) -> Result<String, Error> {
        if let error {
            return .failure(error)
        }

        if let text = item as? String {
            return .success(text)
        }

        if let data = item as? Data,
           let text = String(data: data, encoding: .utf8) {
            return .success(text)
        }

        if let url = item as? URL,
           let text = try? String(contentsOf: url, encoding: .utf8) {
            return .success(text)
        }

        return .failure(NSError(domain: "RadixShareExtension", code: 2))
    }

    private func finish(message: String, openURL: URL?) {
        DispatchQueue.main.async {
            self.statusLabel.text = message
            guard let openURL else {
                self.extensionContext?.completeRequest(returningItems: nil)
                return
            }

            self.extensionContext?.open(openURL) { didOpen in
                DispatchQueue.main.async {
                    if didOpen {
                        self.statusLabel.text = "Opening Radix..."
                    }
                    self.extensionContext?.completeRequest(returningItems: nil)
                }
            }
        }
    }
}

private struct SendableItemProvider: @unchecked Sendable {
    let provider: NSItemProvider

    init(_ provider: NSItemProvider) {
        self.provider = provider
    }
}
