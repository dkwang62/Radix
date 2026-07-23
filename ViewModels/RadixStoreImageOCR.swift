import Foundation

struct CaptureImageRecognitionResult {
    let text: String
    let usedAIFallback: Bool
}

extension RadixStore {
    func recognizeImageTextWithAIFallback(in image: CapturedImage) async throws -> CaptureImageRecognitionResult {
        do {
            let visionText = try await CaptureOCRService().recognizeText(in: image)
            if !CaptureTextExtractor.allCharactersInOrder(in: visionText).isEmpty {
                return CaptureImageRecognitionResult(text: visionText, usedAIFallback: false)
            }
        } catch {
            // Fall through to AI OCR. If AI also fails, the AI error tells the user what to fix.
        }

        let imageData = CaptureImageThumbnailer.makeJPEGData(from: image, maxDimension: 2200) ?? image.data
        let aiText = try await GeminiImageOCRService().recognizeChineseText(
            apiKey: geminiAPIKey,
            modelID: geminiModelID,
            imageJPEGData: imageData
        )
        return CaptureImageRecognitionResult(text: aiText, usedAIFallback: true)
    }
}
