@testable import AgentViewKit
import EditorStyle
import EditorTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Checks the surface of a ``RequestDeck`` in a window: the deck has no fill
/// in content and in the bar, and a card in the composer slot of
/// ``AgentThreadView`` is in the floating controls of the thread (EditorKit
/// `style.md`, "How the steps apply").
///
/// The pixel tests capture a real window (``ContentEdgeHostedProbe``), where
/// the window server draws each card, which can take the VoiceOver focus, and
/// the floating glass of the deck in the bar. The backdrop shows behind a deck
/// with no fill, also on glass.
@Suite(.serialized, .hostedSerially) @MainActor struct RequestDeckSurfaceHostedTests {
  /// The size of each render.
  static let size = CGSize(width: 320, height: 320)

  /// The center of each render. The deck is in the center of its `ZStack`,
  /// so this point is in the glass of a deck in the bar.
  static var centerPoint: CGPoint {
    CGPoint(x: size.width / 2, y: size.height / 2)
  }

  /// A code-built session model that holds one form elicitation.
  static var session: SessionModel {
    .preview(pendingElicitations: [PreviewFixtures.formElicitation])
  }

  /// The deck of ``session`` over the backdrop of ``GlassRenderProbeTests``.
  ///
  /// - Parameters:
  ///   - inBar: Whether the deck is in a `FloatingGlassContainer`, as in the
  ///     composer slot of ``AgentThreadView``.
  ///   - backdrop: The color behind the deck.
  /// - Returns: The view.
  static func deck(inBar: Bool, backdrop: Color = GlassRenderProbeTests.backdrop) -> some View {
    ZStack {
      backdrop
      if inBar {
        FloatingGlassContainer(spacing: EditorStyle.default.spacing.s) { RequestDeck(session: session) }
      } else {
        RequestDeck(session: session)
      }
    }
  }

  /// The deck of ``session`` in content.
  ///
  /// The deck pads its cards with the medium spacing of the style. The
  /// negative padding at the leading and trailing edges puts the edge of the
  /// card on the edge of the window, as the edge check needs.
  static var deckInContent: some View {
    RequestDeck(session: session)
      .padding(.horizontal, -EditorStyle.default.spacing.m)
  }

  /// The deck of ``session`` in a
  /// `FloatingGlassContainer`, as in the composer slot of
  /// ``AgentThreadView``.
  static var deckInBar: some View {
    FloatingGlassContainer(spacing: EditorStyle.default.spacing.s) {
      RequestDeck(session: session)
    }
  }

  @Test func inContentTheBackdropShowsInsideTheEdgeOfTheCard() async throws {
    try await ContentEdgeHostedProbe.expectBackdropShowsInsideTheEdge(of: Self.deckInContent, size: Self.size)
  }

  /// The backdrop of the deck in the bar differs from
  /// ``GlassRenderProbeTests/backdrop`` in each channel, so that glass over
  /// the one looks different from glass over the other.
  static let otherBackdrop = Color(red: 0.9, green: 0.1, blue: 0.1)

  /// In the bar, the card is Liquid Glass that the window server draws: it
  /// shows the backdrop through it and tints it, so no pixel of the card keeps
  /// the exact color of the backdrop. The glass is not a fill: the same deck
  /// over another backdrop looks different at the center of the card.
  @Test func inTheBarTheBackdropShowsThroughTheGlassOfTheCard() async throws {
    let center = CaptureGeometry.pixel(at: Self.centerPoint)
    let centerPixel = CGRect(x: center.x, y: center.y, width: 1, height: 1)

    let overBackdrop = try await GlassRenderProbeTests.capture(of: Self.deck(inBar: true), size: Self.size)
    let overOther = try await GlassRenderProbeTests.capture(
      of: Self.deck(inBar: true, backdrop: Self.otherBackdrop), size: Self.size)

    #expect(try overBackdrop.cropped(to: centerPixel) != overOther.cropped(to: centerPixel))
  }

  /// In the bar, the window server draws the floating glass of the deck over
  /// the backdrop: the pixel at ``centerPoint``, in
  /// the glass of the deck in the bar, differs from the same pixel of the
  /// deck in content, which has no glass.
  @Test func inTheBarTheWindowDrawsTheGlassOfTheDeck() async throws {
    let size = Self.size
    let center = CaptureGeometry.pixel(at: Self.centerPoint)
    let centerPixel = CGRect(x: center.x, y: center.y, width: 1, height: 1)

    let inBar = try await GlassRenderProbeTests.capture(of: Self.deck(inBar: true), size: size)
    let inContent = try await GlassRenderProbeTests.capture(
      of: Self.deck(inBar: false), size: size)

    #expect(try inBar.cropped(to: centerPixel) != inContent.cropped(to: centerPixel))
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
