#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import AppKit
  import EditorTestSupport
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// Tests that no banner of a bar of a thread covers the text of a row while
  /// the list is at rest (^zg9tysk).
  ///
  /// The list scrolls under its two bars (D113 answer 7), but at rest the
  /// insets of the list keep each row clear of the bars: the bottom inset
  /// grows with the banners of the bottom bar, the failure banner of the
  /// ``StateBanner`` and the sign-in card of the ``AgentLoginPrompt``, and an
  /// item that the list moves to stops below the top bar. A row goes under a
  /// bar only when the list is away from that end.
  ///
  /// Each test reads the accessibility frames of the row and of the bar after
  /// the layout passes of the window. The frame of the floating controls is
  /// the bottom bar, and the frame of the ``AgentInfoHeader`` is the top bar.
  @Suite(.serialized, .hostedSerially) @MainActor struct ThreadBarBannerOverlapHostedTests {
    /// The number of the agent messages of the failed turn of each test.
    /// Together they are taller than ``SnapshotFixtures/threadSize``, so the
    /// list scrolls, and the rows far from the bottom are not laid out when
    /// the list starts at the bottom.
    static let messageCount = 12

    /// The failed turn of
    /// ``SnapshotFixtures/failedTurnSession(messageCount:)`` with
    /// ``messageCount`` agent messages.
    static var failedTurnSession: SessionModel {
      SnapshotFixtures.failedTurnSession(messageCount: messageCount)
    }

    /// The thread of the failed turn of `session`, with the sign-in card of
    /// ``AgentAuthViewSurfaceHostedTests/connection``: the content of the
    /// `bottom-bar-buttons` snapshot images.
    ///
    /// - Parameters:
    ///   - session: The session of the failed turn.
    ///   - anchors: The manager of the scroll position of the list.
    /// - Returns: The thread view, with no animation.
    static func failedTurnThread(_ session: SessionModel, anchors: ScrollAnchorManager) -> some View {
      AgentThreadView(session: session, connection: AgentAuthViewSurfaceHostedTests.connection, anchors: anchors) {
        DefaultThreadComposer()
      }
      .transaction { $0.disablesAnimations = true }
    }

    /// Expects that the row of the entry with `key` does not intersect the
    /// element with `barIdentifier` in `harness`.
    ///
    /// - Parameters:
    ///   - key: The row key of the entry.
    ///   - barIdentifier: The accessibility identifier of the bar.
    ///   - harness: The harness that shows the thread.
    ///   - sourceLocation: The location of the caller, for the issue.
    /// - Throws: An issue when the row or the bar is not in the tree.
    static func expectRow<Content: View>(
      _ key: String, clearOf barIdentifier: String, in harness: HostedViewHarness<Content>,
      sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
      let row = try #require(harness.frame(identifier: ItemRow.identifier(for: key)), sourceLocation: sourceLocation)
      let bar = try #require(harness.frame(identifier: barIdentifier), sourceLocation: sourceLocation)

      #expect(!row.intersects(bar), "row \(row), bar \(bar)", sourceLocation: sourceLocation)
    }

    /// At rest, the list follows the bottom, and the last row ends above the
    /// failure banner and the sign-in card of the bottom bar.
    @Test func theLastRowAtRestIsAboveTheBannersOfTheBottomBar() throws {
      let session = Self.failedTurnSession
      let lastKey = try #require(session.transcript.last?.rowKey)
      let harness = HostedViewHarness(
        Self.failedTurnThread(session, anchors: ScrollAnchorManager()), size: SnapshotFixtures.threadSize)
      defer { harness.close() }
      harness.render()
      harness.render()

      #expect(harness.frame(identifier: StateBanner.showErrorIdentifier) != nil)
      #expect(harness.frame(identifier: AgentAuthView.identifier) != nil)
      try Self.expectRow(lastKey, clearOf: AgentThreadLayout.floatingControlsIdentifier, in: harness)
    }

    /// When the failure banner shows in the bottom bar of a list that follows
    /// the bottom, the bottom inset grows with the banner, and the last row
    /// moves up above the banner.
    @Test func theLastRowStaysAboveTheBottomBarWhenTheFailureBannerShows() async throws {
      let session = try await ConversationViewHostedTests.openSession(messages: ConversationViewHostedTests.scrollEntryCount)
      defer { session.close() }
      let model = session.model
      let harness = HostedViewHarness(size: SnapshotFixtures.threadSize) {
        AgentThreadView(session: model).transaction { $0.disablesAnimations = true }
      }
      defer { harness.close() }
      harness.render()

      model.appendError(code: .internalError, message: "The tool did not start.", data: nil)
      let lastKey = try #require(model.transcript.last?.rowKey)
      try await session.sendUpdate(
        SessionStateBannersHostedTests.stateUpdate(#""state": "idle", "stopReason": "refusal""#))
      await harness.render { model.agentState != nil }
      harness.render()

      #expect(harness.frame(identifier: StateBanner.showErrorIdentifier) != nil)
      try Self.expectRow(lastKey, clearOf: AgentThreadLayout.floatingControlsIdentifier, in: harness)
    }

    /// A move of the list to the first row, as the Show Error button, the
    /// minimap and the jump commands move it to an item, puts the row below
    /// the header of the top bar. The rows above the bottom of the list are
    /// not laid out when the move starts.
    @Test func aMoveToTheFirstRowPutsTheRowBelowTheTopBar() throws {
      let session = Self.failedTurnSession
      let firstKey = try #require(session.transcript.first?.rowKey)
      let anchors = ScrollAnchorManager()
      let harness = HostedViewHarness(Self.failedTurnThread(session, anchors: anchors), size: SnapshotFixtures.threadSize)
      defer { harness.close() }
      harness.render()

      anchors.noteJump(to: firstKey)
      anchors.onScroll(.item(firstKey))
      harness.render()

      try Self.expectRow(firstKey, clearOf: AgentInfoHeader.identifier, in: harness)
    }
  }
#endif
