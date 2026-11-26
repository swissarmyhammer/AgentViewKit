#if DEBUG
  import AgentViewKitTestSupport
  import AppKit
  import EditorTestSupport
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  @testable import AgentViewKit

  /// The place of the last row of a thread at rest after its first layout,
  /// relative to the bottom bar of the thread (task ^pc1w14d).
  ///
  /// The first scroll to the bottom goes to the bottom of the last row
  /// (``ConversationLayout/scrollToLastRow(_:rowKey:)``). That place is the
  /// top edge of the bottom bar. When the list stops there, the frame of the
  /// row touches the frame of the bar, and the hosted test
  /// `ThreadBarBannerOverlapHostedTests` finds that they intersect. At rest,
  /// the list must stop at the end of its content, so that the bottom row
  /// padding is in view between the row and the bar.
  ///
  /// The thread is in a window of ``HostedViewHarness`` that is never
  /// ordered in: no window shows, and no window takes the focus.
  @MainActor @Suite(.serialized) struct ConversationBottomBarTests {
    /// The size of the thread.
    static let size = CGSize(width: 480, height: 640)

    /// The number of the agent messages. Together they are taller than the
    /// thread, so the list scrolls.
    static let messageCount = 12

    /// A failed turn: ``messageCount`` agent messages, an idle state with an
    /// error stop, and an error entry. The bottom bar shows the failure
    /// banner.
    ///
    /// - Returns: The session model.
    static func failedTurnSession() -> SessionModel {
      let messages = (1...messageCount).map { number in
        PreviewTranscriptItem.agent(
          "Step \(number): the import reads the next rows of the customer file, and skips each row that "
            + "has no email address. The count of the skipped rows goes to the log.")
      }
      let session = SessionModel.preview(
        transcript: messages + [.update(.stateUpdate(.idle(IdleStateUpdate(stopReason: .error))))])
      session.appendError(code: .internalError, message: "The tool did not start.", data: nil)
      return session
    }

    /// The sign-in method of the connection of the thread.
    static let signInMethod = AuthMethod.agent(
      AuthMethodAgent(
        methodId: AuthMethodId(rawValue: "tests-agent-login"), name: "Sign in with the agent",
        description: "The agent opens its sign-in page."))

    /// A connection that needs a sign-in, so the bottom bar shows the
    /// sign-in card above the failure banner.
    static var signInConnection: ConnectionModel {
      .preview(
        authState: .required([signInMethod]),
        initializeResponse: InitializeResponse(
          info: Implementation(name: "tests-agent", version: "1.0.0"),
          protocolVersion: ACPClient.supportedProtocolVersion, authMethods: [signInMethod]))
    }

    /// A production change that fails this test: the list stops at the
    /// bottom of the last row after the first scroll to the bottom. The row
    /// then touches the bottom bar.
    @Test func theLastRowAtRestEndsAboveTheBottomBar() async throws {
      let session = Self.failedTurnSession()
      let lastKey = try #require(session.transcript.last?.rowKey)
      let anchors = ScrollAnchorManager()
      let harness = HostedViewHarness(
        AgentThreadView(session: session, connection: Self.signInConnection, anchors: anchors) {
          DefaultThreadComposer()
        }
          .transaction { $0.disablesAnimations = true },
        size: Self.size)
      defer { harness.close() }
      harness.render()

      await ObservationWait.until { !anchors.visibleIDs.isEmpty }
      await RunLoopBlockFence.afterPendingBlocks()
      harness.render()
      harness.render()

      let row = try #require(harness.frame(identifier: ItemRow.identifier(for: lastKey)))
      let bar = try #require(harness.frame(identifier: AgentThreadLayout.floatingControlsIdentifier))
      #expect(!row.intersects(bar), "row \(row), bar \(bar)")
    }
  }
#endif
