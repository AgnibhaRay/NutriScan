import AVFoundation
import CoreImage
import UIKit
import SwiftUI

class FrameHandler: NSObject, ObservableObject {
    @Published var frame: CGImage?
    @Published var capturedImage: UIImage?
    
    private var permissionGranted = false
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.nutriscan.sessionQueue")
    private let context = CIContext()
    
    private var isSessionConfigured = false

    override init() {
        super.init()
        checkPermission()
        sessionQueue.async { [weak self] in
             guard let self = self else { return }
             if self.permissionGranted {
                 self.setupCaptureSessionIfNeeded()
                 self.startSession()
             }
         }
    }
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                self.permissionGranted = true
            
            case .notDetermined:
                requestPermission()
            
            default:
                self.permissionGranted = false
        }
    }
    
    func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self = self else { return }
            self.permissionGranted = granted
            if granted {
                self.sessionQueue.async {
                     self.setupCaptureSessionIfNeeded()
                     self.startSession()
                 }
            }
        }
    }
    
    private func setupCaptureSessionIfNeeded() {
         guard permissionGranted, !isSessionConfigured else {
             return
         }
        
         captureSession.beginConfiguration()
        
         captureSession.sessionPreset = .photo

         guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
               let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
               captureSession.canAddInput(videoDeviceInput) else {
             captureSession.commitConfiguration()
             return
         }
         captureSession.addInput(videoDeviceInput)
        
         let videoOutput = AVCaptureVideoDataOutput()
         videoOutput.alwaysDiscardsLateVideoFrames = true
         videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        
         videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.nutriscan.sampleBufferQueue"))
        
         guard captureSession.canAddOutput(videoOutput) else {
             captureSession.commitConfiguration()
             return
         }
         captureSession.addOutput(videoOutput)
        
         videoOutput.connection(with: .video)?.videoRotationAngle = 90
        
         captureSession.commitConfiguration()
         isSessionConfigured = true
    }
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.permissionGranted, self.isSessionConfigured else {
                return
            }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
             guard let self = self else { return }
             if self.captureSession.isRunning {
                 self.captureSession.stopRunning()
             }
         }
    }
    
    func captureCurrentFrame() {
        guard let cgImage = self.frame else {
            return
        }
        
        let uiImage = UIImage(cgImage: cgImage)
        
        DispatchQueue.main.async {
             self.capturedImage = uiImage
         }
        
        DispatchQueue.global(qos: .background).async {
             self.saveImageToDocuments(image: uiImage)
         }
    }
    
    private func saveImageToDocuments(image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            return
        }
        
        let filename = getDocumentsDirectory().appendingPathComponent("\(UUID().uuidString).jpg")
        
        do {
            try data.write(to: filename, options: [.atomic])
        } catch {
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension FrameHandler: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let cgImage = imageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }
        
        DispatchQueue.main.async {
            self.frame = cgImage
        }
    }
    
    private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> CGImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        
        return cgImage
    }
}
