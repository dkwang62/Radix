import Foundation
@preconcurrency import Vision

final class CaptureOCRService {
    func recognizeText(in image: CapturedImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest { request, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    let observations = (request.results as? [VNRecognizedTextObservation] ?? [])
                        .sorted {
                            // Vision boundingBox origin is bottom-left, so higher Y = higher on screen.
                            // Group lines by proximity before sorting left-to-right.
                            let yDiff = abs($0.boundingBox.midY - $1.boundingBox.midY)
                            if yDiff > 0.01 {
                                return $0.boundingBox.midY > $1.boundingBox.midY
                            }
                            return $0.boundingBox.minX < $1.boundingBox.minX
                        }
                    let lines = observations.compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }
                    continuation.resume(returning: lines.joined(separator: "\n"))
                }

                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]

                let handler = VNImageRequestHandler(
                    data: image.data,
                    orientation: image.orientation,
                    options: [:]
                )

                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
