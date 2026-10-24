@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorStyle
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Checks the surface of a ``RequestDeck`` in a window: the deck has no fill
/// in content and in the bar, and a card in the composer slot of
/// ``AgentThreadView`` is in the floating controls of the thread (TestudoApp
/// `features/style.md`, "How the steps apply").
///
/// The pixel tests read the cache of a window, because each card can take
/// the VoiceOver focus, so `ImageRenderer` draws nothing for it
/// (``ContentEdgeHostedProbe``). The cache shows no glass,
/// so the backdrop shows behind a deck with no fill, also on glass.
@Suite(.serialized, .hostedSerially) @MainActor struct RequestDeckSurfaceHostedTests {
  /// The size of the window. The deck fills the width.
  static let size = RequestDeckSurfaceTests.size

  /// The deck of ``RequestDeckSurfaceTests/session`` in content.
  ///
  /// The deck pads its cards with the medium spacing of the style. The
  /// negative padding at the leading and trailing edges puts the edge of the
  /// card on the edge of the window, as the edge check needs.
  static var deckInContent: some View {
    RequestDeck(session: RequestDeckSurfaceTests.session)
      .padding(.horizontal, -EditorStyle.default.spacing.m)
  }

  /// The deck of ``RequestDeckSurfaceTests/session`` in a
  /// `FloatingGlassContainer`, as in the composer slot of
  /// ``AgentThreadView``.
  static var deckInBar: some View {
    FloatingGlassContainer(spacing: EditorStyle.default.spacing.s) {
      RequestDeck(session: RequestDeckSurfaceTests.session)
    }
  }

  @Test(arguments: ContentEdgeHostedProbe.reduceTransparencyValues)
  func inContentTheBackdropShowsInsideTheEdgeOfTheCard(reducesTransparency: Bool) throws {
    try ContentEdgeHostedProbe.expectBackdropShowsInsideTheEdge(
      of: Self.deckInContent, reducesTransparency: reducesTransparency, size: Self.size)
  }

  @Test(arguments: ContentEdgeHostedProbe.reduceTransparencyValues)
  func inTheBarTheBackdropShowsBehindTheCard(reducesTransparency: Bool) throws {
    let rendered = try ContentEdgeHostedProbe.pixels(
      of: Self.deckInBar, backdrop: .behind, reducesTransparency: reducesTransparency, size: Self.size)

    #expect(rendered.contains(GlassRenderProbeTests.backdrop))
  }

  @Test func aCardInTheComposerSlotIsInTheFloatingControlsOfTheThread() throws {
    let session = RequestDeckSurfaceTests.session
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
