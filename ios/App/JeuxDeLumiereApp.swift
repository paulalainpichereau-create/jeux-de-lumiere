import SwiftUI
import ReplayKit

@main
struct JeuxDeLumiereApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

/// Talks to the broadcast extension through Darwin notifications (see Signal.swift).
final class Bridge: ObservableObject {
    static let shared = Bridge()
    @Published var broadcasting = false
    @Published var linked = false        // the extension reached the relay with our code
    @Published var level = 0             // 0…9
    @Published var beats = 0
    @Published var lastSound = Date.distantPast

    private let signals = SignalListener()

    private init() {
        signals.on(Signal.started) { [weak self] in self?.broadcasting = true; self?.sendCode() }
        signals.on(Signal.codeRequest) { [weak self] in self?.broadcasting = true; self?.sendCode() }
        signals.on(Signal.stopped) { [weak self] in self?.broadcasting = false; self?.linked = false; self?.level = 0 }
        signals.on(Signal.linkUp) { [weak self] in self?.linked = true }
        signals.on(Signal.linkDown) { [weak self] in self?.linked = false }
        signals.on(Signal.beat) { [weak self] in self?.beats += 1 }
        for n in 0...9 {
            signals.on(Signal.level(n)) { [weak self] in
                self?.broadcasting = true; self?.level = n; self?.lastSound = Date()
            }
        }
    }

    /// A screen code of our own, used when casting to a Chromecast (no web screen to read it from).
    static func ensureCode() {
        let current = clean(UserDefaults.standard.string(forKey: "screenCode") ?? "")
        if current.count == Signal.codeLength { return }
        let code = String((0..<Signal.codeLength).map { _ in Signal.codeAlphabet.randomElement()! })
        UserDefaults.standard.set(code, forKey: "screenCode")
    }

    static func clean(_ raw: String) -> String {
        String(raw.uppercased().filter { Signal.codeAlphabet.contains($0) }.prefix(Signal.codeLength))
    }

    /// Spells the screen code to the extension, one character per notification, then commits.
    func sendCode() {
        let code = Self.clean(UserDefaults.standard.string(forKey: "screenCode") ?? "")
        guard code.count == Signal.codeLength else { return }
        for (i, ch) in code.enumerated() { Signal.post(Signal.codeChar(i, ch)) }
        Signal.post(Signal.codeCommit)
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
    @ObservedObject private var b = Bridge.shared
    @ObservedObject private var cast = CastLink.shared
    @AppStorage("screenCode") private var screenCode = ""
    @State private var flash = 0.0
    @State private var now = Date()
    private let tick = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var codeOK: Bool { screenCode.count == Signal.codeLength }
    private var hearing: Bool { now.timeIntervalSince(b.lastSound) < 2 && b.level > 0 }

    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.02, blue: 0.06).ignoresSafeArea()
            Color(hue: Double(b.beats % 12) / 12, saturation: 0.9, brightness: 1)
                .opacity(flash * 0.5).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Jeux de lumière").font(.system(size: 30, weight: .bold))
                    Text("L’écran de la TV suit la musique de Spotify ou Deezer, sans micro.")
                        .foregroundStyle(.secondary)

                    step(1, "Touchez l’icône Cast et choisissez votre Chromecast ou Google TV : les lumières s’affichent sur la TV.")
                    HStack(spacing: 12) {
                        CastButton().frame(width: 44, height: 44)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                        if let name = cast.deviceName {
                            Label("Sur \(name)", systemImage: "tv.fill").foregroundStyle(.green)
                        } else if !CastLink.configured {
                            Text("Identifiant Cast pas encore configuré : la TV n’affichera pas les lumières (voir ios/CHROMECAST.md).")
                                .font(.footnote).foregroundStyle(.yellow)
                        }
                    }

                    step(2, "Sans Chromecast : sur l’appareil branché à la TV, ouvrez l’app web › Télécommande › Cet appareil est l’écran, et tapez ici son code. Avec Chromecast, ce code se remplit tout seul.")
                    TextField("K7Q2M", text: $screenCode)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .textInputAutocapitalization(.characters).autocorrectionDisabled()
                        .padding(12).background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                        .onChange(of: screenCode) { v in
                            let c = Bridge.clean(v)
                            if c != v { screenCode = c }
                            if c.count == Signal.codeLength && b.broadcasting { b.sendCode() }
                            if c.count == Signal.codeLength { cast.sendCode() }
                        }

                    step(3, "Touchez le bouton rond, puis « Commencer la diffusion ».")
                    HStack {
                        Spacer()
                        BroadcastButton().frame(width: 72, height: 72)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                            .opacity(codeOK ? 1 : 0.4).disabled(!codeOK)
                        Spacer()
                    }

                    step(4, "Ouvrez Spotify ou Deezer et lancez la musique, sur le haut-parleur ou une enceinte Bluetooth.")

                    meter
                    status
                }
                .padding(24)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            Bridge.ensureCode()
            cast.code = { Bridge.clean(UserDefaults.standard.string(forKey: "screenCode") ?? "") }
        }
        .onReceive(tick) { now = $0 }
        .onChange(of: b.beats) { _ in
            flash = 1
            withAnimation(.easeOut(duration: 0.35)) { flash = 0 }
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)").font(.headline).frame(width: 26, height: 26)
                .background(Circle().fill(Color.pink.opacity(0.85)))
            Text(text).font(.callout)
        }
    }

    private var meter: some View {
        HStack(spacing: 6) {
            ForEach(0..<9) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(i < b.level ? Color(hue: 0.33 - Double(i) * 0.04, saturation: 0.9, brightness: 1) : Color.white.opacity(0.1))
                    .frame(width: 22, height: 14 + CGFloat(i) * 6)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .bottom)
        .animation(.easeOut(duration: 0.08), value: b.level)
    }

    @ViewBuilder private var status: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !b.broadcasting {
                Label("Diffusion arrêtée", systemImage: "circle").foregroundStyle(.secondary)
            } else {
                Label(hearing ? "Musique reçue (\(b.beats) battements)" : "Diffusion en cours : lancez une musique",
                      systemImage: hearing ? "music.note" : "hourglass")
                    .foregroundStyle(hearing ? .green : .yellow)
                Label(b.linked ? "Écran \(screenCode) relié : les lumières suivent la musique" : "Connexion à l’écran \(screenCode)…",
                      systemImage: b.linked ? "tv.fill" : "antenna.radiowaves.left.and.right")
                    .foregroundStyle(b.linked ? .green : .yellow)
            }
        }
        .font(.callout)
    }
}
