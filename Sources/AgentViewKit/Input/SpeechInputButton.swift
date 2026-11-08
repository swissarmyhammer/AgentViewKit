import EditorCommandsUI
import EditorStyle
import EditorSwiftUI
import SwiftUI
import os

/// The microphone button of the composer (plan.md §9 D).
///
/// A press asks the ``SwiftUI/EnvironmentValues/speechTranscriber`` for
/// permission and starts a session. While the session runs, the button shows
/// the listening symbol, filled to the live input level of the microphone
/// (the variable value of EditorKit's `EditorButton`), its accessibility value
/// reads the level as a percentage, and the live transcript goes into the
/// composer text after the text that was there at the start. A second press
/// stops the session and keeps the text.
///
/// The button writes the text through
/// ``SwiftUI/EnvironmentValues/promptText``. The button is empty when the
/// environment has no transcriber, or when it is not in a composer.
public struct SpeechInputButton: View {
  /// The state of the button.
  enum Phase: Equatable {
    /// No session runs.
    case idle
    /// A session runs. `level` is the last input level of the microphone,
    /// from `0` (silence) to `1` (loud), or `nil` until the transcriber sends
    /// the first one.
    case recording(level: Double?)
    /// The user did not give permission.
    case denied
  }

  /// The accessibility identifier of the button.
  public static let identifier = "prompt-mic"

  @Environment(\.speechTranscriber) private var transcriber
  @Environment(\.promptText) private var text

  @State private var phase = Phase.idle
  @State private var session: Task<Void, Never>?

  @Environment(\.speechInputPhaseReport) private var reportPhase

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
      EditorButton(title, systemImage: symbol, variableValue: level, look: .action) {
        toggle(transcriber: transcriber, text: text)
      }
      .editorButtonCaptions(.hidden)
      .editorButtonBorderShape(.circle)
      .accessibilityValue(Self.valueText(of: phase))
      .accessibilityIdentifier(Self.identifier)
      .agentControlScope(Self.identifier)
      .onDisappear { stop(transcriber: transcriber) }
    }
  }

  /// The symbol of the button in its phase. It has no tint of its own,
  /// because only the primary action of the composer (Send) has a tint.
  private var symbol: String {
    switch phase {
    case .recording: AgentSymbol.listening
    case .idle: AgentSymbol.microphone
    case .denied: AgentSymbol.microphoneUnavailable
    }
  }

  /// The input level that fills the symbol: the last level of a session that
  /// runs, or `nil` for a plain symbol.
  private var level: Double? {
    guard case .recording(let level) = phase else { return nil }
    return level
  }

  /// The title of the button in its phase: its accessibility label and its
  /// tooltip, because the button shows its symbol alone.
  private var title: String {
    switch phase {
    case .recording: String(localized: "Stop dictation", bundle: .module)
    case .idle: String(localized: "Dictate the prompt", bundle: .module)
    case .denied: String(localized: "Dictation is not allowed", bundle: .module)
    }
  }

  /// The accessibility value of the button in `phase`.
  ///
  /// - Parameter phase: The phase of the button.
  /// - Returns: "Recording", with the input level as a whole percentage once
  ///   the transcriber sent one, or the text of a phase with no session.
  static func valueText(of phase: Phase) -> String {
    switch phase {
    case .recording(level: nil): String(localized: "Recording", bundle: .module)
    case .recording(level: let level?):
      String(
        localized: "Recording, input level \(level.formatted(.percent.precision(.fractionLength(0))))",
        bundle: .module)
    case .idle: String(localized: "Not recording", bundle: .module)
    case .denied: String(localized: "Not allowed", bundle: .module)
    }
  }

  /// Starts a session, or stops the session that runs.
  ///
  /// - Parameters:
  ///   - transcriber: The transcriber of the session.
  ///   - text: The composer text.
  private func toggle(transcriber: any SpeechTranscriber, text: Binding<AttributedString>) {
    if case .recording = phase {
      stop(transcriber: transcriber)
      return
    }
    show(.recording(level: nil))
    session = Task { @MainActor in
      await record(transcriber: transcriber, text: text)
    }
  }

  /// Stops the session that runs. The composer text does not change.
  ///
  /// - Parameter transcriber: The transcriber of the session.
  private func stop(transcriber: any SpeechTranscriber) {
    guard case .recording = phase else { return }
    session?.cancel()
    session = nil
    transcriber.stop()
    show(.idle)
  }

  /// Asks for permission, then writes each transcript into the composer text
  /// until the session ends.
  ///
  /// - Parameters:
  ///   - transcriber: The transcriber of the session.
  ///   - text: The composer text.
  private func record(transcriber: any SpeechTranscriber, text: Binding<AttributedString>) async {
    guard await transcriber.requestAuthorization() else {
      show(.denied)
      return
    }
    guard !Task.isCancelled else { return }
    let base = text.wrappedValue
    do {
      for try await event in try transcriber.start() {
        switch event {
        case .transcript(let transcript):
          text.wrappedValue = Self.transcribedText(base: base, transcript: transcript)
        case .level(let level):
          show(.recording(level: level))
        }
      }
    } catch {
      Self.logger.error("Dictation failed: \(error.localizedDescription, privacy: .public)")
    }
    guard !Task.isCancelled else { return }
    show(.idle)
    session = nil
  }

  /// Sets the phase of the button, and reports it through
  /// ``SwiftUI/EnvironmentValues/speechInputPhaseReport``.
  ///
  /// - Parameter newPhase: The new phase.
  private func show(_ newPhase: Phase) {
    phase = newPhase
    reportPhase?(newPhase)
  }
}

extension EnvironmentValues {
  /// The ``ObservationReport`` that gets each phase of the nearest
  /// ``SpeechInputButton``, or `nil`.
  ///
  /// The button calls the report in the same step as the change of its phase.
  /// Each new input level of a session is a change of its phase.
  @Entry var speechInputPhaseReport: ObservationReport<SpeechInputButton.Phase>? = nil
}

#Preview("Microphone") {
  @Previewable @State var text = AttributedString()
  SpeechInputButton()
    .environment(\.speechTranscriber, SystemSpeechTranscriber())
    .environment(\.promptText, $text)
}
