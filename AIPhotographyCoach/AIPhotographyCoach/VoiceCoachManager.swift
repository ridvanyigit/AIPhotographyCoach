import Foundation
import AVFoundation

@Observable
class VoiceCoachManager: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var isSpeaking = false
    private var lastSpokenPhrase = ""
    private var lastSpeakTime = Date.distantPast

    override init() {
        super.init()
        synthesizer.delegate = self
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        lastSpokenPhrase = ""
    }

    // `lightingHint` is only consulted once the pose itself is `.perfect` — no point
    // telling someone to fix their lighting while they're still framing their face.
    func provideGuidance(poseState: SelfieState, lightingHint: String?) {
        // Don't interrupt an in-progress utterance, and rate-limit to avoid spamming
        guard !isSpeaking else { return }
        let now = Date()
        guard now.timeIntervalSince(lastSpeakTime) > 2.0 else { return }

        let phraseToSpeak: String

        switch poseState {
        case .searching:
            return // Don't nag the user while we're still looking for a face
        case .fitIntoMask:
            phraseToSpeak = "Center your face in the frame."
        case .eyesClosed:
            phraseToSpeak = "Open your eyes."
        case .good, .veryGood:
            return // Getting close — stay quiet and let the visual guide do the work
        case .perfect:
            phraseToSpeak = lightingHint ?? "Perfect!"
        }

        // Never repeat the exact same phrase back to back
        guard phraseToSpeak != lastSpokenPhrase else { return }

        speak(phraseToSpeak)
    }

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.05

        lastSpokenPhrase = text
        lastSpeakTime = Date()
        synthesizer.speak(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        isSpeaking = true
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
        // Clear the last phrase after a few seconds so a persisting state can be
        // gently repeated instead of going silent forever
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.lastSpokenPhrase = ""
        }
    }
}
