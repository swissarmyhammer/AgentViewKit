import CoreGraphics
import Testing

@testable import AgentViewKit

/// Tests for the layout of ``BlockHeader``: the title, the line and the
/// buttons on one line when they fit, and in a column when they do not.
///
/// The tests read the frames that ``BlockHeaderLayout`` gives for fixed
/// sizes, with no view, so no test shows a window or takes the focus.
@MainActor struct BlockHeaderTests {
  /// The layout of the tests: 8 points between the title and the buttons,
  /// and a tile gap of 10 points around the line.
  static let layout = BlockHeaderLayout(spacing: 8, gap: 10)

  /// The size of the title of the tests.
  static let title = CGSize(width: 100, height: 14)

  /// The size of the buttons of the tests.
  static let actions = CGSize(width: 60, height: 22)

  /// The size of no buttons.
  static let noActions = CGSize.zero

  /// The height of the line of the tests.
  static let lineHeight: CGFloat = 1

  /// The width at which the title, the spacing and the buttons just fit.
  static let limit = title.width + layout.spacing + actions.width

  /// The bounds of a header that is wider than the limit.
  static let wideBounds = CGRect(x: 20, y: 30, width: 300, height: actions.height)

  /// The bounds of a header that is narrower than the limit.
  static let narrowBounds = CGRect(x: 20, y: 30, width: 120, height: 50)

  /// The frames of the header of the tests in `bounds`.
  ///
  /// - Parameters:
  ///   - bounds: The bounds of the header.
  ///   - actions: The size of the buttons.
  /// - Returns: The frames of the title, the line and the buttons.
  static func frames(in bounds: CGRect, actions: CGSize = actions) -> BlockHeaderLayout.Frames {
    layout.frames(title: title, lineHeight: lineHeight, actions: actions, in: bounds)
  }

  // MARK: - The decision

  @Test func theHeaderFitsOnOneLineAtTheLimit() {
    let fits = BlockHeaderLayout.fitsOnOneLine(
      titleWidth: Self.title.width, actionsWidth: Self.actions.width, spacing: Self.layout.spacing,
      available: Self.limit)

    #expect(fits)
  }

  @Test func theHeaderFitsOnOneLineInMoreThanTheLimit() {
    let fits = BlockHeaderLayout.fitsOnOneLine(
      titleWidth: Self.title.width, actionsWidth: Self.actions.width, spacing: Self.layout.spacing,
      available: Self.limit + 1)

    #expect(fits)
  }

  @Test func theHeaderDoesNotFitOnOneLineInLessThanTheLimit() {
    let fits = BlockHeaderLayout.fitsOnOneLine(
      titleWidth: Self.title.width, actionsWidth: Self.actions.width, spacing: Self.layout.spacing,
      available: Self.limit - 1)

    #expect(!fits)
  }

  // MARK: - A wide header

  @Test func inAWideHeaderTheTitleAndTheButtonsHaveTheSameVerticalCenter() {
    let frames = Self.frames(in: Self.wideBounds)

    #expect(frames.title.midY == frames.actions.midY)
  }

  @Test func inAWideHeaderTheTitleIsAtTheLeadingEdge() {
    let frames = Self.frames(in: Self.wideBounds)

    #expect(frames.title.minX == Self.wideBounds.minX)
  }

  @Test func inAWideHeaderTheButtonsAreAtTheTrailingEdge() {
    let frames = Self.frames(in: Self.wideBounds)

    #expect(frames.actions.maxX == Self.wideBounds.maxX)
  }

  @Test func inAWideHeaderTheLineIsBelowTheTitleAndTheButtons() {
    let frames = Self.frames(in: Self.wideBounds)

    #expect(frames.line.minY > max(frames.title.maxY, frames.actions.maxY))
  }

  @Test func inAWideHeaderTheLineIsInTheMiddleOfTheTileGapUnderTheRow() {
    let frames = Self.frames(in: Self.wideBounds)

    #expect(frames.line.midY == Self.wideBounds.minY + Self.actions.height + Self.layout.gap / 2)
  }

  @Test func inAWideHeaderTheLineHasTheFullWidth() {
    let frames = Self.frames(in: Self.wideBounds)

    #expect(frames.line.width == Self.wideBounds.width)
  }

  @Test func aWideHeaderIsAsHighAsItsHighestPart() {
    let size = Self.layout.size(
      title: Self.title, actions: Self.actions, width: Self.wideBounds.width)

    #expect(size == CGSize(width: Self.wideBounds.width, height: Self.actions.height))
  }

  @Test func aHeaderWithNoProposedWidthIsWide() {
    let size = Self.layout.size(title: Self.title, actions: Self.actions, width: nil)

    #expect(size == CGSize(width: Self.limit, height: Self.actions.height))
  }

  // MARK: - A narrow header

  @Test func inANarrowHeaderTheTitleIsAboveTheLine() {
    let frames = Self.frames(in: Self.narrowBounds)

    #expect(frames.title.maxY < frames.line.minY)
  }

  @Test func inANarrowHeaderTheButtonsAreBelowTheLine() {
    let frames = Self.frames(in: Self.narrowBounds)

    #expect(frames.actions.minY > frames.line.maxY)
  }

  @Test func inANarrowHeaderTheButtonsAreAtTheLeadingEdge() {
    let frames = Self.frames(in: Self.narrowBounds)

    #expect(frames.actions.minX == Self.narrowBounds.minX)
  }

  @Test func inANarrowHeaderTheLineIsInTheMiddleOfTheTileGapBetweenTheTitleAndTheButtons() {
    let frames = Self.frames(in: Self.narrowBounds)

    #expect(frames.line.midY == frames.title.maxY + Self.layout.gap / 2)
    #expect(frames.actions.minY == frames.title.maxY + Self.layout.gap)
  }

  @Test func inANarrowHeaderTheTitleIsNotWiderThanTheHeader() {
    let bounds = CGRect(x: 0, y: 0, width: Self.title.width / 2, height: 50)

    let frames = Self.frames(in: bounds)

    #expect(frames.title.width == bounds.width)
  }

  @Test func aNarrowHeaderIsAsHighAsTheTitleTheGapAndTheButtons() {
    let size = Self.layout.size(
      title: Self.title, actions: Self.actions, width: Self.narrowBounds.width)

    #expect(size.height == Self.title.height + Self.layout.gap + Self.actions.height)
  }

  // MARK: - No buttons

  @Test func aHeaderWithNoButtonsStaysOnOneLine() {
    let bounds = CGRect(x: 0, y: 0, width: Self.title.width / 2, height: Self.title.height)

    let frames = Self.frames(in: bounds, actions: Self.noActions)

    #expect(frames.title == CGRect(x: 0, y: 0, width: bounds.width, height: Self.title.height))
  }
}
