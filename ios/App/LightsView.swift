import SwiftUI
import WebKit

/// The lights themselves: the web app (GitHub Pages) in a full-screen web view, with the microphone allowed
/// and the screen kept on. While the iPhone is broadcasting (Spotify captured without the microphone), it
/// opens as a screen on our own code, so this phone shows the lights of the music it is playing, as the TV does.
struct LightsView: View {
    @ObservedObject private var b = Bridge.shared
    @AppStorage("screenCode") private var screenCode = ""

    static let home = "https://paulalainpichereau-create.github.io/jeux-de-lumiere/"

    private var url: URL {
        if b.broadcasting && screenCode.count == Signal.codeLength {
            return URL(string: Self.home + "?ecran=" + screenCode + "&app=ios")!
        }
        return URL(string: Self.home + "?app=ios")!
    }

    var body: some View {
        WebLights(url: url)
            .id(url)                       // a new page when we switch between "microphone" and "Spotify"
            .ignoresSafeArea(edges: [.top, .horizontal])
            .background(Color.black)
            .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = b.broadcasting }
    }
}

struct WebLights: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.applicationNameForUserAgent = "JeuxDeLumiereApp/iOS"
        let web = WKWebView(frame: .zero, configuration: cfg)
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.backgroundColor = .black
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.scrollView.bounces = false
        web.uiDelegate = context.coordinator
        web.navigationDelegate = context.coordinator
        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate {
        // the microphone: iOS asks the person once (NSMicrophoneUsageDescription), then the page may use it
        @available(iOS 15.0, *)
        func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                     initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                     decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            decisionHandler(origin.host == "paulalainpichereau-create.github.io" && type == .microphone ? .grant : .deny)
        }

        // links leaving the app (GitHub, help…) open in Safari
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let u = action.request.url, let host = u.host, host != "paulalainpichereau-create.github.io",
               action.navigationType == .linkActivated || action.targetFrame == nil {
                UIApplication.shared.open(u)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        // first launch without internet: a short message instead of a blank page
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let html = """
            <html><head><meta name='viewport' content='width=device-width,initial-scale=1'></head>
            <body style='margin:0;min-height:100vh;display:grid;place-items:center;background:#07060e;color:#efeaff;font:17px -apple-system,sans-serif;text-align:center;padding:24px'>
            <div><h2>Pas de connexion internet</h2><p style='color:#a9a2c4'>Au premier lancement, les lumières ont besoin d’internet pour se charger. Ensuite, elles marchent aussi sans réseau.</p>
            <a style='display:inline-block;margin-top:14px;padding:12px 22px;border-radius:10px;background:#ff4d94;color:#14060d;font-weight:600;text-decoration:none' href='\(LightsView.home)?app=ios'>Réessayer</a></div></body></html>
            """
            webView.loadHTMLString(html, baseURL: nil)
        }
    }
}
