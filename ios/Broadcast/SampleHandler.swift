import ReplayKit
import CoreMedia

/// Broadcast extension: while the user runs a "Diffusion" (screen broadcast) with this extension,
/// iOS hands it the sound played by the other apps (.audioApp). This prototype only measures it:
/// overall level, bass level and beats, and tells the main app through Darwin notifications
/// (they cross process boundaries without needing an App Group, which keeps signing simple).
final class SampleHandler: RPBroadcastSampleHandler {
    private var lowpass: Float = 0          // one-pole low-pass state, isolates the bass
    private var peak: Float = 0.02          // auto-gain memory
    private var bassAvg: Float = 0, bassPrev: Float = 0
    private var lastPost: CFAbsoluteTime = 0, lastBeat: CFAbsoluteTime = 0
    private var levelSum: Float = 0, bassSum: Float = 0, count = 0

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        Signal.post(Signal.started)
    }

    override func broadcastFinished() {
        Signal.post(Signal.stopped)
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .audioApp else { return }
        guard let (rms, bass) = measure(sampleBuffer) else { return }
        levelSum += rms; bassSum += bass; count += 1

        let now = CFAbsoluteTimeGetCurrent()
        // beat: bass rising clearly above its running average, at most ~3.5 per second
        bassAvg += (bass - bassAvg) * 0.05
        if bass > bassPrev * 1.08, bass > bassAvg * 1.35, bass > 0.004, now - lastBeat > 0.28 {
            lastBeat = now
            Signal.post(Signal.beat)
        }
        bassPrev = bass

        // level: 0…9 relative to the recent peak, sent 20 times a second
        if now - lastPost >= 0.05, count > 0 {
            let level = levelSum / Float(count)
            peak = max(peak * 0.995, level, 0.002)
            let step = min(9, max(0, Int((level / peak) * 9.5)))
            Signal.post(Signal.level(step))
            lastPost = now; levelSum = 0; bassSum = 0; count = 0
        }
    }

    /// RMS of the whole buffer and of its low-passed (bass) part. App audio comes as 16-bit or float PCM,
    /// sometimes big-endian, so the format is read from the buffer itself.
    private func measure(_ sb: CMSampleBuffer) -> (Float, Float)? {
        guard let fmt = CMSampleBufferGetFormatDescription(sb),
              let asbdPtr = CMAudioFormatDescriptionGetStreamBasicDescription(fmt) else { return nil }
        let asbd = asbdPtr.pointee
        let isFloat = asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0
        let bigEndian = asbd.mFormatFlags & kAudioFormatFlagIsBigEndian != 0
        let bits = Int(asbd.mBitsPerChannel)
        let rate = asbd.mSampleRate > 0 ? Float(asbd.mSampleRate) : 44100
        let alpha = 1 - expf(-2 * .pi * 150 / rate) // ~150 Hz low-pass

        var blockBuffer: CMBlockBuffer?
        var abl = AudioBufferList()
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sb, bufferListSizeNeededOut: nil, bufferListOut: &abl, bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: nil, blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment, blockBufferOut: &blockBuffer)
        guard status == noErr, let data = abl.mBuffers.mData else { return nil }
        let bytes = Int(abl.mBuffers.mDataByteSize)

        var sum: Float = 0, bassSumSq: Float = 0, n = 0
        if isFloat && bits == 32 {
            let p = data.assumingMemoryBound(to: Float.self)
            n = bytes / 4
            for i in 0..<n {
                let x = p[i]
                lowpass += alpha * (x - lowpass)
                sum += x * x; bassSumSq += lowpass * lowpass
            }
        } else if bits == 16 {
            let p = data.assumingMemoryBound(to: Int16.self)
            n = bytes / 2
            for i in 0..<n {
                let raw = bigEndian ? Int16(bigEndian: p[i]) : p[i]
                let x = Float(raw) / 32768
                lowpass += alpha * (x - lowpass)
                sum += x * x; bassSumSq += lowpass * lowpass
            }
        } else {
            return nil
        }
        guard n > 0 else { return nil }
        return (sqrtf(sum / Float(n)), sqrtf(bassSumSq / Float(n)))
    }
}
