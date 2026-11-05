@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorStyle
import EditorTestSupport
import SwiftUI

/// The composer of the `composer-field-recording` images: the idle composer
/// with its dictation button in a session that runs, its symbol filled to the
/// input level of ``level`` (^dj4hchg).
///
/// The gallery mounts the composer one time for each look, so each look gets
/// a new transcriber and a new recorder of the phases of the button
/// (``makeComposer()``). The settle step (``startRecording(in:)``) presses the
/// button through accessibility, as VoiceOver does, feeds one input level and
/// waits until the button shows it.
@MainActor final class RecordingComposer {
  /// The input level that the image shows: most of the full level, so the
  /// fill of the symbol is plain to see.
  static let level = 0.7

  /// The transcriber of the composer that the gallery mounted last.
  private var transcriber = FakeSpeechTranscriber()

  /// The phases of the dictation button of the composer that the gallery
  /// mounted last.
  private var phases = ReportRecorder<SpeechInputButton.Phase>()

  /// A new idle composer with a new transcriber, on the glass of the
  /// composer slot of a thread, over text.
  ///
  /// - Returns: The view to mount.
  func makeComposer() -> some View {
    transcriber = FakeSpeechTranscriber()
    phases = ReportRecorder<SpeechInputButton.Phase>()
    let composer = FloatingGlassContainer(spacing: GlassSnapshotTests.spacing) {
      SnapshotFixtures.composer(for: SnapshotFixtures.idleSession)
        .speechTranscriber(transcriber)
        .environment(\.speechInputPhaseReport, phases.report)
    }
    return GlassSnapshotTests.overText(composer)
  }

  /// Presses the dictation button of `mount`, feeds ``level`` to the session
  /// that the press starts, and waits until the button shows the level.
  ///
  /// - Parameter mount: The window and the hosting view of the composer.
  /// - Throws: The error of the press.
  func startRecording(in mount: ReviewMount) async throws {
    _ = try AccessibilityAction.press.perform(on: SpeechInputButton.identifier, in: mount.window)
    let transcriber = transcriber
    await ObservationWait.until { transcriber.isRunning }
    transcriber.feed(level: Self.level)
    let phases = phases
    await mount.render { phases.values.last == .recording(level: Self.level) }
  }
}
