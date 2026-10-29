#if DEBUG
  import AgentViewKit
  import AgentViewKitTestSupport
  import DemoSupport
  import EditorTestSupport
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// Tests of the window size of the demo app (^66has33), and of a host
  /// window that is shorter than the bars of the thread (^4yw9781).
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

    /// The width of the window of the repro of ^4yw9781, in points.
    static let shortWindowWidth: CGFloat = 1100

    /// The window heights of the repro of ^4yw9781, in points.
    ///
    /// At these heights, the bars of the thread are taller than the detail
    /// column while the in-memory agent asks for a sign-in. The list showed
    /// the short content of the first turn under the top bar, and it
    /// reported no visible row. The pin state and the scroll-to-bottom pill
    /// then changed in a loop, and AppKit stopped the constraint update of
    /// the window.
    nonisolated static let heightsShorterThanTheBars: [CGFloat] = [700, 760, 820]

    /// The hosted replica of the ACP window after the first turn of the
    /// in-memory agent.
    struct FirstTurn {
      /// The started in-memory agent.
      let agent: DemoAgent

      /// The session of the turn.
      let session: SessionModel

      /// The harness of the replica of the ACP window.
      let harness: HostedViewHarness<ACPWindowReplica>
    }

    /// Tells whether the first turn of the in-memory agent ended: the agent
    /// is idle and the transcript holds each entry of the turn.
    ///
    /// - Parameter session: The session model.
    /// - Returns: `true` after the end of the first turn.
    static func firstTurnEnded(in session: SessionModel) -> Bool {
      guard case .idle = session.agentState else { return false }
      return session.transcript.count == firstTurnEntryCount
    }

    /// Mounts the replica of the ACP window, sends the prompt of the demo UI
    /// test, and waits for the end of the first turn.
    ///
    /// The caller closes the harness and stops the agent.
    ///
    /// - Parameter size: The size of the window.
    /// - Returns: The agent, the session and the harness after the turn.
    static func sendThePrompt(in size: CGSize) async throws -> FirstTurn {
      let agent = try await DemoAgent.makeInProcess(options: DemoAgentFixtures.inMemoryOptions)
      let opened = DemoAgentFixtures.OpenedSessions()
      try await agent.openSession { opened.sessions.append($0) }
      let session = try #require(opened.sessions.first)
      let harness = HostedViewHarness(
        ACPWindowReplica(session: session, connection: agent.connection),
        size: size, styleMask: ACPWindowReplica.titledStyle)
      harness.render()

      _ = try await session.prompt([.text(TextContent(text: promptText))])
      await harness.render { firstTurnEnded(in: session) }
      return FirstTurn(agent: agent, session: session, harness: harness)
    }

    @Test func theListOfTheDefaultWindowShowsEachRowOfTheFirstTurn() async throws {
      let turn = try await Self.sendThePrompt(in: DemoWindowLayout.defaultSize)
      defer { turn.harness.close() }

      let list = try #require(turn.harness.frame(identifier: ConversationLayout.listIdentifier))
      let rowsOutOfView = turn.session.transcript.map(\.rowKey).filter { key in
        guard let row = turn.harness.frame(identifier: ItemRow.identifier(for: key)) else { return true }
        return !list.contains(row)
      }
      #expect(rowsOutOfView.isEmpty, "The list \(list) does not show the rows \(rowsOutOfView).")
      await turn.agent.stop()
    }

    /// The window of the harness catches the exception of a display cycle
    /// loop, so a loop fails this test and does not stop the test process.
    ///
    /// - Parameter height: The height of the window, in points.
    @Test(arguments: heightsShorterThanTheBars)
    func aWindowShorterThanTheBarsEndsTheLayoutOfTheFirstTurn(height: CGFloat) async throws {
      let size = CGSize(width: Self.shortWindowWidth, height: height)
      let turn = try await Self.sendThePrompt(in: size)
      defer { turn.harness.close() }

      #expect(turn.harness.displayCycleExceptionReason == nil)
      let missingRows = turn.session.transcript.map(\.rowKey).filter { key in
        turn.harness.element(identifier: ItemRow.identifier(for: key)) == nil
      }
      #expect(missingRows.isEmpty, "The accessibility tree has no rows \(missingRows).")
      await turn.agent.stop()
    }
  }
#endif
