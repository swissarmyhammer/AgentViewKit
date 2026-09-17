#if DEBUG
  import AgentViewKit
  import AgentViewKitFoundationModels
  import AgentViewKitTestSupport
  import FoundationModels
  import SwiftUI
  import Testing

  @Suite(.serialized, .hostedSerially) @MainActor struct AgentTranscriptViewHostedTests {
    /// A size that shows each row of the full transcript.
    static let tallSize = CGSize(width: 480, height: 1_200)

    /// The ids of the rows that the full transcript gives, in order.
    static let rowIDs = [
      TranscriptSamples.instructionsID, TranscriptSamples.promptID, TranscriptSamples.reasoningID,
      TranscriptSamples.toolCallID, TranscriptSamples.responseID,
    ]

    /// The row elements of the harness, in order.
    ///
    /// - Parameter harness: The harness that shows the view.
    /// - Returns: The identifier of each row element.
    static func rowIdentifiers<Content: View>(in harness: HostedViewHarness<Content>) -> [String] {
      harness.accessibilityElements()
        .compactMap(\.identifier)
        .filter { $0.hasPrefix(ItemRow.identifierPrefix) }
    }

    @Test func eachMappedItemMountsOneRow() throws {
      let view = AgentTranscriptView(transcript: try TranscriptSamples.fullTranscript())
      let harness = HostedViewHarness(view, size: Self.tallSize)
      defer { harness.close() }
      harness.pump()

      #expect(Self.rowIdentifiers(in: harness) == Self.rowIDs.map(ItemRow.identifier(for:)))
    }

    @Test func theThreadHoldsTheMappedItems() throws {
      let transcript = try TranscriptSamples.fullTranscript()
      let thread = AgentTranscriptView.thread(for: transcript)

      #expect(thread.items.map(\.id) == Self.rowIDs)
      #expect(thread.state == .idle(nil))
    }
  }
#endif
