import AVFoundation
import Foundation
import Speech

/// The ``SpeechTranscriber`` of the system: `SFSpeechRecognizer` with the
/// audio of the default microphone (plan.md §9 D).
///
/// The host app must have the `NSMicrophoneUsageDescription` and
/// `NSSpeechRecognitionUsageDescription` keys in its `Info.plist`.
///
/// The class is isolated to the main actor, so it meets the `Sendable`
/// requirement of ``SpeechTranscriber``. The microphone tap and the
/// recognition handler run on their own threads and touch only `Sendable`
/// values.
@MainActor
public final class SystemSpeechTranscriber: AgentViewKit.SpeechTranscriber {
  /// The stream type of the events of a session.
  private typealias Events = AsyncThrowingStream<SpeechTranscriptionEvent, any Error>

  /// The recognizer of the locale.
  private let recognizer: SFSpeechRecognizer?

  /// The audio engine that reads the microphone.
  private let engine = AVAudioEngine()

  /// The recognition task of the current session.
  private var task: SFSpeechRecognitionTask?

  /// The request of the current session.
  private var request: SFSpeechAudioBufferRecognitionRequest?

  /// The continuation of the event stream of the current session.
  private var continuation: Events.Continuation?

  /// The continuation of the audio stream that the microphone tap writes.
  private var audioSink: AsyncStream<AVReadOnlyAudioPCMBuffer>.Continuation?

  /// The task that gives each audio buffer to the request.
  private var feeder: Task<Void, Never>?

  /// The number of audio frames in one tap buffer.
  private static let bufferSize: AVAudioFrameCount = 1024

  /// The bus of the input node that the tap reads.
  private static let inputBus: AVAudioNodeBus = 0

  /// The channel of a buffer that the level reads.
  private nonisolated static let levelChannel = 0

  /// The lowest input level in decibels. A quieter input shows as the lowest
  /// level.
  private nonisolated static let silenceDecibels: Float = -50

  /// The factor that turns the log of an amplitude ratio into decibels.
  private nonisolated static let decibelsPerAmplitudeDecade: Float = 20

  /// The range of a reported input level.
  private nonisolated static let levelRange: ClosedRange<Float> = 0...1

  /// Makes a transcriber.
  ///
  /// - Parameter locale: The locale of the speech. The default is the
  ///   current locale.
  public init(locale: Locale = .current) {
    recognizer = SFSpeechRecognizer(locale: locale)
  }

  public func requestAuthorization() async -> Bool {
    let speech = await withCheckedContinuation { continuation in
      SFSpeechRecognizer.requestAuthorization { status in
        continuation.resume(returning: status == .authorized)
      }
    }
    guard speech else { return false }
    return await AVCaptureDevice.requestAccess(for: .audio)
  }

  public func start() throws -> AsyncThrowingStream<SpeechTranscriptionEvent, any Error> {
    stop()
    guard let recognizer, recognizer.isAvailable else {
      throw SystemSpeechTranscriberError.recognizerUnavailable
    }
    let (events, continuation) = Events.makeStream()
    let (audio, audioSink) = AsyncStream.makeStream(of: AVReadOnlyAudioPCMBuffer.self)
    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    self.request = request
    self.continuation = continuation
    self.audioSink = audioSink
    feeder = Task { @MainActor in
      for await buffer in audio {
        request.append(AVAudioPCMBuffer(copying: buffer))
        continuation.yield(.level(Self.level(of: buffer)))
      }
    }
    do {
      let input = engine.inputNode
      try input.installAudioTap(
        onBus: Self.inputBus, bufferSize: Self.bufferSize,
        format: input.outputFormat(forBus: Self.inputBus)
      ) { buffer, _ in
        audioSink.yield(buffer)
      }
      task = recognizer.recognitionTask(
        with: request, resultHandler: Self.resultHandler(continuation: continuation))
      engine.prepare()
      try engine.start()
    } catch {
      stop()
      throw error
    }
    return events
  }

  public func stop() {
    engine.stop()
    engine.inputNode.removeTap(onBus: Self.inputBus)
    audioSink?.finish()
    feeder?.cancel()
    request?.endAudio()
    task?.cancel()
    continuation?.finish()
    audioSink = nil
    feeder = nil
    request = nil
    task = nil
    continuation = nil
  }

  /// The handler that sends each recognition result to the event stream.
  ///
  /// The recognizer calls the handler on its own queue, so the handler is
  /// made outside the main actor.
  ///
  /// - Parameter continuation: The continuation of the event stream.
  /// - Returns: The result handler.
  private nonisolated static func resultHandler(
    continuation: Events.Continuation
  ) -> @Sendable (SFSpeechRecognitionResult?, (any Error)?) -> Void {
    { result, error in
      if let result {
        continuation.yield(.transcript(result.bestTranscription.formattedString))
        if result.isFinal { continuation.finish() }
      } else if let error {
        continuation.finish(throwing: error)
      }
    }
  }

  /// The input level of an audio buffer.
  ///
  /// - Parameter buffer: The buffer.
  /// - Returns: The root mean square level of ``levelChannel``, from the
  ///   lower bound of ``levelRange`` at ``silenceDecibels`` to the upper
  ///   bound at 0 dB. A buffer with no float samples, or with silence only,
  ///   gives the lower bound.
  private nonisolated static func level(of buffer: AVReadOnlyAudioPCMBuffer) -> Double {
    let lowest = Double(levelRange.lowerBound)
    guard case .float(let samples) = buffer.channelData(levelChannel), !samples.isEmpty else {
      return lowest
    }
    var sum: Float = .zero
    for index in samples.indices {
      sum += samples[index] * samples[index]
    }
    let rms = (sum / Float(samples.count)).squareRoot()
    guard rms > .zero else { return lowest }
    let decibels = decibelsPerAmplitudeDecade * log10(rms)
    let level = (silenceDecibels - decibels) / silenceDecibels
    return Double(min(max(level, levelRange.lowerBound), levelRange.upperBound))
  }
}

/// The errors of ``SystemSpeechTranscriber``.
public nonisolated enum SystemSpeechTranscriberError: Error, Equatable {
  /// The system has no speech recognizer for the locale, or the recognizer
  /// is not available now.
  case recognizerUnavailable
}
