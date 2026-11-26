import SwiftUI
import Testing

@testable import AgentViewKit

/// The spinner of an ``ActivityIndicator`` while a tool runs: EditorKit's
/// `EditorProgressView`, which always has an accessibility label
/// (Docs/decisions/focus-audit.md, "Raw controls").
///
/// Each test lays out the indicator in a window that is never ordered in
/// (``ControlProbe``), and reads its accessibility labels.
@MainActor @Suite struct ActivityIndicatorProgressTests {
  /// The name of the tool of each test.
  static let toolName = "Run swift test"

  /// A production change that fails this test: the spinner is a system
  /// `ProgressView` with no label in place of the EditorKit
  /// `EditorProgressView`, so VoiceOver reads the tool name with no word
  /// that the tool runs.
  @Test func theSpinnerOfARunningToolSaysThatTheToolRuns() async {
    let labels = await ControlProbe.labels(in: ActivityIndicator(state: .runningTool(Self.toolName)))

    #expect(labels.contains { $0.contains(ActivityIndicator.runningText) })
  }
}
