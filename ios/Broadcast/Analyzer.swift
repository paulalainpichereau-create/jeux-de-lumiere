import Accelerate
import CoreMedia

/// One analysis frame, in exactly the shape the web screen expects (see onRemoteMessage / analyse in index.html).
struct Frame {
    var tb: Float, tm: Float, th: Float, loud: Float
    var ts: [Float]      // 48 log-spaced bands, 0…1
    var wv: [Float]      // 64 waveform points, -1…1
    var beat: Bool

    func json() -> Data {
        func f(_ x: Float) -> String { x.isFinite ? String(format: "%.2f", x) : "0" }
        var s = "{\"t\":\"f\",\"tb\":\(f(tb)),\"tm\":\(f(tm)),\"th\":\(f(th)),\"loud\":\(f(loud)),\"ts\":["
        s += ts.map(f).joined(separator: ",")
        s += "],\"wv\":["
        s += wv.map(f).joined(separator: ",")
        s += "],\"beat\":\(beat ? "true" : "false")}"
        return Data(s.utf8)
    }
}

/// Port of the web app's analysis (index.html, analyse()): an FFT shaped like Web Audio's AnalyserNode
/// (2048 points, Blackman window, 0.72 smoothing, -90…-20 dB), the same bands, auto-gain and beat rule.
/// Running the same maths on both sides keeps the lights looking the same whatever the source.
final class Analyzer {
    static let n = 2048
    private static let half = n / 2
    private let log2n = vDSP_Length(11)
    private let setup: FFTSetup
    private let window: [Float]

    private var ring = [Float](repeating: 0, count: 2 * n)   // mono history
    private var writeIndex = 0, filled = 0
    private var sampleRate: Float = 48_000
    private var lowCut: Float = 0

    private var block = [Float](repeating: 0, count: n)
    private var real = [Float](repeating: 0, count: half)
    private var imag = [Float](repeating: 0, count: half)
    private var smooth = [Float](repeating: 0, count: half)
    private var level = [Float](repeating: 0, count: half)    // 0…1, like getByteFrequencyData / 255

    // same auto-gain memories and beat state as the web app
    private var agB: Float = 0.12, agM: Float = 0.12, agH: Float = 0.1, agS: Float = 0.15, agW: Float = 0.06, pk: Float = 0.05
    private var avg: Float = 0, prev: Float = 0
    private var lastBeat: Double = 0, lastTime: Double = 0

    init() {
        setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        var w = [Float](repeating: 0, count: Self.n)
        vDSP_blkman_window(&w, vDSP_Length(Self.n), 0)
        window = w
    }

    deinit { vDSP_destroy_fftsetup(setup) }

    // MARK: input

    /// Mixes the buffer down to mono and appends it to the history. Handles 16-bit and float PCM,
    /// interleaved or not, little or big endian (ReplayKit app audio is often big-endian 16-bit).
    func append(_ sb: CMSampleBuffer) {
        guard let fmt = CMSampleBufferGetFormatDescription(sb),
              let asbdPtr = CMAudioFormatDescriptionGetStreamBasicDescription(fmt) else { return }
        let asbd = asbdPtr.pointee
        if asbd.mSampleRate > 0 { sampleRate = Float(asbd.mSampleRate) }
        let isFloat = asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0
        let bigEndian = asbd.mFormatFlags & kAudioFormatFlagIsBigEndian != 0
        let bits = Int(asbd.mBitsPerChannel)
        guard (isFloat && bits == 32) || (!isFloat && bits == 16) else { return }
        let bytesPerSample = bits / 8

        var sizeNeeded = 0
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sb, bufferListSizeNeededOut: &sizeNeeded, bufferListOut: nil, bufferListSize: 0,
            blockBufferAllocator: nil, blockBufferMemoryAllocator: nil, flags: 0, blockBufferOut: nil)
        guard sizeNeeded > 0 else { return }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: sizeNeeded, alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        let ablPtr = raw.bindMemory(to: AudioBufferList.self, capacity: 1)
        var block: CMBlockBuffer?
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sb, bufferListSizeNeededOut: nil, bufferListOut: ablPtr, bufferListSize: sizeNeeded,
            blockBufferAllocator: nil, blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment, blockBufferOut: &block)
        guard status == noErr else { return }
        let buffers = UnsafeMutableAudioBufferListPointer(ablPtr)
        guard let first = buffers.first, first.mNumberChannels > 0 else { return }

        let channelsPerBuffer = Int(first.mNumberChannels)
        let frames = Int(first.mDataByteSize) / (bytesPerSample * channelsPerBuffer)
        guard frames > 0 else { return }
        var mono = [Float](repeating: 0, count: frames)
        var totalChannels = 0
        for buf in buffers {
            guard let data = buf.mData else { continue }
            let ch = Int(buf.mNumberChannels)
            let count = min(frames, Int(buf.mDataByteSize) / (bytesPerSample * max(ch, 1)))
            totalChannels += ch
            if isFloat {
                let p = data.assumingMemoryBound(to: UInt32.self)
                for i in 0..<count {
                    for c in 0..<ch {
                        let bitsValue = bigEndian ? UInt32(bigEndian: p[i * ch + c]) : p[i * ch + c]
                        mono[i] += Float(bitPattern: bitsValue)
                    }
                }
            } else {
                let p = data.assumingMemoryBound(to: Int16.self)
                for i in 0..<count {
                    for c in 0..<ch {
                        let v = bigEndian ? Int16(bigEndian: p[i * ch + c]) : p[i * ch + c]
                        mono[i] += Float(v) / 32768
                    }
                }
            }
        }
        guard totalChannels > 0 else { return }
        let scale = 1 / Float(totalChannels)
        for x in mono {
            ring[writeIndex] = x * scale
            writeIndex = (writeIndex + 1) % ring.count
        }
        filled = min(ring.count, filled + frames)
    }

    // MARK: analysis

    func frame(now: Double) -> Frame? {
        let n = Self.n, half = Self.half
        guard filled >= n else { return nil }
        let dt = Float(lastTime == 0 ? 0.045 : min(0.2, max(0.001, now - lastTime)))
        lastTime = now

        // last n samples, oldest first
        let start = (writeIndex - n + ring.count) % ring.count
        for i in 0..<n { block[i] = ring[(start + i) % ring.count] }

        // FFT of the windowed block
        var windowed = [Float](repeating: 0, count: n)
        vDSP_vmul(block, 1, window, 1, &windowed, 1, vDSP_Length(n))
        real.withUnsafeMutableBufferPointer { rp in
            imag.withUnsafeMutableBufferPointer { ip in
                var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
                windowed.withUnsafeBufferPointer { wp in
                    wp.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) { cp in
                        vDSP_ctoz(cp, 2, &split, 1, vDSP_Length(half))
                    }
                }
                vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
            }
        }
        imag[0] = 0 // bin 0 carries the Nyquist value in the imaginary slot: drop it
        let norm = 1 / (2 * Float(n))   // vDSP's real FFT is scaled ×2; Web Audio divides by n
        for k in 0..<half {
            let mag = sqrtf(real[k] * real[k] + imag[k] * imag[k]) * norm
            smooth[k] = 0.72 * smooth[k] + 0.28 * mag
            let db = 20 * log10f(max(smooth[k], 1e-12))
            level[k] = min(1, max(0, (db + 90) / 70))
        }

        let bin = sampleRate / Float(n), top = half - 1
        func bandAvg(_ f0: Float, _ f1: Float) -> Float {
            let a = min(top, max(1, Int((f0 / bin).rounded())))
            let b = min(top, max(a, Int((f1 / bin).rounded())))
            var s: Float = 0
            for i in a...b { s += level[i] }
            return s / Float(b - a + 1)
        }

        let rb = bandAvg(30, 150), rm = bandAvg(150, 2000), rh = bandAvg(2000, 12000)
        let rawL = 0.5 * rb + 0.3 * rm + 0.2 * rh
        pk = max(pk * powf(0.5, dt / 30), rawL, 0.05)
        let loud = rawL / pk
        let decay = powf(0.5, dt / 6)
        agB = max(agB * decay, rb, 0.12)
        agM = max(agM * decay, rm, 0.12)
        agH = max(agH * decay, rh, 0.1)
        let tb = powf(min(1, max(0, rb / agB)), 1.3)
        let tm = powf(min(1, max(0, rm / agM)), 1.2)
        let th = powf(min(1, max(0, rh / agH)), 1.2)

        var bands = [Float](repeating: 0, count: 48), mx: Float = 0
        for j in 0..<48 {
            let f0 = 40 * powf(350, Float(j) / 48), f1 = 40 * powf(350, Float(j + 1) / 48)
            let v = bandAvg(f0, f1) * (1 + 1.2 * Float(j) / 48)
            bands[j] = v
            mx = max(mx, v)
        }
        agS = max(agS * decay, mx, 0.15)
        let ts = bands.map { powf(min(1, max(0, $0 / agS)), 1.25) }

        // waveform: start on a rising zero crossing so the trace stays steady (64 points, every 16 samples)
        var s0 = 0
        for i in 0..<(n / 2 - 1) where block[i] < 0 && block[i + 1] >= 0 { s0 = i; break }
        var wv = [Float](repeating: 0, count: 64), wm: Float = 0
        for i in 0..<64 {
            let x = block[min(n - 1, s0 + i * 16)]
            wv[i] = x
            wm = max(wm, abs(x))
        }
        agW = max(agW * decay, wm, 0.06)
        for i in 0..<64 { wv[i] = min(1, max(-1, wv[i] / agW * 0.9)) }

        // beat: same rule as the web app
        avg += (tb - avg) * (1 - expf(-dt * 2.2))
        let beat = tb > prev + 0.015 && tb > 0.4 && tb > avg * 1.2 + 0.05 && now - lastBeat > 0.28
        if beat { lastBeat = now }
        prev = tb

        return Frame(tb: tb, tm: tm, th: th, loud: loud, ts: ts, wv: wv, beat: beat)
    }
}
