import ReplayKit
import CoreMedia

/// Broadcast extension. While the user runs a "Diffusion" with it, iOS hands it the sound played by the
/// other apps (.audioApp). It analyses that sound like the web app does and publishes ~22 frames a second
/// on the relay, on the topic of the TV screen whose code the app passed over. Only levels leave the phone.
final class SampleHandler: RPBroadcastSampleHandler {
    private let analyzer = Analyzer()
    private let link = MQTTLink()
    private let signals = SignalListener()
    private var slots = [Character?](repeating: nil, count: Signal.codeLength)
    private var code: String?
    private var askTimer: DispatchSourceTimer?
    private var lastFrame: CFAbsoluteTime = 0

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        // the screen code arrives one character per notification, then a commit
        for position in 0..<Signal.codeLength {
            for char in Signal.codeAlphabet {
                signals.on(Signal.codeChar(position, char)) { [weak self] in self?.slots[position] = char }
            }
        }
        signals.on(Signal.codeCommit) { [weak self] in self?.commitCode() }
        link.onState = { up in Signal.post(up ? Signal.linkUp : Signal.linkDown) }
        Signal.post(Signal.started)

        // keep asking until the app answers (it is in front when the broadcast starts from its button)
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: 1.0)
        timer.setEventHandler { [weak self] in
            guard let self, self.code == nil else { return }
            Signal.post(Signal.codeRequest)
        }
        timer.resume()
        askTimer = timer
    }

    private func commitCode() {
        let chars = slots.compactMap { $0 }
        guard chars.count == Signal.codeLength else { return }
        let newCode = String(chars)
        guard newCode != code else { return }
        if code != nil { link.close() }      // the user switched to another screen
        code = newCode
        link.open(code: newCode)
    }

    override func broadcastFinished() {
        askTimer?.cancel()
        link.close()
        Signal.post(Signal.stopped)
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .audioApp else { return }
        analyzer.append(sampleBuffer)
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastFrame >= 0.045, let f = analyzer.frame(now: now) else { return }
        lastFrame = now
        link.publish(f.json())
        Signal.post(Signal.level(min(9, max(0, Int(f.loud * 9.5)))))
        if f.beat { Signal.post(Signal.beat) }
    }
}
