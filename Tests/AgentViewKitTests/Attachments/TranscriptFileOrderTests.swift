import Foundation
import Testing

@testable import AgentViewKit

/// Tests for the transcript order of the files that a thread shows
/// (``TranscriptFileOrder``, card ^4138tmp).
///
/// Each file view places its file with the position of its row in the
/// transcript and its frame in that row. The order sorts by the row, then
/// from the top, then from the leading edge. A view outside each row, such
/// as a chip in the composer slot, comes after the rows.
@Suite @MainActor struct TranscriptFileOrderTests {
  /// The attachment of the kit. FoundationModelsACP has a type of the same
  /// name.
  typealias Attachment = AgentViewKit.Attachment

  /// The side of the frame of each placed file view, in points.
  static let side: CGFloat = 20

  /// A file with a name of its own.
  ///
  /// - Parameter name: The file name.
  /// - Returns: The attachment.
  static func file(_ name: String) -> Attachment {
    Attachment(url: URL(filePath: "/tmp/avk-order/\(name)"))
  }

  /// A frame at a point, with the side ``side``.
  ///
  /// - Parameters:
  ///   - x: The leading edge.
  ///   - y: The top edge.
  /// - Returns: The frame.
  static func frame(x: CGFloat = 0, y: CGFloat = 0) -> CGRect {
    CGRect(x: x, y: y, width: side, height: side)
  }

  /// The file names of the order, in transcript order.
  ///
  /// - Parameter order: The order.
  /// - Returns: The names.
  static func names(of order: TranscriptFileOrder) -> [String] {
    order.files.map(\.name)
  }

  @Test func filesSortByTheirRowInTheTranscript() {
    let order = TranscriptFileOrder()

    order.place(Self.file("late"), row: 4, frame: Self.frame(), view: UUID())
    order.place(Self.file("early"), row: 1, frame: Self.frame(y: Self.side), view: UUID())

    #expect(Self.names(of: order) == ["early", "late"])
  }

  @Test func filesOfOneRowSortFromTheTop() {
    let order = TranscriptFileOrder()

    order.place(Self.file("lower"), row: 2, frame: Self.frame(y: Self.side), view: UUID())
    order.place(Self.file("upper"), row: 2, frame: Self.frame(x: Self.side), view: UUID())

    #expect(Self.names(of: order) == ["upper", "lower"])
  }

  @Test func filesOfOneLineSortFromTheLeadingEdge() {
    let order = TranscriptFileOrder()

    order.place(Self.file("trailing"), row: 2, frame: Self.frame(x: Self.side), view: UUID())
    order.place(Self.file("leading"), row: 2, frame: Self.frame(), view: UUID())

    #expect(Self.names(of: order) == ["leading", "trailing"])
  }

  @Test func aFileOutsideEachRowComesAfterTheRows() {
    let order = TranscriptFileOrder()

    order.place(Self.file("composer"), row: nil, frame: Self.frame(), view: UUID())
    order.place(Self.file("row"), row: 7, frame: Self.frame(y: Self.side), view: UUID())

    #expect(Self.names(of: order) == ["row", "composer"])
  }

  /// One file can show in two places. The order holds it one time, at its
  /// first place.
  @Test func aFileThatShowsTwiceHoldsItsFirstPlace() {
    let order = TranscriptFileOrder()

    order.place(Self.file("twice"), row: 3, frame: Self.frame(), view: UUID())
    order.place(Self.file("between"), row: 2, frame: Self.frame(), view: UUID())
    order.place(Self.file("twice"), row: 1, frame: Self.frame(), view: UUID())

    #expect(Self.names(of: order) == ["twice", "between"])
  }

  /// A new frame of the same view moves the file.
  @Test func aViewThatPlacesItsFileAgainMovesIt() {
    let order = TranscriptFileOrder()
    let view = UUID()

    order.place(Self.file("moving"), row: nil, frame: Self.frame(y: Self.side), view: view)
    order.place(Self.file("still"), row: nil, frame: Self.frame(x: Self.side), view: UUID())
    order.place(Self.file("moving"), row: nil, frame: Self.frame(), view: view)

    #expect(Self.names(of: order) == ["moving", "still"])
  }

  @Test func aViewOutsideEachRowThatGoesAwayLeavesTheOrder() {
    let order = TranscriptFileOrder()
    let view = UUID()
    order.place(Self.file("composer"), row: nil, frame: Self.frame(), view: view)

    order.remove(view: view)

    #expect(order.files.isEmpty)
  }

  /// A lazy list lets a row go when it scrolls away, and the transcript
  /// still holds its file. So the file keeps its place, and a range over the
  /// row still reaches it.
  @Test func aViewOfARowThatGoesAwayKeepsItsFile() {
    let order = TranscriptFileOrder()
    let view = UUID()
    order.place(Self.file("scrolled"), row: 0, frame: Self.frame(), view: view)

    order.remove(view: view)

    #expect(Self.names(of: order) == ["scrolled"])
  }
}
