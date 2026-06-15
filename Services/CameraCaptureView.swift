import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit

struct CameraCaptureView: UIViewControllerRepresentable {
    let onImage: (CapturedImage) -> Void
    var onError: (Error) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, onError: onError, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onImage: (CapturedImage) -> Void
        private let onError: (Error) -> Void
        private let dismiss: DismissAction

        init(
            onImage: @escaping (CapturedImage) -> Void,
            onError: @escaping (Error) -> Void,
            dismiss: DismissAction
        ) {
            self.onImage = onImage
            self.onError = onError
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                do {
                    onImage(try CapturedImage(image: image))
                } catch {
                    onError(error)
                }
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
#else
struct CameraCaptureView: View {
    let onImage: (CapturedImage) -> Void
    var onError: (Error) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Text("Camera capture is unavailable on this platform.")
            .padding()
            .task {
                onError(NSError(
                    domain: "Radix",
                    code: 3003,
                    userInfo: [NSLocalizedDescriptionKey: "Camera capture is unavailable on this platform."]
                ))
                dismiss()
            }
    }
}
#endif
