#if DEBUG
  import AgentViewKitTestSupport
  import AppKit
  import EditorTestSupport
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  @testable import AgentViewKit

  /// The rows that a long conversation with a very tall first row shows
  /// after its first layout at the bottom (task ^pc1w14d).
  ///
  /// At the first layout, the lazy stack measures only the first rows, and
  /// it gives each other row an estimated height. When the first row is very
  /// tall, the estimate of one row is taller than the list. The list then
  /// went to the bottom of the estimated content, the stack laid out only
  /// the last row, and after that the list showed no row and reported no
  /// row in view. The Gallery detail of a recorded session showed no
  /// transcript row in this way.
  ///
  /// The list is in a window of ``HostedViewHarness`` that is never ordered
  /// in: no window shows, and no window takes the focus.
  ///
  /// The cases run one at a time. When two harnesses wait at the same time,
  /// the work of one harness can make a layout pass in the window of the
  /// other. That pass shows the rows, and the test then passes without the
  /// fix.
  @MainActor @Suite(.serialized) struct ConversationFirstLayoutTests {
    /// The size of the list: the size of the detail column of the Gallery
    /// window in the failed CI run.
    static let size = CGSize(width: 1475, height: 587)

    /// One line of the first row.
    static let promptLine = "The prompt of the task has many lines of text.\n"

    /// A transcript with a very tall first row: a user message of
    /// `promptLines` lines, then `toolCalls` tool calls, then `thoughts`
    /// thoughts, then a short agent answer.
    ///
    /// - Parameters:
    ///   - promptLines: The number of lines of the first row.
    ///   - toolCalls: The number of tool calls.
    ///   - thoughts: The number of thoughts.
    /// - Returns: The items of the transcript.
    static func transcript(promptLines: Int, toolCalls: Int, thoughts: Int) -> [PreviewTranscriptItem] {
      let prompt = String(repeating: promptLine, count: promptLines)
      let calls = (0..<toolCalls).map { index in
        PreviewTranscriptItem.toolCall(title: "Step \(index)", kind: .execute, status: .completed)
      }
      let notes = (0..<thoughts).map { index in PreviewTranscriptItem.thought("Thought \(index) of the agent.") }
      return [.user(prompt)] + calls + notes + [.agent("Done.")]
    }

    /// The shapes of the tests. With one element for each entry, the
    /// estimate of one row is taller than the list for the first shape. With
    /// two views for each entry (the code before 574ebdf9), the estimate is
    /// taller than the list for the second shape.
    static let shapes: [[PreviewTranscriptItem]] = [
      transcript(promptLines: 158, toolCalls: 40, thoughts: 40),
      transcript(promptLines: 625, toolCalls: 2, thoughts: 2),
    ]

    /// A production change that fails this test: the first scroll to the
    /// bottom goes to the bottom edge, which is where the list already is
    /// after the first layout. No later layout pass comes, and the list
    /// shows no row and reports no row in view.
    @Test(arguments: [0, 1])
    func theListShowsTheLastRowAfterTheFirstLayout(_ shape: Int) async throws {
      let session = SessionModel.preview(transcript: Self.shapes[shape])
      let anchors = ScrollAnchorManager()
      let harness = HostedViewHarness(
        ConversationView(session: session, anchors: anchors), size: Self.size)
      let lastRowKey = try #require(session.transcript.last).rowKey

      await ObservationWait.until { !anchors.visibleIDs.isEmpty }
      harness.render()

      let rows = harness.accessibilityElements().compactMap(\.identifier).filter {
        $0.hasPrefix(ItemRow.identifierPrefix)
      }
      #expect(rows.contains(ItemRow.identifier(for: lastRowKey)), "\(rows)")
      harness.close()
    }
  }
#endif
