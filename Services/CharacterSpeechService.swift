import Foundation

#if canImport(AVFoundation)
import AVFoundation

@MainActor
final class CharacterSpeechService {
    private let synthesizer = AVSpeechSynthesizer()
    private var cachedVoice: AVSpeechSynthesisVoice?
    private var hasPreparedAudioSession = false

    func prepareForFirstUtterance() {
        configureAudioSessionIfNeeded()
        cachedVoice = preferredVoice()
    }

    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        configureAudioSessionIfNeeded()
        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = cachedVoice ?? preferredVoice()
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.prefersAssistiveTechnologySettings = true
        synthesizer.speak(utterance)
    }

    private func configureAudioSessionIfNeeded() {
        guard !hasPreparedAudioSession else { return }
        #if !targetEnvironment(macCatalyst)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        hasPreparedAudioSession = true
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
        if let cachedVoice { return cachedVoice }
        for language in ["zh-CN", "zh-TW", "zh-HK"] {
            if let voice = AVSpeechSynthesisVoice(language: language) {
                cachedVoice = voice
                return voice
            }
        }

        let fallback = AVSpeechSynthesisVoice(language: Locale.preferredLanguages.first ?? Locale.current.identifier)
        cachedVoice = fallback
        return fallback
    }
}
#else
@MainActor
final class CharacterSpeechService {
    func prepareForFirstUtterance() { }

    func speak(_ text: String) { }

    func speakPhrase(_ phrase: PhraseItem) { }

    @discardableResult
    func speakCharacters(in text: String) -> Int {
        let characters = CaptureTextExtractor.allCharactersInOrder(in: text)
        return characters.count
    }
}
#endif
