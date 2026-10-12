import SwiftUI
import ReplayKit

@main
struct JeuxDeLumiereApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

/// Receives the extension's Darwin notifications and publishes them to the UI.
final class Listener: ObservableObject {
    static let shared = Listener()
    @Published var broadcasting = false
    @Published var level = 0              // 0…9
    @Published var beats = 0
    @Published var lastSignal = Date.distantPast

    private init() {
        observe(Signal.started) { $0.broadcasting = true }
        observe(Signal.stopped) { $0.broadcasting = false; $0.level = 0 }
        observe(Signal.beat) { $0.beats += 1 }
        for n in 0...9 { observe(Signal.level(n)) { $0.level = n } }
    }

    private var handlers: [String: (Listener) -> Void] = [:]

    private func observe(_ name: String, _ handler: @escaping (Listener) -> Void) {
        handlers[name] = handler
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, name, _, _ in
                guard let observer, let name else { return }
                let me = Unmanaged<Listener>.fromOpaque(observer).takeUnretainedValue()
                let key = name.rawValue as String
                DispatchQueue.main.async {
                    me.lastSignal = Date()
                    if key != Signal.stopped { me.broadcasting = true }
                    me.handlers[key]?(me)
                }
            },
            name as CFString, nil, .deliverImmediately)
    }
}

/// The system "start broadcast" button, preset to our extension.
struct BroadcastButton: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let v = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 72, height: 72))
        v.preferredExtension = "fr.jeuxdelumiere.app.broadcast"
        v.showsMicrophoneButton = false
        return v
    }
    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}

struct ContentView: View {
    @ObservedObject private var l = Listener.shared
    @State private var flash = 0.0
    private let tick = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    @State private var now = Date()

    private var receiving: Bool { now.timeIntervalSince(l.lastSignal) < 2 && l.level > 0 }

    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.02, blue: 0.06).ignoresSafeArea()
            // the whole screen pulses on each beat: the quickest way to see the sync with the music
            Color(hue: Double(l.beats % 12) / 12, saturation: 0.9, brightness: 1)
                .opacity(flash * 0.55).ignoresSafeArea()
            VStack(spacing: 22) {
                Text("Jeux de lumière").font(.system(size: 30, weight: .bold))
                Text("Prototype : vérifier que le son de Spotify ou Deezer arrive dans l’app")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Touchez le bouton rond ci-dessous, puis « Commencer la diffusion ».")
                    Text("2. Ouvrez Spotify ou Deezer et lancez une musique.")
                    Text("3. Revenez ici : le niveau et les flashs doivent suivre la musique.")
                }
                .font(.callout)

                BroadcastButton().frame(width: 72, height: 72)
                    .background(Circle().fill(Color.white.opacity(0.08)))

                // level meter
                HStack(spacing: 6) {
                    ForEach(0..<9) { i in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(i < l.level ? Color(hue: 0.33 - Double(i) * 0.04, saturation: 0.9, brightness: 1) : Color.white.opacity(0.1))
                            .frame(width: 22, height: 14 + CGFloat(i) * 6)
                    }
                }
                .frame(height: 70, alignment: .bottom)
                .animation(.easeOut(duration: 0.08), value: l.level)

                Group {
                    if receiving {
                        Label("Son reçu : ça marche ! \(l.beats) battements détectés", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if l.broadcasting {
                        Label("Diffusion en cours, mais aucun son reçu. Lancez une musique ; si rien ne bouge, cette app de musique bloque la capture.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                    } else {
                        Label("Diffusion arrêtée", systemImage: "circle")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.callout).multilineTextAlignment(.center)
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
        .onReceive(tick) { now = $0 }
        .onChange(of: l.beats) { _ in
            flash = 1
            withAnimation(.easeOut(duration: 0.35)) { flash = 0 }
        }
    }
}
