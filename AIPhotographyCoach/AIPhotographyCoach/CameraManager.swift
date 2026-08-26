import Foundation
import AVFoundation
import SwiftUI
import CoreMedia
import CoreImage
import ImageIO
import UIKit

@Observable
class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    var isAuthorized: Bool = false
    let session = AVCaptureSession()
    var onFrameAvailable: ((CVPixelBuffer) -> Void)?
    var onPhotoCaptured: ((UIImage) -> Void)?
    
    var currentBrightness: Double = 0.0
    var currentPosition: AVCaptureDevice.Position = .back
    
    var selectedFilter: String = "Original"
    // YENİ: Aktif Portre Işığı Modu
    var portraitLighting: PortraitLightingMode = .natural
    var isPortraitActive: Bool = false
    
    private var isMultiCam: Bool = false
    private var baseZoomFactor: CGFloat = 1.0
    
    private let sessionQueue = DispatchQueue(label: "com.ridvanyigit.CameraSessionQueue")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private let ciContext = CIContext()
    
    func checkPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized: isAuthorized = true; setupCamera()
        case .notDetermined: requestPermission()
        default: isAuthorized = false
        }
    }
    
    private func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if granted { self?.setupCamera() }
            }
        }
    }
    
    private func getBestCamera(for position: AVCaptureDevice.Position) -> (device: AVCaptureDevice?, isMulti: Bool) {
        if position == .front {
            return (AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front), false)
        }
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: position
        )
        
        if let triple = discoverySession.devices.first(where: { $0.deviceType == .builtInTripleCamera }) {
            return (triple, true)
        }
        if let dualWide = discoverySession.devices.first(where: { $0.deviceType == .builtInDualWideCamera }) {
            return (dualWide, true)
        }
        if let wide = discoverySession.devices.first(where: { $0.deviceType == .builtInWideAngleCamera }) {
            return (wide, false)
        }
        return (AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position), false)
    }
    
    private func setupCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .hd1920x1080
            
            let (videoDevice, isMulti) = self.getBestCamera(for: self.currentPosition)
            self.isMultiCam = isMulti
            
            guard let device = videoDevice,
                  let videoDeviceInput = try? AVCaptureDeviceInput(device: device) else { return }
            
            if self.session.canAddInput(videoDeviceInput) { self.session.addInput(videoDeviceInput) }
            
            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
                let videoQueue = DispatchQueue(label: "com.ridvanyigit.VideoQueue")
                self.videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
            }
            
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
                self.photoOutput.maxPhotoQualityPrioritization = .quality
            }
            
            do {
                try device.lockForConfiguration()
                if self.currentPosition == .front {
                    device.videoZoomFactor = 1.0
                } else if isMulti, let firstSwitch = device.virtualDeviceSwitchOverVideoZoomFactors.first {
                    self.baseZoomFactor = CGFloat(truncating: firstSwitch)
                    device.videoZoomFactor = self.baseZoomFactor
                } else {
                    self.baseZoomFactor = 1.0
                    device.videoZoomFactor = 1.0
                }
                device.unlockForConfiguration()
            } catch {
                print("Initial zoom error: \(error)")
            }
            
            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }
    
    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()
            
            guard let currentInput = self.session.inputs.first as? AVCaptureDeviceInput else { return }
            self.session.removeInput(currentInput)
            
            self.currentPosition = self.currentPosition == .back ? .front : .back
            
            let (videoDevice, isMulti) = self.getBestCamera(for: self.currentPosition)
            self.isMultiCam = isMulti
            
            guard let newDevice = videoDevice,
                  let newInput = try? AVCaptureDeviceInput(device: newDevice) else {
                self.session.commitConfiguration()
                return
            }
            
            if self.session.canAddInput(newInput) { self.session.addInput(newInput) } 
            else { self.session.addInput(currentInput) }
            
            do {
                try newDevice.lockForConfiguration()
                if self.currentPosition == .front {
                    newDevice.videoZoomFactor = 1.0
                } else if isMulti, let firstSwitch = newDevice.virtualDeviceSwitchOverVideoZoomFactors.first {
                    self.baseZoomFactor = CGFloat(truncating: firstSwitch)
                    newDevice.videoZoomFactor = self.baseZoomFactor
                } else {
                    self.baseZoomFactor = 1.0
                    newDevice.videoZoomFactor = 1.0
                }
                newDevice.unlockForConfiguration()
            } catch {
                print("Camera switch zoom error: \(error)")
            }
            
            self.session.commitConfiguration()
        }
    }
    
    func setZoom(_ level: Double) {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let input = self.session.inputs.first as? AVCaptureDeviceInput else { return }
            let device = input.device
            
            if self.currentPosition == .front { return }
            
            do {
                try device.lockForConfiguration()
                let targetFactor: CGFloat
                if self.isMultiCam {
                    if level == 0.5 {
                        targetFactor = device.minAvailableVideoZoomFactor
                    } else {
                        targetFactor = self.baseZoomFactor * CGFloat(level)
                    }
                } else {
                    targetFactor = CGFloat(level)
                }
                
                let clampedZoom = max(device.minAvailableVideoZoomFactor, min(targetFactor, device.maxAvailableVideoZoomFactor))
                device.videoZoomFactor = clampedZoom
                device.unlockForConfiguration()
            } catch {
                print("Zoom configuration error: \(error)")
            }
        }
    }
    
    func focusAndExpose(at point: CGPoint, screenWidth: CGFloat, screenHeight: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard let device = self.getBestCamera(for: self.currentPosition).device else { return }
            
            let focusX = point.y / screenHeight
            let focusY = 1.0 - (point.x / screenWidth)
            let sensorPoint = CGPoint(x: focusX, y: focusY)
            
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = sensorPoint
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                    device.exposurePointOfInterest = sensorPoint
                    device.exposureMode = .autoExpose
                }
                device.unlockForConfiguration()
            } catch {
                print("Focus error: \(error)")
            }
        }
    }
    
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        if let photoConnection = photoOutput.connection(with: .video) {
            photoConnection.videoOrientation = currentVideoOrientation()
            if currentPosition == .front && photoConnection.isVideoMirroringSupported {
                photoConnection.isVideoMirrored = true
            }
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    private func currentVideoOrientation() -> AVCaptureVideoOrientation {
        switch UIDevice.current.orientation {
        case .portrait: return .portrait
        case .landscapeRight: return .landscapeLeft
        case .landscapeLeft: return .landscapeRight
        case .portraitUpsideDown: return .portraitUpsideDown
        default: return .portrait
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), var image = UIImage(data: data) else { return }
        
        // 1. Portre Işığı Efekti Uygula
        if isPortraitActive, let portraitImage = applyPortraitLighting(to: image, mode: portraitLighting) {
            image = portraitImage
        }
        // 2. Filtre Uygula
        else if selectedFilter != "Original", let filteredImage = applyFilter(to: image, filterName: selectedFilter) {
            image = filteredImage
        }
        
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        DispatchQueue.main.async { self.onPhotoCaptured?(image) }
    }
    
    // CoreImage Portre Işık İşleme Motoru
    private func applyPortraitLighting(to image: UIImage, mode: PortraitLightingMode) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return image }
        var output = ciImage
        
        switch mode {
        case .natural:
            break
        case .studio:
            if let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(output, forKey: kCIInputImageKey)
                filter.setValue(1.12, forKey: kCIInputBrightnessKey)
                filter.setValue(1.05, forKey: kCIInputContrastKey)
                output = filter.outputImage ?? output
            }
        case .contour:
            if let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(output, forKey: kCIInputImageKey)
                filter.setValue(1.22, forKey: kCIInputContrastKey)
                filter.setValue(1.1, forKey: kCIInputSaturationKey)
                output = filter.outputImage ?? output
            }
            if let vignette = CIFilter(name: "CIVignette") {
                vignette.setValue(output, forKey: kCIInputImageKey)
                vignette.setValue(1.5, forKey: kCIInputIntensityKey)
                vignette.setValue(2.0, forKey: kCIInputRadiusKey)
                output = vignette.outputImage ?? output
            }
        case .stage:
            if let vignette = CIFilter(name: "CIVignetteEffect") {
                vignette.setValue(output, forKey: kCIInputImageKey)
                vignette.setValue(CIVector(x: ciImage.extent.midX, y: ciImage.extent.midY), forKey: kCIInputCenterKey)
                vignette.setValue(ciImage.extent.width * 0.45, forKey: kCIInputRadiusKey)
                vignette.setValue(1.0, forKey: kCIInputIntensityKey)
                output = vignette.outputImage ?? output
            }
        case .stageMono:
            if let mono = CIFilter(name: "CIPhotoEffectMono") {
                mono.setValue(output, forKey: kCIInputImageKey)
                output = mono.outputImage ?? output
            }
            if let vignette = CIFilter(name: "CIVignetteEffect") {
                vignette.setValue(output, forKey: kCIInputImageKey)
                vignette.setValue(CIVector(x: ciImage.extent.midX, y: ciImage.extent.midY), forKey: kCIInputCenterKey)
                vignette.setValue(ciImage.extent.width * 0.45, forKey: kCIInputRadiusKey)
                vignette.setValue(1.0, forKey: kCIInputIntensityKey)
                output = vignette.outputImage ?? output
            }
        case .highKeyMono:
            if let noir = CIFilter(name: "CIPhotoEffectNoir") {
                noir.setValue(output, forKey: kCIInputImageKey)
                output = noir.outputImage ?? output
            }
            if let boost = CIFilter(name: "CIColorControls") {
                boost.setValue(output, forKey: kCIInputImageKey)
                boost.setValue(1.4, forKey: kCIInputContrastKey)
                boost.setValue(0.1, forKey: kCIInputBrightnessKey)
                output = boost.outputImage ?? output
            }
        }
        
        if let cgImage = ciContext.createCGImage(output, from: output.extent) {
            return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        }
        return image
    }
    
    private func applyFilter(to image: UIImage, filterName: String) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return image }
        var outputCIImage: CIImage = ciImage
        
        switch filterName {
        case "Vivid":
            if let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                filter.setValue(1.35, forKey: kCIInputSaturationKey)
                filter.setValue(1.08, forKey: kCIInputContrastKey)
                outputCIImage = filter.outputImage ?? ciImage
            }
        case "Warm":
            if let filter = CIFilter(name: "CITemperatureAndTint") {
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                filter.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                filter.setValue(CIVector(x: 7600, y: 0), forKey: "inputTargetNeutral")
                outputCIImage = filter.outputImage ?? ciImage
            }
        case "Mono":
            if let filter = CIFilter(name: "CIPhotoEffectMono") {
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                outputCIImage = filter.outputImage ?? ciImage
            }
        case "Noir":
            if let filter = CIFilter(name: "CIPhotoEffectNoir") {
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                outputCIImage = filter.outputImage ?? ciImage
            }
        default:
            break
        }
        
        if let cgImage = ciContext.createCGImage(outputCIImage, from: outputCIImage.extent) {
            return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        }
        return image
    }
    
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) { onFrameAvailable?(pixelBuffer) }
        if let metadata = CMCopyDictionaryOfAttachments(allocator: kCFAllocatorDefault, target: sampleBuffer, attachmentMode: kCMAttachmentMode_ShouldPropagate) as? [String: Any],
           let exifData = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let brightness = exifData[kCGImagePropertyExifBrightnessValue as String] as? Double {
            DispatchQueue.main.async { self.currentBrightness = brightness }
        }
    }
}