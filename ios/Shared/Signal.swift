import Foundation

/// Darwin notifications shared by the app and the broadcast extension. They cross process boundaries
/// without an App Group (so the app installs with any Apple ID), but carry no data, so values are
/// encoded in the names themselves: level.0 … level.9, and the screen code one character at a time.
enum Signal {
    static let prefix = "fr.jeuxdelumiere."
    static let started = prefix + "started"
    static let stopped = prefix + "stopped"
    static let beat = prefix + "beat"
    static func level(_ n: Int) -> String { prefix + "level.\(n)" }

    // screen code hand-over: the extension asks, the app spells the code, then commits
    static let codeRequest = prefix + "code.request"
    static func codeChar(_ position: Int, _ char: Character) -> String { prefix + "code.\(position).\(char)" }
    static let codeCommit = prefix + "code.commit"
    static let linkUp = prefix + "link.up"       // the extension reached the relay
    static let linkDown = prefix + "link.down"

    /// Same alphabet as the web app's screen codes (no 0/O, 1/I/L).
    static let codeAlphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
    static let codeLength = 5

    static func post(_ name: String) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(name as CFString), nil, nil, true)
    }
}

/// Darwin-notification listener usable from both processes. Handlers run on the main queue.
final class SignalListener {
    private var handlers: [String: () -> Void] = [:]

    func on(_ name: String, _ handler: @escaping () -> Void) {
        handlers[name] = handler
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, name, _, _ in
                guard let observer, let name else { return }
                let me = Unmanaged<SignalListener>.fromOpaque(observer).takeUnretainedValue()
                let key = name.rawValue as String
                DispatchQueue.main.async { me.handlers[key]?() }
            },
            name as CFString, nil, .deliverImmediately)
    }

    deinit {
        CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(), Unmanaged.passUnretained(self).toOpaque())
    }
}
