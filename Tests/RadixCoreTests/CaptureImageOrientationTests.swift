import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import RadixCore

@Suite("Capture image orientation")
struct CaptureImageOrientationTests {
    @Test("EXIF metadata preserves all eight image orientations")
    func preservesEveryExifOrientation() throws {
        for rawValue in UInt32(1)...8 {
            let data = try imageData(orientationRawValue: rawValue)
            #expect(CaptureImageOrientationMetadata.orientation(in: data).rawValue == rawValue)
        }

        let dataWithoutOrientation = try imageData(orientationRawValue: nil)
        #expect(CaptureImageOrientationMetadata.orientation(in: dataWithoutOrientation) == .up)
        #expect(CaptureImageOrientationMetadata.orientation(in: Data()) == .up)
    }

    @Test("Image resource budget rejects oversized inputs and bounds recognition dimensions")
    func enforcesImageResourceBudget() {
        #expect(CaptureImageResourceBudget.violation(
            encodedByteCount: CaptureImageResourceBudget.maximumEncodedByteCount,
            pixelWidth: 8_000,
            pixelHeight: 8_000
        ) == nil)
        #expect(CaptureImageResourceBudget.violation(
            encodedByteCount: CaptureImageResourceBudget.maximumEncodedByteCount + 1,
            pixelWidth: 1,
            pixelHeight: 1
        ) == .encodedBytes)
        #expect(CaptureImageResourceBudget.violation(
            encodedByteCount: 1,
            pixelWidth: 8_001,
            pixelHeight: 8_000
        ) == .pixels)
        #expect(!CaptureImageResourceBudget.requiresDownsampling(
            pixelWidth: CaptureImageResourceBudget.maximumRecognitionDimension,
            pixelHeight: 1
        ))
        #expect(CaptureImageResourceBudget.requiresDownsampling(
            pixelWidth: CaptureImageResourceBudget.maximumRecognitionDimension + 1,
            pixelHeight: 1
        ))
    }

    private func imageData(orientationRawValue: UInt32) throws -> Data {
        try imageData(orientationRawValue: Optional(orientationRawValue))
    }

    private func imageData(orientationRawValue: UInt32?) throws -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try #require(CGContext(
            data: nil,
            width: 2,
            height: 3,
            bitsPerComponent: 8,
            bytesPerRow: 8,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(
            data,
            "public.jpeg" as CFString,
            1,
            nil
        ))
        let properties = orientationRawValue.map { [kCGImagePropertyOrientation: $0] as CFDictionary }
        CGImageDestinationAddImage(destination, image, properties)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }
}
