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
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    func provideGuidance(framing: FramingAdvice, roll: RollState, pitch: PitchState) {
        var phraseToSpeak = ""
        
        // Priority 1: Framing (Subject position)
        if framing != .perfect && framing != .searching {
            phraseToSpeak = textForFraming(framing)
        } 
        // Priority 2: Roll (Left/Right Leveling)
        else if roll != .aligned && roll != .unknown {
            phraseToSpeak = textForRoll(roll)
        }
        // Priority 3: Pitch (Up/Down Leveling)
        else if pitch != .aligned && pitch != .unknown {
            phraseToSpeak = textForPitch(pitch)
        }
        // Priority 4: All Perfect
        else if framing == .perfect && roll == .aligned && pitch == .aligned {
            phraseToSpeak = "Perfect. Hold still."
        }
        
        guard !phraseToSpeak.isEmpty else { return }
        guard !isSpeaking else { return }
        guard phraseToSpeak != lastSpokenPhrase else { return } 
        
        speak(phraseToSpeak)
    }
    
    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.1
        
        lastSpokenPhrase = text
        synthesizer.speak(utterance)
    }
    
    private func textForFraming(_ advice: FramingAdvice) -> String {
        switch advice {
        case .moveCloser: return "Move a bit closer."
        case .moveBack: return "Step back."
        case .turnCameraLeft: return "Turn camera left."
        case .turnCameraRight: return "Turn camera right."
        default: return ""
        }
    }
    
    private func textForRoll(_ roll: RollState) -> String {
        switch roll {
        case .tiltLeft: return "Tilt phone left."
        case .tiltRight: return "Tilt phone right."
        default: return ""
        }
    }
    
    private func textForPitch(_ pitch: PitchState) -> String {
        switch pitch {
        case .tiltUp: return "Tilt phone up."
        case .tiltDown: return "Tilt phone down."
        default: return ""
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        isSpeaking = true
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isSpeaking = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.lastSpokenPhrase = ""
            }
        }
    }
}