import Foundation
import AVFoundation

@Observable
class VoiceCoachManager: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var isSpeaking = false
    private var lastSpokenPhrase = ""
    
    override init() {
        super.init()
        synthesizer.delegate = self
        
        // Audio session setup so it plays nicely with the system
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    func provideGuidance(framing: FramingAdvice, tilt: GuidanceState) {
        var phraseToSpeak = ""
        
        // 1. Priority: Framing (Positioning the subject)
        if framing != .perfect && framing != .searching {
            phraseToSpeak = textForFraming(framing)
        }
        // 2. Priority: Tilt (Leveling the camera)
        else if tilt != .aligned && tilt != .unknown {
            phraseToSpeak = textForTilt(tilt)
        }
        // 3. Perfect condition
        else if framing == .perfect && tilt == .aligned {
            phraseToSpeak = "Perfect. Hold still."
        }
        
        guard !phraseToSpeak.isEmpty else { return }
        
        // Prevent spamming
        guard !isSpeaking else { return }
        guard phraseToSpeak != lastSpokenPhrase else { return }
        
        speak(phraseToSpeak)
    }
    
    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US") // English native voice
        utterance.rate = 0.5 // Natural speaking speed
        utterance.pitchMultiplier = 1.1 // Slightly friendlier tone
        
        lastSpokenPhrase = text
        synthesizer.speak(utterance)
    }
    
    // Convert Enums to English Sentences
    private func textForFraming(_ advice: FramingAdvice) -> String {
        switch advice {
        case .moveCloser: return "Move a bit closer."
        case .moveBack: return "Step back."
        case .turnCameraLeft: return "Turn camera left."
        case .turnCameraRight: return "Turn camera right."
        default: return ""
        }
    }
    
    private func textForTilt(_ tilt: GuidanceState) -> String {
        switch tilt {
        case .tiltLeft: return "Tilt phone left."
        case .tiltRight: return "Tilt phone right."
        default: return ""
        }
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        isSpeaking = true
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // 2.0 seconds cooldown after finishing a sentence so it doesn't talk non-stop
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isSpeaking = false
            // Reset last spoken phrase after 4 seconds so it can remind the user again if needed
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.lastSpokenPhrase = ""
            }
        }
    }
}
