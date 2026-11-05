@testable import AgentViewKit
import CoreGraphics
import SwiftUI
import Testing

/// Checks the surface of a ``RequestDeck`` in each place (EditorKit
/// `style.md`, "How the steps apply"), and the band of each card
/// that shows in the stack.
///
/// In a bar of floating controls, the deck is user input: it is on the
/// floating glass of the kit. In content, the deck has no glass and no fill.
struct RequestDeckSurfaceTests {
  /// The edge step of the band tests, in points.
  static let edgeStep: CGFloat = 8

  /// The frame of a card in the band tests.
  static let cardFrame = CGRect(x: 0, y: 0, width: 200, height: 120)

  /// The depth of the edge card in the band test.
  static let edgeDepth = 2

  @Test func outOfAFloatingContainerTheDeckIsInContent() {
    #expect(RequestDeckPlace(isInFloatingGlassContainer: false) == .content)
  }

  @Test func inAFloatingContainerTheDeckIsInTheBar() {
    #expect(RequestDeckPlace(isInFloatingGlassContainer: true) == .bar)
  }

  @Test func aLoneCardOnTheGlassOfTheDeckDrawsNoEdge() {
    #expect(!RequestDeckPlace.bar.drawsCardEdge(cardCount: 1))
  }

  @Test func withMoreCardsOnTheGlassOfTheDeckEachCardDrawsItsEdge() {
    #expect(RequestDeckPlace.bar.drawsCardEdge(cardCount: 2))
  }

  @Test(arguments: [1, 2])
  func inContentEachCardDrawsItsEdge(cardCount: Int) {
    #expect(RequestDeckPlace.content.drawsCardEdge(cardCount: cardCount))
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
