@testable import AgentViewKit
import AgentViewKitTestSupport
import CoreGraphics
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Checks the surface of a ``RequestDeck`` in each place (TestudoApp
/// `features/style.md`, "How the steps apply"), and the band of each card
/// that shows in the stack.
///
/// In a bar of floating controls, the deck is user input: it is on the
/// floating glass of the kit. In content, the deck has no glass and no fill.
struct RequestDeckSurfaceTests {
  /// The size of each render.
  static let size = CGSize(width: 320, height: 320)

  /// The center of each render. The deck is in the center of its `ZStack`,
  /// so this point is in the glass of a deck in the bar.
  static var centerPoint: CGPoint {
    CGPoint(x: size.width / 2, y: size.height / 2)
  }

  /// The edge step of the band tests, in points.
  static let edgeStep: CGFloat = 8

  /// The frame of a card in the band tests.
  static let cardFrame = CGRect(x: 0, y: 0, width: 200, height: 120)

  /// The depth of the edge card in the band test.
  static let edgeDepth = 2

  /// A code-built session model that holds one form elicitation.
  static var session: SessionModel {
    .preview(pendingElicitations: [PreviewFixtures.formElicitation])
  }

  /// The deck of ``session`` over the backdrop of ``GlassRenderProbeTests``.
  ///
  /// - Parameter inBar: Whether the deck is in a ``FloatingGlassContainer``,
  ///   as in the composer slot of ``AgentThreadView``.
  /// - Returns: The view.
  static func deck(inBar: Bool) -> some View {
    ZStack {
      GlassRenderProbeTests.backdrop
      if inBar {
        FloatingGlassContainer(spacing: AgentTheme.default.spacing.s) { RequestDeck(session: session) }
      } else {
        RequestDeck(session: session)
      }
    }
  }

  @Test func outOfAFloatingContainerTheDeckIsInContent() {
    #expect(RequestDeckPlace(floatingGlassContainerCount: 0) == .content)
  }

  @Test func inAFloatingContainerTheDeckIsInTheBar() {
    #expect(RequestDeckPlace(floatingGlassContainerCount: 1) == .bar)
  }

  /// Each action of a request card, and its button style in the bar. A glass
  /// button on the glass of the deck is glass on glass (TestudoApp
  /// `features/style.md`, "Buttons on glass"), so each style is bordered.
  ///
  /// It is `nonisolated` because the arguments of a test use it.
  nonisolated static let barStyles: [(action: RequestAction, style: RequestActionStyle)] = [
    (.primary, .borderedProminent),
    (.secondary, .bordered),
    (.standard, .bordered),
  ]

  /// Each action of a request card, and its button style in content. The
  /// actions keep their glass styles, and a standard action keeps the style
  /// of its environment.
  ///
  /// It is `nonisolated` because the arguments of a test use it.
  nonisolated static let contentStyles: [(action: RequestAction, style: RequestActionStyle)] = [
    (.primary, .glassProminent),
    (.secondary, .glass),
    (.standard, .inherited),
  ]

  @Test(arguments: barStyles)
  func inTheBarAnActionOfACardUsesABorderedStyle(action: RequestAction, style: RequestActionStyle) {
    #expect(RequestDeckPlace.bar.style(of: action) == style)
  }

  @Test(arguments: contentStyles)
  func inContentAnActionOfACardKeepsItsGlassStyle(action: RequestAction, style: RequestActionStyle) {
    #expect(RequestDeckPlace.content.style(of: action) == style)
  }

  /// The test compares the two renders only at ``centerPoint``. The render
  /// draws no card, because each card can take the VoiceOver focus
  /// (``ContentEdgeHostedProbe``). In the bar, it draws the glass of the
  /// deck as a band across the full width, in the center of the render. The
  /// center is far from the edge of the glass. The rim of a rounded glass
  /// changes after its first renders in the process, at a render that is not
  /// the same in each run (``RenderedPixels/isClose(to:at:tolerance:)``).
  @Test func inTheBarTheRenderDrawsTheGlassOfTheDeck() throws {
    let inBar = try #require(RenderedPixels(rendering: Self.deck(inBar: true), size: Self.size))
    let inContent = try #require(RenderedPixels(rendering: Self.deck(inBar: false), size: Self.size))

    #expect(!inBar.isClose(to: inContent, at: [Self.centerPoint]))
  }

  @Test func anEdgeCardShowsOnlyItsTopBandAndTheOutsetOfItsStroke() {
    let band = DeckCardBand(role: .edge(depth: Self.edgeDepth), edgeStep: Self.edgeStep)
    let outset = DeckCardBand.strokeOutset
    let shown = CGFloat(Self.edgeDepth) * Self.edgeStep

    let expected = CGRect(
      x: -outset, y: -outset, width: Self.cardFrame.width + 2 * outset, height: shown + outset)
    #expect(band.path(in: Self.cardFrame).boundingRect == expected)
  }

  @Test(arguments: [DeckCardRole.front, .waiting, .hidden])
  func aCardThatIsNotAnEdgeShowsItsWholeFrameAndTheOutsetOfItsStroke(role: DeckCardRole) {
    let band = DeckCardBand(role: role, edgeStep: Self.edgeStep)
    let outset = DeckCardBand.strokeOutset

    #expect(band.path(in: Self.cardFrame).boundingRect == Self.cardFrame.insetBy(dx: -outset, dy: -outset))
  }
}
