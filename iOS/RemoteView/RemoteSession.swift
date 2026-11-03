import Foundation
import Combine
import UIKit

@MainActor
final class RemoteSession: ObservableObject {
    enum RemoteAction {
        case tap
        case swipe
    }

    @Published private(set) var isConnected = false
    @Published private(set) var isStreaming = false
    @Published private(set) var pairingCode: String?
    @Published private(set) var statusText = "Disconnected"
    @Published private(set) var lastError: String?

    let remoteActionPublisher = PassthroughSubject<RemoteAction, Never>()

    private let socket = WebSocketClient()
    private let streamer = ScreenStreamer()

    init() {
        socket.onEvent = { [weak self] event in
            Task { @MainActor in
                self?.handle(event)
            }
        }
        socket.onBinary = { _ in }
        streamer.onJPEG = { [weak self] data in
            self?.socket.sendBinary(data)
        }
        streamer.onStateChange = { [weak self] streaming in
            Task { @MainActor in
                self?.isStreaming = streaming
            }
        }
        streamer.onError = { [weak self] message in
            Task { @MainActor in
                self?.lastError = message
            }
        }
    }

    func connect(to string: String) {
        lastError = nil
        guard let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            lastError = "Invalid WebSocket URL."
            return
        }
        statusText = "Connecting…"
        socket.connect(url: url)
    }

    func disconnect() {
        stopStreaming()
        socket.disconnect()
        isConnected = false
        pairingCode = nil
        statusText = "Disconnected"
    }

    func startStreaming() async {
        streamer.requestSharing()
    }

    func stopStreaming() {
        streamer.stop()
    }

    private func handle(_ event: WebSocketClient.Event) {
        switch event {
        case .connected:
            isConnected = true
            statusText = "Connected"
            socket.sendJSON(["type": "hello", "role": "device", "name": UIDevice.current.name])
        case .disconnected(let reason):
            isConnected = false
            statusText = "Disconnected"
            if let reason { lastError = reason }
        case .json(let payload):
            guard let type = payload["type"] as? String else { return }
            if type == "welcome" {
                pairingCode = payload["pairingCode"] as? String
            } else if type == "command",
                      let command = payload["command"] as? [String: Any],
                      let name = command["name"] as? String {
                if name == "tap" { remoteActionPublisher.send(.tap) }
                if name == "swipe" { remoteActionPublisher.send(.swipe) }
            }
        case .binary:
            break
        }
    }
}
