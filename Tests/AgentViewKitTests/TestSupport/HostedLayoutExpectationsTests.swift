import AgentViewKitTestSupport
import SwiftUI
import Testing

/// Tests for ``HostedLayoutExpectations``.
@Suite(.hostedSerially) @MainActor struct HostedLayoutExpectationsTests {
  /// The number of sentences of ``longText``.
  static let sentenceCount = 4

  /// A text that wraps to many lines at a narrow width.
  static let longText = String(
    repeating: "The agent wants to read the files of the project and run the tests. ", count: sentenceCount)

  /// The usual width of the views of the tests, in points.
  static let width: CGFloat = 480

  @Test func aWrappedTextWithNoFixedSizePasses() {
    HostedLayoutExpectations.expectMinimumHeightFitsWidth(of: Text(Self.longText), width: Self.width)
  }

  @Test func aWrappedTextWithAFixedVerticalSizeFails() {
    withKnownIssue {
      HostedLayoutExpectations.expectMinimumHeightFitsWidth(
        of: Text(Self.longText).fixedSize(horizontal: false, vertical: true), width: Self.width)
    }
  }
}
