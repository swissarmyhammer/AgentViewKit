@testable import AgentViewKit
import EditorStyle
import EditorTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Checks that a card in the composer slot of ``AgentThreadView`` is in the
/// floating controls of the thread (EditorKit `style.md`, "How the steps
/// apply").
@Suite(.serialized, .hostedSerially) @MainActor struct RequestDeckSurfaceHostedTests {
  /// The size of each render.
  static let size = CGSize(width: 320, height: 320)

  /// A code-built session model that holds one form elicitation.
  static var session: SessionModel {
    .preview(pendingElicitations: [PreviewFixtures.formElicitation])
  }

  /// The deck of ``session`` in a
  /// `FloatingGlassContainer`, as in the composer slot of
  /// ``AgentThreadView``.
  static var deckInBar: some View {
    FloatingGlassContainer(spacing: EditorStyle.default.spacing.s) {
      RequestDeck(session: session)
    }
  }

  @Test func aCardInTheComposerSlotIsInTheFloatingControlsOfTheThread() throws {
    let session = Self.session
    let request = try #require(session.pendingRequests.first)
    let harness = HostedViewHarness(size: Self.size) {
      AgentThreadView(session: session) {
        RequestDeck(session: session)
      }
    }
    defer { harness.close() }
    harness.render()

    let identifiers = harness.elements(under: AgentThreadLayout.floatingControlsIdentifier).compactMap(\.identifier)
    #expect(identifiers.contains(RequestDeck.identifier(for: request.id.uuidString)))
  }
}
