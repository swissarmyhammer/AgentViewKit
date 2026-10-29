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

  /// Each action of a request card, and its button style in the bar. A glass
  /// button on the glass of the deck is glass on glass (EditorKit
  /// `style.md`, "Buttons on glass"), so each style is bordered. The
  /// accent is only for the selection and the focus, so the primary action
  /// has no prominent style (card ^k06v4gt).
  ///
  /// It is `nonisolated` because the arguments of a test use it.
  nonisolated static let barStyles: [(action: RequestAction, style: RequestActionStyle)] = [
    (.primary, .bordered),
    (.secondary, .bordered),
    (.standard, .bordered),
  ]

  /// Each action of a request card, and its button style in content. The
  /// primary and the secondary action use the glass style, and a standard
  /// action keeps the style of its environment.
  ///
  /// It is `nonisolated` because the arguments of a test use it.
  nonisolated static let contentStyles: [(action: RequestAction, style: RequestActionStyle)] = [
    (.primary, .glass),
    (.secondary, .glass),
    (.standard, .inherited),
  ]

  /// Each action, and its button style in a bar with no glass surface, for
  /// example the state banner and the login card in the bottom bar of a
  /// thread. The content scrolls under the bar, so each action uses the glass
  /// style (EditorKit `style.md`, rule 4).
  ///
  /// It is `nonisolated` because the arguments of a test use it.
  nonisolated static let barWithoutGlassStyles: [(action: RequestAction, style: RequestActionStyle)] = [
    (.primary, .glass),
    (.secondary, .glass),
    (.standard, .glass),
  ]

  @Test(arguments: barStyles)
  func inTheBarAnActionOfACardUsesABorderedStyle(action: RequestAction, style: RequestActionStyle) {
    #expect(RequestDeckPlace.bar.style(of: action) == style)
  }

  @Test(arguments: barWithoutGlassStyles)
  func inABarWithNoGlassAnActionUsesAGlassStyle(action: RequestAction, style: RequestActionStyle) {
    #expect(RequestDeckPlace.barWithoutGlass.style(of: action) == style)
  }

  @Test(arguments: [false, true])
  func aDeclaredPlaceIsThePlaceOfTheButtonsInAndOutOfAFloatingContainer(isInContainer: Bool) {
    let place = RequestDeckPlace(declared: .barWithoutGlass, isInFloatingGlassContainer: isInContainer)

    #expect(place == .barWithoutGlass)
  }

  @Test func withNoDeclaredPlaceTheButtonsInAFloatingContainerAreInTheBar() {
    #expect(RequestDeckPlace(declared: nil, isInFloatingGlassContainer: true) == .bar)
  }

  @Test func withNoDeclaredPlaceTheButtonsOutOfAFloatingContainerAreInContent() {
    #expect(RequestDeckPlace(declared: nil, isInFloatingGlassContainer: false) == .content)
  }

  @Test(arguments: contentStyles)
  func inContentAnActionUsesTheGlassStyleOrItsEnvironment(action: RequestAction, style: RequestActionStyle) {
    #expect(RequestDeckPlace.content.style(of: action) == style)
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
