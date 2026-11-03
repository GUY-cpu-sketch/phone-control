import Foundation
import ReplayKit
import CoreImage
import ImageIO
import CoreMedia

final class ScreenStreamer: NSObject {
    var onJPEG: ((Data) -> Void)?
    var onStateChange: ((Bool) -> Void)?
    var onError: ((String) -> Void)?

    private let recorder = RPScreenRecorder.shared()
    private let queue = DispatchQueue(label: "RemoteView.ScreenStreamer", qos: .userInitiated)
    private let context = CIContext()
    private var lastSent = Date.distantPast
    private let minimumFrameInterval: TimeInterval = 1.0 / 8.0

    func requestSharing() {
        guard recorder.isAvailable else {
            onError?("Screen capture is not currently available.")
            return
        }

        recorder.startCapture(handler: { [weak self] sampleBuffer, type, error in
            if let error {
                DispatchQueue.main.async { self?.onError?(error.localizedDescription) }
                return
            }
            guard type == .video else { return }
            self?.process(sampleBuffer)
        }, completionHandler: { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.onStateChange?(false)
                    self?.onError?(error.localizedDescription)
                } else {
                    self?.onStateChange?(true)
                }
            }
        })
    }

    func stop() {
        recorder.stopCapture { [weak self] error in
            DispatchQueue.main.async {
                self?.onStateChange?(false)
                if let error { self?.onError?(error.localizedDescription) }
            }
        }
    }

    private func process(_ sampleBuffer: CMSampleBuffer) {
        let now = Date()
        guard now.timeIntervalSince(lastSent) >= minimumFrameInterval else { return }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastSent = now

        let image = CIImage(cvPixelBuffer: imageBuffer)
        guard let jpeg = makeJPEG(from: image) else { return }
        onJPEG?(jpeg)
    }

    private func makeJPEG(from image: CIImage) -> Data? {
        let mutable = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutable, "public.jpeg" as CFString, 1, nil),
              let cgImage = context.createCGImage(image, from: image.extent) else { return nil }

        CGImageDestinationAddImage(destination, cgImage, [
            kCGImageDestinationLossyCompressionQuality: 0.55
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutable as Data
    }
}
