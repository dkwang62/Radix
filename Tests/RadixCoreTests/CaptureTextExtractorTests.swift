import Testing
@testable import RadixCore

@Suite("Capture text extraction")
struct CaptureTextExtractorTests {
    @Test("Extraction includes CJK extension ideographs in reading order")
    func extractsUnicodeIdeographs() {
        let characters = CaptureTextExtractor.allCharactersInOrder(in: "㐀𠮷𰻞你好 A")

        #expect(characters == ["㐀", "𠮷", "𰻞", "你", "好"])
    }

    @Test("Validation separates dictionary coverage without discarding characters")
    func reportsDictionaryCoverage() {
        let validation = CaptureTextExtractor.characterValidation(
            in: "㐀𠮷𰻞你好你",
            dictionaryContains: { ["你", "好"].contains($0) }
        )

        #expect(validation.charactersInReadingOrder == ["㐀", "𠮷", "𰻞", "你", "好", "你"])
        #expect(validation.uniqueCharacters == ["㐀", "𠮷", "𰻞", "你", "好"])
        #expect(validation.dictionarySupportedCharacters == ["你", "好"])
        #expect(validation.dictionaryUnsupportedCharacters == ["㐀", "𠮷", "𰻞"])
        #expect(validation.hasChineseCharacters)
    }

    @Test("Local OCR distinguishes empty, non-Chinese, Chinese, and failure outcomes")
    func classifiesLocalOCROutcomes() {
        #expect(CaptureLocalOCRClassifier.classify(" \n ") == .noText)
        #expect(CaptureLocalOCRClassifier.classify("Invoice total: 42") == .nonChineseText("Invoice total: 42"))
        #expect(CaptureLocalOCRClassifier.classify("Invoice 中文") == .recognized("Invoice 中文"))

        let failure = CaptureLocalOCRResult.failed("Vision unavailable")
        #expect(failure.userMessage == "Apple Vision could not process this image: Vision unavailable")
        #expect(CaptureLocalOCRResult.noText.userMessage != CaptureLocalOCRResult.nonChineseText("English").userMessage)
    }
}
