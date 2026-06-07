import SwiftUI

struct CaptureFileImportModifier: ViewModifier {
    @Binding var isPresented: Bool

    let onImage: @MainActor @Sendable (CapturedImage) -> Void
    let onError: @MainActor @Sendable (Error) -> Void

    func body(content: Content) -> some View {
        content
            .fileImporter(
                isPresented: $isPresented,
                allowedContentTypes: RadixFileTypes.imageImports,
                allowsMultipleSelection: false
            ) { result in
                do {
                    guard let image = try CaptureImageLoader.capturedImage(from: result.get()) else { return }
                    Task { @MainActor in
                        onImage(image)
                    }
                } catch {
                    Task { @MainActor in
                        onError(error)
                    }
                }
            }
    }
}
