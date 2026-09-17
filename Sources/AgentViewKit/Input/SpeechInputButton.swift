import SwiftUI
import os

/// The microphone button of the composer (plan.md §9 D).
///
/// A press asks the ``SwiftUI/EnvironmentValues/speechTranscriber`` for
/// permission and starts a session. While the session runs, the button shows
/// the input level, and the live transcript goes into the composer text
/// after the text that was there at the start. A second press stops the
/// session and keeps the text.
///
/// The button writes the text through
/// ``SwiftUI/EnvironmentValues/promptText``. The button is empty when the
/// environment has no transcriber, or when it is not in a composer.
public struct SpeechInputButton: View {
  /// The state of the button.
  enum Phase: Equatable {
    /// No session runs.
    case idle
    /// A session runs.
    case recording
    /// The user did not give permission.
    case denied
  }

  /// The accessibility identifier of the button.
  public static let identifier = "prompt-mic"

  @Environment(\.speechTranscriber) private var transcriber
  @Environment(\.promptText) private var text
  @Environment(\.agentTheme) private var theme

  @State private var phase = Phase.idle
  @State private var level: Double = .zero
  @State private var session: Task<Void, Never>?

  /// The log of the button.
  private static let logger = Logger(subsystem: "AgentViewKit", category: "SpeechInputButton")

  /// Makes the button.
  public init() {}

  /// The composer text with a transcript after the start text.
  ///
  /// The function puts one space between the start text and the transcript,
  /// unless the start text is empty or ends with white space. The start text
  /// keeps its attributes, such as the `link` of a file chip.
  ///
  /// - Parameters:
  ///   - base: The composer text at the start of the session.
  ///   - transcript: The transcript of the session until now.
  /// - Returns: The new composer text.
  static func transcribedText(base: AttributedString, transcript: String) -> AttributedString {
    let needsSpace = base.characters.last.map { !$0.isWhitespace } ?? false
    return base + AttributedString((needsSpace ? " " : "") + transcript)
  }

  public var body: some View {
    if let transcriber, let text {
      Button {
        toggle(transcriber: transcriber, text: text)
      } label: {
        label
      }
      .buttonStyle(.glass)
      .buttonBorderShape(.circle)
      .help(helpText)
      .accessibilityLabel(String(localized: "Dictate"))
      .accessibilityValue(valueText)
      .accessibilityIdentifier(Self.identifier)
      .onDisappear { stop(transcriber: transcriber) }
    }
  }

  /// The icon of the button. While a session runs, the waveform shows the
  /// input level.
  @ViewBuilder
  private var label: some View {
    switch phase {
    case .recording:
      Image(systemName: "waveform", variableValue: level)
        .fontWeight(theme.symbolWeight)
        .foregroundStyle(.tint)
    case .idle:
      Image(systemName: "mic")
        .fontWeight(theme.symbolWeight)
    case .denied:
      Image(systemName: "mic.slash")
        .fontWeight(theme.symbolWeight)
    }
  }

  /// The help text of the button.
  private var helpText: String {
    switch phase {
    case .recording: String(localized: "Stop dictation")
    case .idle: String(localized: "Dictate the prompt")
    case .denied: String(localized: "Dictation is not allowed")
    }
  }

  /// The accessibility value of the button.
  private var valueText: String {
    switch phase {
    case .recording: String(localized: "Recording")
    case .idle: String(localized: "Not recording")
    case .denied: String(localized: "Not allowed")
    }
  }

  /// Starts a session, or stops the session that runs.
  ///
  /// - Parameters:
  ///   - transcriber: The transcriber of the session.
  ///   - text: The composer text.
  private func toggle(transcriber: any SpeechTranscriber, text: Binding<AttributedString>) {
    if phase == .recording {
      stop(transcriber: transcriber)
      return
    }
    phase = .recording
    session = Task { @MainActor in
      await record(transcriber: transcriber, text: text)
    }
  }

  /// Stops the session that runs. The composer text does not change.
  ///
  /// - Parameter transcriber: The transcriber of the session.
  private func stop(transcriber: any SpeechTranscriber) {
    guard phase == .recording else { return }
    session?.cancel()
    session = nil
    transcriber.stop()
    phase = .idle
    level = .zero
  }

  /// Asks for permission, then writes each transcript into the composer text
  /// until the session ends.
  ///
  /// - Parameters:
  ///   - transcriber: The transcriber of the session.
  ///   - text: The composer text.
  private func record(transcriber: any SpeechTranscriber, text: Binding<AttributedString>) async {
    guard await transcriber.requestAuthorization() else {
      phase = .denied
      return
    }
    guard !Task.isCancelled else { return }
    let base = text.wrappedValue
    do {
      for try await event in try transcriber.start() {
        switch event {
        case .transcript(let transcript):
          text.wrappedValue = Self.transcribedText(base: base, transcript: transcript)
        case .level(let value):
          level = value
        }
      }
    } catch {
      Self.logger.error("Dictation failed: \(error.localizedDescription, privacy: .public)")
    }
    guard !Task.isCancelled else { return }
    phase = .idle
    level = .zero
    session = nil
  }
}
