import AVFoundation
import Foundation
import Speech

/// The ``SpeechTranscriber`` of the system: `SFSpeechRecognizer` with the
/// audio of the default microphone (plan.md §9 D).
///
/// The host app must have the `NSMicrophoneUsageDescription` and
/// `NSSpeechRecognitionUsageDescription` keys in its `Info.plist`.
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

  /// The lowest input level in decibels. A quieter input shows as level `0`.
  private nonisolated static let silenceDecibels: Float = -50

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
    feeder = Task {
      for await buffer in audio {
        request.append(AVAudioPCMBuffer(copying: buffer))
        continuation.yield(.level(Self.level(of: buffer)))
      }
    }
    do {
      let input = engine.inputNode
      try input.installAudioTap(
        onBus: 0, bufferSize: Self.bufferSize, format: input.outputFormat(forBus: 0)
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
    engine.inputNode.removeTap(onBus: 0)
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
  /// - Returns: The root mean square level of the first channel, from `0` at
  ///   ``silenceDecibels`` to `1` at 0 dB. A buffer with no float samples
  ///   gives `0`.
  private nonisolated static func level(of buffer: AVReadOnlyAudioPCMBuffer) -> Double {
    guard case .float(let samples) = buffer.channelData(0), !samples.isEmpty else { return 0 }
    var sum: Float = 0
    for index in samples.indices {
      sum += samples[index] * samples[index]
    }
    let rms = (sum / Float(samples.count)).squareRoot()
    guard rms > 0 else { return 0 }
    let decibels = 20 * log10(rms)
    return Double(min(max(1 - decibels / silenceDecibels, 0), 1))
  }
}

/// The errors of ``SystemSpeechTranscriber``.
public nonisolated enum SystemSpeechTranscriberError: Error, Equatable {
  /// The system has no speech recognizer for the locale, or the recognizer
  /// is not available now.
  case recognizerUnavailable
}
