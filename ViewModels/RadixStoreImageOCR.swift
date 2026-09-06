import Foundation

struct CaptureImageRecognitionResult {
    let text: String
    let method: CaptureImageRecognitionMethod

    var usedAIFallback: Bool { method == .gemini }
}

extension RadixStore {
    func recognizeImageTextLocally(in image: CapturedImage) async throws -> CaptureLocalOCRResult {
        do {
            let visionText = try await CaptureOCRService().recognizeText(in: image)
            return CaptureLocalOCRClassifier.classify(visionText)
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            return .failed(error.localizedDescription)
        }
    }

    func recognizeImageTextWithGemini(in image: CapturedImage) async throws -> CaptureImageRecognitionResult {
        let imageData = CaptureImageThumbnailer.makeJPEGData(from: image, maxDimension: 2200) ?? image.data
        let aiText = try await GeminiImageOCRService().recognizeChineseText(
            apiKey: geminiAPIKey,
            modelID: geminiModelID,
            imageJPEGData: imageData
        )
        return CaptureImageRecognitionResult(text: aiText, method: .gemini)
    }
}
