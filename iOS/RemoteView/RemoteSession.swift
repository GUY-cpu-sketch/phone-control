import Foundation
import Combine
import UIKit

@MainActor
final class RemoteSession: ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var pairingCode: String?
    @Published private(set) var statusText = "Disconnected"
    @Published private(set) var lastError: String?

    let browser = BrowserController()
    private let socket = WebSocketClient()
    private var streamTask: Task<Void, Never>?

    init() {
        socket.onEvent = { [weak self] event in
            Task { @MainActor in self?.handle(event) }
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
        streamTask?.cancel()
        streamTask = nil
        socket.disconnect()
        isConnected = false
        pairingCode = nil
        statusText = "Disconnected"
    }

    func startStreaming() {
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if self.isConnected { await self.sendSnapshot() }
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }

    private func sendSnapshot() async {
        await withCheckedContinuation { continuation in
            browser.snapshotJPEG { [weak self] data in
                if let data { self?.socket.sendBinary(data) }
                continuation.resume()
            }
        }
    }

    private func handle(_ event: WebSocketClient.Event) {
        switch event {
        case .connected:
            isConnected = true
            statusText = "Connected"
            socket.sendJSON(["type": "hello", "role": "device", "name": UIDevice.current.name])
            startStreaming()
        case .disconnected(let reason):
            isConnected = false
            statusText = "Disconnected"
            if let reason { lastError = reason }
        case .json(let payload):
            guard let type = payload["type"] as? String else { return }
            if type == "welcome" {
                pairingCode = payload["pairingCode"] as? String
            } else if type == "command", let name = payload["command"] as? String {
                handleCommand(name, payload: payload)
            }
        case .binary:
            break
        }
    }

    private func handleCommand(_ name: String, payload: [String: Any]) {
        switch name {
        case "navigate":
            if let url = payload["url"] as? String { browser.navigate(url) }
        case "back": browser.goBack()
        case "forward": browser.goForward()
        case "reload": browser.reload()
        case "scroll":
            if let delta = payload["deltaY"] as? Double { browser.scroll(deltaY: CGFloat(delta)) }
        case "tap":
            if let x = payload["x"] as? Double, let y = payload["y"] as? Double {
                browser.tap(x: CGFloat(x), y: CGFloat(y))
            }
        case "type":
            if let text = payload["text"] as? String { browser.typeText(text) }
        default: break
        }
        socket.sendJSON(browser.navigationState())
    }
}
