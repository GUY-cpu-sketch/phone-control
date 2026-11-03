import Foundation

final class WebSocketClient {
    enum Event {
        case connected
        case disconnected(String?)
        case json([String: Any])
        case binary(Data)
    }

    var onEvent: ((Event) -> Void)?
    var onBinary: ((Data) -> Void)?

    private var task: URLSessionWebSocketTask?
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        session = URLSession(configuration: configuration)
    }

    func connect(url: URL) {
        disconnect()
        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()
        onEvent?(.connected)
        receiveLoop()
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    func sendJSON(_ json: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: json) else { return }
        send(.string(String(decoding: data, as: UTF8.self)))
    }

    func sendBinary(_ data: Data) {
        send(.data(data))
    }

    private func send(_ message: URLSessionWebSocketTask.Message) {
        task?.send(message) { [weak self] error in
            if let error {
                self?.onEvent?(.disconnected(error.localizedDescription))
            }
        }
    }

    private func receiveLoop() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let string):
                    if let data = string.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        self.onEvent?(.json(json))
                    }
                case .data(let data):
                    self.onBinary?(data)
                    self.onEvent?(.binary(data))
                @unknown default:
                    break
                }
                self.receiveLoop()
            case .failure(let error):
                self.task = nil
                self.onEvent?(.disconnected(error.localizedDescription))
            }
        }
    }
}
