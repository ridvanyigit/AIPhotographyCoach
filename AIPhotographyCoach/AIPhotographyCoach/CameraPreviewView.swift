import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        // Nothing to do here for now — SwiftUI-driven updates aren't needed yet.
    }
}

// Thin UIView subclass needed to host Apple's native camera preview layer
class VideoPreviewView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }

    // Runs automatically whenever the screen rotates or the view resizes
    override func layoutSubviews() {
        super.layoutSubviews()

        // Bail out if the preview layer's connection doesn't support orientation changes
        guard let connection = videoPreviewLayer.connection, connection.isVideoOrientationSupported else { return }

        // Match the camera connection's orientation to the current window scene orientation
        if let windowScene = window?.windowScene {
            switch windowScene.interfaceOrientation {
            case .portrait:
                connection.videoOrientation = .portrait
            case .landscapeLeft:
                connection.videoOrientation = .landscapeLeft
            case .landscapeRight:
                connection.videoOrientation = .landscapeRight
            case .portraitUpsideDown:
                connection.videoOrientation = .portraitUpsideDown
            default:
                connection.videoOrientation = .portrait
            }
        }
    }
}
