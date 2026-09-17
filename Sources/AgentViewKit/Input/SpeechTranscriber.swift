import SwiftUI

/// One event of a ``SpeechTranscriber`` session.
public nonisolated enum SpeechTranscriptionEvent: Sendable, Hashable {
  /// The full transcript of the session until now. Each event replaces the
  /// text of the event before it.
  case transcript(String)

  /// The input level of the microphone, from `0` (silence) to `1` (loud).
  case level(Double)
}

/// The object that turns speech into text for ``SpeechInputButton``
/// (plan.md §9 D).
///
/// ``SystemSpeechTranscriber`` wraps `SFSpeechRecognizer`. A test gives a
/// fake, so that a test does not touch the microphone or the permission
/// prompts of the system.
public protocol SpeechTranscriber: AnyObject {
  /// Asks the user for permission to use the microphone and speech
  /// recognition.
  ///
  /// - Returns: `true` when the user gave both permissions.
  func requestAuthorization() async -> Bool

  /// Starts a session.
  ///
  /// - Returns: The events of the session. The stream finishes when the
  ///   session ends, or after ``stop()``.
  /// - Throws: An error when the session cannot start.
  func start() throws -> AsyncThrowingStream<SpeechTranscriptionEvent, any Error>

  /// Stops the current session and finishes its stream.
  func stop()
}

extension EnvironmentValues {
  /// The transcriber of ``SpeechInputButton``.
  ///
  /// The value is `nil` until a host sets a transcriber with
  /// ``SwiftUI/View/speechTranscriber(_:)``. While the value is `nil`,
  /// ``DefaultPromptAccessory`` shows no microphone button.
  @Entry public var speechTranscriber: (any SpeechTranscriber)? = nil
}

extension View {
  /// Sets the transcriber of ``SpeechInputButton`` for this view and each
  /// view in it.
  ///
  /// - Parameter transcriber: The transcriber, such as a
  ///   ``SystemSpeechTranscriber``, or `nil` for no microphone button.
  /// - Returns: A view that gives `transcriber` to its subtree.
  public func speechTranscriber(_ transcriber: (any SpeechTranscriber)?) -> some View {
    environment(\.speechTranscriber, transcriber)
  }
}
