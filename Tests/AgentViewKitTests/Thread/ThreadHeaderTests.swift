import AgentViewKitTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// Tests for the header slot of a thread (TestudoApp D208 (i)): the host
/// view of `threadHeader(_:)` above the transcript.
///
/// Each test lays out a thread view in an `NSHostingView` with no window, so
/// no test shows a window or takes the focus.
@MainActor struct ThreadHeaderTests {
  /// The width of the thread of the tests.
  static let width: CGFloat = 900

  /// The height of the thread of the tests.
  static let height: CGFloat = 400

  /// A production change that fails this test: the thread does not read
  /// the header of the environment, or does not show it in the top bar.
  @Test func theHeaderSlotShowsTheHostView() {
    let record = SlotProbeRecord()

    StyleViewHost.layOut(
      AgentThreadView(session: ReadOnlyThreadTests.readOnlyModel()) { EmptyView() }
        .threadHeader { SlotProbe(record: record) }
        .frame(width: Self.width, height: Self.height))

    #expect(record.isShown)
  }

  /// A production change that fails this test: the thread hides the header
  /// while it shows the unavailable message.
  @Test func theHeaderStaysInTheUnavailableState() {
    let record = SlotProbeRecord()

    StyleViewHost.layOut(
      AgentThreadView(session: ReadOnlyThreadTests.readOnlyModel()) { EmptyView() }
        .threadHeader { SlotProbe(record: record) }
        .threadUnavailable(ThreadUnavailableTests.message)
        .frame(width: Self.width, height: Self.height))

    #expect(record.isShown)
  }
}
