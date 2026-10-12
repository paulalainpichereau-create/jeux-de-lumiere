import Foundation
import GoogleCast
import SwiftUI

/// Google Cast: starts our receiver page on the Chromecast (the web app with ?cast=1) and tells it which
/// screen code to follow. The music analysis itself goes from the broadcast extension through the relay,
/// so it keeps flowing while this app sits in the background behind Spotify.
final class CastLink: NSObject, ObservableObject, GCKSessionManagerListener {
    static let shared = CastLink()
    static let namespace = "urn:x-cast:fr.jeuxdelumiere"
    /// The receiver's application ID, set at build time from the repository variable CAST_APP_ID.
    static let appID: String = (Bundle.main.object(forInfoDictionaryKey: "JDLCastAppID") as? String) ?? ""
    /// CC1AD845 is Google's default media player: casting works but cannot show our lights.
    static var configured: Bool { !appID.isEmpty && appID != "CC1AD845" && !appID.contains("$") }

    @Published var deviceName: String?      // set while connected to a Chromecast
    private var channel: GCKGenericChannel?
    private var resend: Timer?
    var code: () -> String = { "" }

    static func setUp() {
        let criteria = GCKDiscoveryCriteria(applicationID: configured ? appID : kGCKDefaultMediaReceiverApplicationID)
        let options = GCKCastOptions(discoveryCriteria: criteria)
        options.stopReceiverApplicationWhenEndingSession = true
        GCKCastContext.setSharedInstanceWith(options)
        GCKCastContext.sharedInstance().sessionManager.add(shared)
    }

    /// Sends the screen code (again a few times, in case the receiver page is still loading).
    func sendCode() {
        let c = code()
        guard c.count == Signal.codeLength, let channel else { return }
        channel.sendTextMessage("{\"t\":\"code\",\"code\":\"\(c)\"}", error: nil)
    }

    private func attach(_ session: GCKCastSession) {
        let ch = GCKGenericChannel(namespace: Self.namespace)
        session.add(ch)
        channel = ch
        deviceName = session.device.friendlyName ?? "Chromecast"
        resend?.invalidate()
        var count = 0
        resend = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] t in
            self?.sendCode()
            count += 1
            if count >= 8 { t.invalidate() }
        }
    }

    private func detach() {
        resend?.invalidate(); resend = nil
        channel = nil
        deviceName = nil
    }

    func sessionManager(_ sessionManager: GCKSessionManager, didStart session: GCKCastSession) { attach(session) }
    func sessionManager(_ sessionManager: GCKSessionManager, didResumeCastSession session: GCKCastSession) { attach(session) }
    func sessionManager(_ sessionManager: GCKSessionManager, didEnd session: GCKCastSession, withError error: Error?) { detach() }
    func sessionManager(_ sessionManager: GCKSessionManager, didFailToStart session: GCKCastSession, withError error: Error) { detach() }
}

/// The standard Cast button.
struct CastButton: UIViewRepresentable {
    func makeUIView(context: Context) -> GCKUICastButton {
        let b = GCKUICastButton(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        b.tintColor = .white
        return b
    }
    func updateUIView(_ uiView: GCKUICastButton, context: Context) {}
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        CastLink.setUp()
        return true
    }
}
