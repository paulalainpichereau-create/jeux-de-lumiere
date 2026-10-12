import Foundation

/// Darwin notification names shared by the app and the broadcast extension.
/// A Darwin notification carries no data, so the level is encoded in the name (level.0 … level.9).
enum Signal {
    static let prefix = "fr.jeuxdelumiere."
    static let started = prefix + "started"
    static let stopped = prefix + "stopped"
    static let beat = prefix + "beat"
    static func level(_ n: Int) -> String { prefix + "level.\(n)" }

    static func post(_ name: String) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(name as CFString), nil, nil, true)
    }
}
