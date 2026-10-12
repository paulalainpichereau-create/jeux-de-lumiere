import Foundation

/// Minimal MQTT 3.1.1 client over a secure WebSocket: CONNECT, QoS 0 PUBLISH, PINGREQ, DISCONNECT.
/// Kept tiny on purpose: a broadcast extension has very little memory. Reconnects by itself.
final class MQTTLink: NSObject, URLSessionWebSocketDelegate {
    /// Public relay shared with the web app (see MQ_URL in index.html).
    static let url = URL(string: "wss://broker.emqx.io:8084/mqtt")!

    private let q = DispatchQueue(label: "fr.jeuxdelumiere.mqtt")
    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    private var task: URLSessionWebSocketTask?
    private var topic = ""
    private var ready = false
    private var closed = true
    private var retryDelay: TimeInterval = 1
    private var pingTimer: DispatchSourceTimer?
    private let clientId = "jdl-ios-" + String((0..<8).map { _ in Signal.codeAlphabet.randomElement()! }).lowercased()

    /// Called on the link's queue with true when connected to the relay, false when lost.
    var onState: ((Bool) -> Void)?

    func open(code: String) {
        q.async {
            self.topic = "jeux-de-lumiere/v1/" + code
            self.closed = false
            self.connect()
        }
    }

    func close() {
        q.async {
            self.closed = true
            self.pingTimer?.cancel(); self.pingTimer = nil
            if self.ready { self.task?.send(.data(Data([0xE0, 0x00]))) { _ in } }
            self.ready = false
            self.task?.cancel(with: .normalClosure, reason: nil)
            self.task = nil
        }
    }

    /// Fire-and-forget; frames are dropped while the link is down (the next one replaces them anyway).
    func publish(_ payload: Data) {
        q.async {
            guard self.ready, let task = self.task else { return }
            task.send(.data(Self.publishPacket(topic: self.topic, payload: payload))) { _ in }
        }
    }

    // MARK: - connection

    private func connect() {
        guard !closed else { return }
        let t = session.webSocketTask(with: Self.url, protocols: ["mqtt"])
        task = t
        t.resume()
        t.send(.data(Self.connectPacket(clientId: clientId))) { [weak self] error in
            if error != nil { self?.q.async { self?.fail(t) } }
        }
        receive(t)
    }

    private func receive(_ t: URLSessionWebSocketTask) {
        t.receive { [weak self] result in
            guard let self else { return }
            self.q.async {
                guard self.task === t else { return }
                switch result {
                case .failure:
                    self.fail(t)
                case .success(let message):
                    if case .data(let d) = message, d.count >= 4, d[0] == 0x20 {   // CONNACK
                        if d[3] == 0 { self.up() } else { self.fail(t); return }
                    }
                    self.receive(t)
                }
            }
        }
    }

    private func up() {
        ready = true
        retryDelay = 1
        onState?(true)
        pingTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: q)
        timer.schedule(deadline: .now() + 25, repeating: 25)
        timer.setEventHandler { [weak self] in
            guard let self, self.ready else { return }
            self.task?.send(.data(Data([0xC0, 0x00]))) { _ in }        // PINGREQ (keepalive is 60 s)
        }
        timer.resume()
        pingTimer = timer
    }

    private func fail(_ t: URLSessionWebSocketTask) {
        guard task === t else { return }
        let wasReady = ready
        ready = false
        pingTimer?.cancel(); pingTimer = nil
        t.cancel(with: .goingAway, reason: nil)
        task = nil
        if wasReady { onState?(false) }
        guard !closed else { return }
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, 15)
        q.asyncAfter(deadline: .now() + delay) { [weak self] in self?.connect() }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        q.async { self.fail(webSocketTask) }
    }

    // MARK: - packets (MQTT 3.1.1)

    private static func remainingLength(_ n: Int) -> [UInt8] {
        var x = n, out: [UInt8] = []
        repeat {
            var b = UInt8(x % 128)
            x /= 128
            if x > 0 { b |= 0x80 }
            out.append(b)
        } while x > 0
        return out
    }

    private static func string(_ s: String) -> [UInt8] {
        let u = Array(s.utf8)
        return [UInt8(u.count >> 8), UInt8(u.count & 0xFF)] + u
    }

    static func connectPacket(clientId: String) -> Data {
        let variable: [UInt8] = string("MQTT") + [0x04, 0x02, 0x00, 60]   // level 4, clean session, keepalive 60 s
        let payload = string(clientId)
        return Data([0x10] + remainingLength(variable.count + payload.count) + variable + payload)
    }

    static func publishPacket(topic: String, payload: Data) -> Data {
        let head = string(topic)
        var out = Data([0x30] + remainingLength(head.count + payload.count) + head)
        out.append(payload)
        return out
    }
}
