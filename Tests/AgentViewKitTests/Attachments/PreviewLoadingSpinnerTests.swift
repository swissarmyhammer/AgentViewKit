import SwiftUI
import Testing

@testable import AgentViewKit

/// The spinner of a preview that loads or writes its file: EditorKit's
/// `EditorProgressView`, which always has an accessibility label
/// (Docs/decisions/focus-audit.md, "Raw controls"). An attachment preview, a
/// sound block and a binary resource block show it.
@MainActor @Suite struct PreviewLoadingSpinnerTests {
  /// A production change that fails this test: the spinner is a system
  /// `ProgressView` with no label in place of the EditorKit
  /// `EditorProgressView`, so VoiceOver does not say that the preview loads.
  @Test func theSpinnerSaysThatThePreviewLoads() async {
    let labels = await ControlProbe.labels(in: PreviewLoadingSpinner())

    #expect(labels.contains(PreviewLoadingSpinner.label))
  }
}
