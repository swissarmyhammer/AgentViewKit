import EditorTestSupport
import SwiftUI
import Testing

/// Tests of the spinner count of a hosted view, which the tests of the tool
/// call row and of the plan use.
@Suite(.serialized, .hostedSerially) @MainActor struct HarnessProgressIndicatorTests {
  @Test func aProgressViewCountsAsOneProgressIndicator() {
    let harness = HostedViewHarness(ProgressView().controlSize(.mini))
    defer { harness.close() }
    harness.render()

    #expect(harness.progressIndicatorCount() == 1)
  }

  @Test func aTextHasNoProgressIndicator() {
    let harness = HostedViewHarness(Text(verbatim: "Done"))
    defer { harness.close() }
    harness.render()

    #expect(harness.progressIndicatorCount() == 0)
  }
}
