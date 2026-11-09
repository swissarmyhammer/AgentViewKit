#if DEBUG
  @testable import AgentViewKit
  import AppKit
  import EditorStyle
  import EditorTestSupport
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// Tests that the rows of a thread line up with its bars (^0er2xf6).
  ///
  /// The list pads its content on the leading and the trailing edge by the
  /// bar inset that the host gives (`\.barInsets`). Thus the leading edge of
  /// each row surface stands under the leading edge of the header glass and
  /// of the composer glass.
  ///
  /// The row surface of a message is the frame of its ``ItemRow``: the item
  /// scope of the message, which holds the inner padding of the focus ring,
  /// starts at the leading edge of the row. The row surface of a tool call is
  /// its content tile (``ToolCallView/identifier(for:)``).
  ///
  /// The tests read the frames that the views report to AppKit after one
  /// layout pass of the window: the screen frame of the hosting view, the
  /// accessibility frame of the header glass (``AgentInfoHeader``), of the
  /// composer glass (``PromptFieldSurface``), of the first row and of the tool
  /// call card.
  @Suite(.serialized, .hostedSerially) @MainActor struct ThreadRowAlignmentHostedTests {
    /// The size of the window: tall enough that each row of the transcript
    /// is in view.
    static let windowSize = CGSize(width: 480, height: 800)

    /// The height of the editor of the composer of the tests, in points.
    static let editorHeight: CGFloat = 24

    /// The space between the leading edge of the hosting view and each
    /// surface that the tests compare.
    struct LeadingEdges {
      /// The space from the leading edge to the header glass.
      let header: CGFloat
      /// The space from the leading edge to the composer glass.
      let composer: CGFloat
      /// The space from the leading edge to the first row.
      let firstRow: CGFloat
      /// The space from the leading edge to the tool call card.
      let toolCall: CGFloat
    }

    /// Mounts a thread with a header, a composer whose field fills the width
    /// of the bottom bar, and a transcript whose first row is a message and
    /// whose last row is a tool call. Then reads the space between the
    /// leading edge of the hosting view and each surface.
    ///
    /// - Parameter insets: The bar inset that the host gives, or `nil` for a
    ///   host that writes no `.barInsets()`.
    /// - Returns: The spaces, in points.
    /// - Throws: An issue when a surface is not there.
    static func leadingEdges(insets: EdgeInsets?) throws -> LeadingEdges {
      try BarInsetThreadMount.measure(insets: insets, size: windowSize) {
        PromptInputView(text: .constant(AttributedString()), onSubmit: {}) { _ in
          Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: editorHeight)
        }
      } read: { frames in
        let transcript = frames.session.transcript
        let firstKey = try #require(transcript.first?.rowKey)
        let toolCallKey = try #require(transcript.last?.rowKey)
        let composer = try frames.frame(identifier: PromptFieldSurface.identifier)
        let firstRow = try frames.frame(identifier: ItemRow.identifier(for: firstKey))
        let toolCall = try frames.frame(identifier: ToolCallView.identifier(for: toolCallKey))
        return LeadingEdges(
          header: frames.leading(of: frames.header), composer: frames.leading(of: composer),
          firstRow: frames.leading(of: firstRow), toolCall: frames.leading(of: toolCall))
      }
    }

    /// With `.barInsets()`, the first row and the tool call card stand at
    /// the leading edge of the header glass, and so does the composer glass.
    ///
    /// A production change that fails this test: the list pads its content
    /// on the leading edge by a value that is not the leading bar inset, such
    /// as the row padding of the style.
    @Test func theRowsStandUnderTheLeadingEdgeOfTheBars() throws {
      let edges = try Self.leadingEdges(insets: EditorStyle.default.bar.insets)

      ThreadBarInsetsHostedTests.expectSpace(edges.composer, is: edges.header, "composer glass leading")
      ThreadBarInsetsHostedTests.expectSpace(edges.firstRow, is: edges.header, "first row leading")
      ThreadBarInsetsHostedTests.expectSpace(edges.toolCall, is: edges.header, "tool call card leading")
    }

    /// With no `.barInsets()`, the bars and the rows touch the leading edge
    /// of the thread.
    ///
    /// A production change that fails this test: the list pads its content
    /// on the leading edge when the host gives no bar inset.
    @Test func aHostWithNoBarInsetsPutsTheRowsAtTheLeadingEdge() throws {
      let edges = try Self.leadingEdges(insets: nil)

      ThreadBarInsetsHostedTests.expectSpace(edges.header, is: 0, "header glass leading")
      ThreadBarInsetsHostedTests.expectSpace(edges.composer, is: 0, "composer glass leading")
      ThreadBarInsetsHostedTests.expectSpace(edges.firstRow, is: 0, "first row leading")
      ThreadBarInsetsHostedTests.expectSpace(edges.toolCall, is: 0, "tool call card leading")
    }
  }
#endif
