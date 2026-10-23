#if DEBUG
  import AgentViewKit
  import AgentViewKitTestSupport
  import DemoSupport
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// Tests of the window size of the demo app (^66has33).
  ///
  /// The demo UI test sends "hello" and finds each row of the first turn in
  /// the accessibility tree. The rows are in a lazy stack, so a row is in the
  /// tree only when the list lays it out. While the in-memory agent asks for a
  /// sign-in, the bottom bar of the thread holds the state banner, the
  /// sign-in card and the composer. In a window of the ideal size of its
  /// content (900 by 572 points in a failed run), the list had less than 100
  /// points, and the rows of the turn were not all in view.
  @Suite(.serialized, .hostedSerially) @MainActor struct ACPWindowLayoutHostedTests {
    /// The text of the prompt of the demo UI test.
    static let promptText = "hello"

    /// The number of transcript entries of the first turn of the in-memory
    /// agent: the user message, the reply and the plan.
    static let firstTurnEntryCount = 3

    /// Tells whether the first turn of the in-memory agent ended: the agent
    /// is idle and the transcript holds each entry of the turn.
    ///
    /// - Parameter session: The session model.
    /// - Returns: `true` after the end of the first turn.
    static func firstTurnEnded(in session: SessionModel) -> Bool {
      guard case .idle = session.agentState else { return false }
      return session.transcript.count == firstTurnEntryCount
    }

    @Test func theListOfTheDefaultWindowShowsEachRowOfTheFirstTurn() async throws {
      let agent = try await DemoAgent.makeInProcess(options: DemoAgentTests.inMemoryOptions)
      let opened = DemoAgentSignInTests.OpenedSessions()
      try await agent.openSession { opened.sessions.append($0) }
      let session = try #require(opened.sessions.first)
      let harness = HostedViewHarness(
        ACPWindowReplica(session: session, connection: agent.connection),
        size: DemoWindowLayout.defaultSize, styleMask: ACPWindowReplica.titledStyle)
      defer { harness.close() }
      harness.render()

      _ = try await session.prompt([.text(TextContent(text: Self.promptText))])
      await harness.render { Self.firstTurnEnded(in: session) }

      let list = try #require(harness.frame(identifier: ConversationLayout.listIdentifier))
      let rowsOutOfView = session.transcript.map(\.rowKey).filter { key in
        guard let row = harness.frame(identifier: ItemRow.identifier(for: key)) else { return true }
        return !list.contains(row)
      }
      #expect(rowsOutOfView.isEmpty, "The list \(list) does not show the rows \(rowsOutOfView).")
      await agent.stop()
    }
  }
#endif
