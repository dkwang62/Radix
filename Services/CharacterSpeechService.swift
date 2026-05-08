import AVFoundation
import Foundation

@MainActor
final class CharacterSpeechService {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        #if !targetEnvironment(macCatalyst)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif

        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = preferredVoice()
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.prefersAssistiveTechnologySettings = true
        synthesizer.speak(utterance)
    }

    func speakPhrase(_ phrase: PhraseItem) {
        speak(phrase.word)
    }

    @discardableResult
    func speakCharacters(in text: String) -> Int {
        let characters = CaptureTextExtractor.allCharactersInOrder(in: text)
        guard !characters.isEmpty else { return 0 }
        speak(characters.joined())
        return characters.count
    }

    private func preferredVoice() -> AVSpeechSynthesisVoice? {
        for language in ["zh-CN", "zh-TW", "zh-HK"] {
            if let voice = AVSpeechSynthesisVoice(language: language) {
                return voice
            }
        }

        return AVSpeechSynthesisVoice(language: Locale.preferredLanguages.first ?? Locale.current.identifier)
    }
}
