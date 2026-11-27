#if DEBUG
  import AgentViewKitTestSupport
  import AppKit
  import EditorCommandsUI
  import EditorTestSupport
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  @testable import AgentViewKit

  /// The frames of the one row of a short thread after the first scroll to
  /// the bottom of the list (task ^pc1w14d).
  ///
  /// The hosted test `AgentItemFocusHostedTests` reads the frame of the focus
  /// scope of a user message and the accessibility frames of the message and
  /// of its send state. The scope frame must hold both frames.
  ///
  /// The thread is in a window of ``HostedViewHarness`` that is never
  /// ordered in: no window shows, and no window takes the focus.
  @MainActor @Suite(.serialized) struct ConversationShortListTests {
    /// The size of the window.
    static let windowSize = CGSize(width: 480, height: 480)

    /// The `messageId` of the user message.
    static let messageID = "short-list-message"

    /// A production change that fails this test: the first scroll to the
    /// bottom of a short list keeps the row of the message in the scroll
    /// position, and the accessibility frames of the message are not where
    /// the list draws the row.
    @Test func theRowOfTheOneMessageIsInTheWindow() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let model = session.model
      let harness = HostedViewHarness(size: Self.windowSize) {
        AgentThreadView(session: model, connection: session.connection) {}
          .commandSystem(CommandSystem())
          .transaction { $0.disablesAnimations = true }
      }
      defer { harness.close() }
      harness.render()

      try await session.sendUpdate(
        WireBlockJSON.makeChunk(
          "user_message_chunk", messageID: Self.messageID, block: WireBlockJSON.makeText("Hello")))
      await ObservationWait.until { !model.transcript.isEmpty }
      PendingRunLoopBlocks.run()
      harness.render()

      let key = try #require(model.transcript.first).rowKey
      let window = harness.window.frame
      let message = try #require(harness.frame(identifier: MessageRole.user.messageIdentifier(for: key)))
      let sendState = try #require(harness.frame(identifier: UserMessageView.sendStateIdentifier(for: key)))
      #expect(window.contains(message), "window \(window), message \(message)")
      #expect(window.contains(sendState), "window \(window), send state \(sendState)")
    }
  }
#endif
