import Foundation
import ScreenCaptureKit
import CoreImage
import ImageIO
import CoreMedia

final class ScreenStreamer: NSObject, SCStreamOutput, SCStreamDelegate, SCContentSharingPickerObserver {
    var onJPEG: ((Data) -> Void)?
    var onStateChange: ((Bool) -> Void)?
    var onError: ((String) -> Void)?

    private var stream: SCStream?
    private let picker = SCContentSharingPicker.shared
    private let queue = DispatchQueue(label: "RemoteView.ScreenStreamer", qos: .userInitiated)
    private let context = CIContext()
    private var lastSent = Date.distantPast
    private let minimumFrameInterval: TimeInterval = 1.0 / 8.0

    override init() {
        super.init()
        picker.add(self)
        picker.active = true
    }

    deinit { picker.remove(self) }

    func requestSharing() {
        picker.active = true
        picker.present(using: .display)
    }

    func stop() {
        guard let stream else {
            onStateChange?(false)
            return
        }
        self.stream = nil
        stream.stopCapture { [weak self] _ in self?.onStateChange?(false) }
    }

    private func makeStream(for filter: SCContentFilter) async {
        do {
            if let existing = stream {
                self.stream = nil
                try await existing.stopCapture()
            }

            let configuration = SCStreamConfiguration()
            configuration.width = 960
            configuration.height = 2079
            configuration.minimumFrameInterval = CMTime(value: 1, timescale: 8)
            configuration.queueDepth = 3
            configuration.pixelFormat = kCVPixelFormatType_32BGRA
            configuration.showsCursor = false
            configuration.capturesAudio = false

            let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
            self.stream = stream
            try await stream.startCapture()
            onStateChange?(true)
        } catch {
            self.stream = nil
            onStateChange?(false)
            onError?(error.localizedDescription)
        }
    }

    func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        if let stream {
            stream.updateContentFilter(filter) { [weak self] error in
                if let error { self?.onError?(error.localizedDescription) }
            }
        } else {
            Task { [weak self] in await self?.makeStream(for: filter) }
        }
    }

    func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        if stream == nil { onStateChange?(false) }
    }

    func contentSharingPickerStartDidFailWithError(_ error: Error) {
        onStateChange?(false)
        onError?(error.localizedDescription)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        self.stream = nil
        onStateChange?(false)
        onError?(error.localizedDescription)
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
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
