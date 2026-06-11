import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        importSharedImage()
    }

    private func configureView() {
        view.backgroundColor = .systemBackground
        statusLabel.text = "Sending image to Radix..."
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

    private func importSharedImage() {
        guard let provider = firstImageProvider() else {
            finish(message: "No image found.", openRadix: false)
            return
        }

        loadImageData(from: provider)
    }

    private func firstImageProvider() -> NSItemProvider? {
        extensionContext?.inputItems
            .compactMap { $0 as? NSExtensionItem }
            .flatMap { $0.attachments ?? [] }
            .first { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }
    }

    @MainActor
    private func handleLoadedImageData(_ result: Result<Data, Error>) {
        switch result {
        case .failure:
            finish(message: "Unable to read image.", openRadix: false)
        case .success(let data):
            guard let destinationURL = RadixSharedImageImport.makeIncomingImageURL(fileExtension: "jpg") else {
                finish(message: "Unable to access Radix storage.", openRadix: false)
                return
            }

            do {
                try data.write(to: destinationURL, options: [.atomic])
                finish(message: "Opening Radix...", openRadix: true)
            } catch {
                finish(message: "Unable to send image.", openRadix: false)
            }
        }
    }

    private func loadImageData(from provider: NSItemProvider) {
        let typeIdentifier = UTType.image.identifier
        guard provider.hasItemConformingToTypeIdentifier(typeIdentifier) else {
            finish(message: "No image found.", openRadix: false)
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

    private func finish(message: String, openRadix: Bool) {
        DispatchQueue.main.async {
            self.statusLabel.text = message
            guard openRadix else {
                self.extensionContext?.completeRequest(returningItems: nil)
                return
            }

            self.extensionContext?.open(RadixSharedImageImport.importURL) { didOpen in
                DispatchQueue.main.async {
                    self.statusLabel.text = didOpen ? "Opening Radix..." : "Open Radix to finish import."
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
