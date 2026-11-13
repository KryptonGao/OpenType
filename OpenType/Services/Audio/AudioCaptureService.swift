@preconcurrency import AVFoundation
import Foundation

enum AudioCaptureError: Error, Equatable, Sendable {
    case noInputDevice
    case formatUnavailable
    case backlogOverflow
    case engine(String)

    var userMessage: String {
        switch self {
        case .noInputDevice: "未检测到可用的麦克风"
        case .formatUnavailable: "无法创建音频转换器"
        case .backlogOverflow: "网络拥塞，音频积压超过上限"
        case .engine(let detail): "音频采集中断：\(detail)"
        }
    }
}

protocol AudioCapturing: Sendable {
    /// Starts capture. The returned stream yields ~100 ms PCM16/16 kHz/mono chunks (3200 bytes) and finishes
    /// after `stop()` (the final partial chunk is flushed first).
    /// `onInterruption` fires (from any thread) when capture ends unexpectedly — device change, backlog overflow.
    func start(
        onLevel: @escaping @Sendable (Float) -> Void,
        onInterruption: @escaping @Sendable (AudioCaptureError) -> Void
    ) throws -> AsyncStream<Data>
    func stop()
}

/// Captures microphone audio via AVAudioEngine and resamples to PCM16 16 kHz mono.
/// The audio thread only converts and enqueues; it never touches the network.
final class AudioCaptureService: AudioCapturing, @unchecked Sendable {
    /// Bounded queue: 600 chunks ≈ 60 s of audio. Overflow is reported, never silently dropped.
    static let maxBufferedChunks = 600

    private let lock = NSLock()
    private var engine: AVAudioEngine?
    private var pipeline: AudioPipeline?
    private var observer: NSObjectProtocol?

    func start(
        onLevel: @escaping @Sendable (Float) -> Void,
        onInterruption: @escaping @Sendable (AudioCaptureError) -> Void
    ) throws -> AsyncStream<Data> {
        lock.lock()
        defer { lock.unlock() }
        stopLocked()

        let engine = AVAudioEngine()
        let inputFormat = engine.inputNode.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw AudioCaptureError.noInputDevice
        }

        let (stream, continuation) = AsyncStream<Data>.makeStream(
            bufferingPolicy: .bufferingOldest(Self.maxBufferedChunks)
        )
        let pipeline = try AudioPipeline(
            inputFormat: inputFormat,
            continuation: continuation,
            onLevel: onLevel,
            onOverflow: { onInterruption(.backlogOverflow) }
        )
        engine.inputNode.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { buffer, _ in
            pipeline.process(buffer)
        }
        observer = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil
        ) { _ in
            onInterruption(.engine("音频设备配置已变更"))
        }
        do {
            engine.prepare()
            try engine.start()
        } catch {
            engine.inputNode.removeTap(onBus: 0)
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = nil
            continuation.finish()
            throw AudioCaptureError.engine(error.localizedDescription)
        }
        self.engine = engine
        self.pipeline = pipeline
        return stream
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        stopLocked()
    }

    private func stopLocked() {
        if let engine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        pipeline?.finish()
        pipeline = nil
        engine = nil
    }
}

/// Converts hardware-format buffers to PCM16/16k/mono and slices them into fixed 100 ms chunks.
final class AudioPipeline: @unchecked Sendable {
    static let chunkSize = 3200 // 100 ms * 16000 Hz * 2 bytes

    private final class Flag: @unchecked Sendable { var value = false }

    private let converter: AVAudioConverter
    private let outputFormat: AVAudioFormat
    private let continuation: AsyncStream<Data>.Continuation
    private let onLevel: @Sendable (Float) -> Void
    private let onOverflow: @Sendable () -> Void
    private let lock = NSLock()
    private var pending = Data()
    private var overflowed = false
    private var finished = false

    init(
        inputFormat: AVAudioFormat,
        continuation: AsyncStream<Data>.Continuation,
        onLevel: @escaping @Sendable (Float) -> Void,
        onOverflow: @escaping @Sendable () -> Void
    ) throws {
        guard let output = AVAudioFormat(
            commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true
        ), let converter = AVAudioConverter(from: inputFormat, to: output) else {
            throw AudioCaptureError.formatUnavailable
        }
        self.outputFormat = output
        self.converter = converter
        self.continuation = continuation
        self.onLevel = onLevel
        self.onOverflow = onOverflow
    }

    func process(_ buffer: AVAudioPCMBuffer) {
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return }

        let consumed = Flag()
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            if consumed.value {
                inputStatus.pointee = .noDataNow
                return nil
            }
            consumed.value = true
            inputStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, error == nil else { return }
        let frames = Int(output.frameLength)
        guard frames > 0, let samples = output.int16ChannelData?[0] else { return }

        onLevel(Self.level(samples: samples, count: frames))
        append(Data(bytes: samples, count: frames * MemoryLayout<Int16>.size))
    }

    /// Flushes the remaining partial chunk and ends the stream.
    func finish() {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return }
        finished = true
        if !pending.isEmpty {
            continuation.yield(pending)
            pending.removeAll()
        }
        continuation.finish()
    }

    private func append(_ bytes: Data) {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return }
        pending.append(bytes)
        while pending.count >= Self.chunkSize {
            let chunk = Data(pending.prefix(Self.chunkSize))
            pending = Data(pending.dropFirst(Self.chunkSize))
            if case .dropped = continuation.yield(chunk), !overflowed {
                overflowed = true
                onOverflow()
            }
        }
    }

    /// RMS → 0...1 using a 50 dB window.
    static func level(samples: UnsafePointer<Int16>, count: Int) -> Float {
        guard count > 0 else { return 0 }
        var sum: Double = 0
        for index in 0..<count {
            let value = Double(samples[index]) / 32768.0
            sum += value * value
        }
        let rms = (sum / Double(count)).squareRoot()
        guard rms > 0 else { return 0 }
        let decibels = 20 * log10(rms)
        return Float(min(1, max(0, (decibels + 50) / 50)))
    }
}
