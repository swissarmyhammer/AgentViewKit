import AppKit
import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

@testable import AgentViewKit

/// One row of a thread, as ``ConversationView`` shows it, in a borderless
/// window that is never ordered in (card ^9ync5h3).
///
/// The host shows the ``TranscriptRowElement`` of the one entry of a
/// session, with the record of the row heights and the motion signal of a
/// thread. ``show(rowsMove:)`` sets the motion signal and lays the row out
/// again, so a test reads the row at rest and while the rows move. No
/// window shows, and no window takes the focus. The window has the light
/// appearance, so the text is dark on a clear background.
@MainActor final class StaticRowHost {
  /// The session whose one entry the host shows.
  let session: SessionModel

  /// The width of the row, in points.
  let width: CGFloat

  /// The record of the heights of the real row.
  let heights = TranscriptMeasuredRowHeights()

  /// The cache of the EditorKit models of the row, as a thread gives it.
  let cache = CodeBlockModelCache(limit: CodeBlockModelCache.threadLimit)

  /// The window of the host. It is never ordered in.
  private let window: NSWindow

  /// The host of the row.
  private let hosting: NSHostingView<AnyView>

  /// Shows the row of `item` at rest, at `width`.
  ///
  /// - Parameters:
  ///   - item: The transcript item of the one entry.
  ///   - width: The width of the row, in points.
  init(_ item: PreviewTranscriptItem, width: CGFloat) {
    session = .preview(transcript: [item])
    self.width = width
    hosting = NSHostingView(rootView: AnyView(EmptyView()))
    window = UnorderedWindow.make(holding: hosting, size: CGSize(width: width, height: width))
    window.appearance = NSAppearance(named: .aqua)
    show(rowsMove: false)
  }

  /// The entry of the row.
  var entry: TranscriptEntry {
    session.transcript[0]
  }

  /// Sets the motion signal of the thread, and lays the row out again.
  ///
  /// - Parameter rowsMove: Whether the rows of the thread move.
  func show(rowsMove: Bool) {
    hosting.rootView = AnyView(row(rowsMove: rowsMove))
    layOut()
  }

  /// Lays the row out at its fitting size in two passes: the first pass
  /// lays out the editors, and the second pass gives the host the size
  /// that the editors then have.
  func layOut() {
    for _ in 0..<Self.layoutPasses {
      hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
      hosting.layoutSubtreeIfNeeded()
    }
  }

  /// The number of layout passes of ``layOut()``.
  static let layoutPasses = 2

  /// Waits until the first parse of the text of the first block of the
  /// entry lands, and lays the row out again, so the real row shows the
  /// styles of the parse, such as the size of a heading.
  ///
  /// - Parameter markdown: The text of the first block of the entry.
  func awaitParse(of markdown: String) async throws {
    let id = EntryContentView.blockID(entryID: entry.rowKey, index: 0)
    let model = ResponseView.model(in: cache, id: id, markdown: markdown)
    guard let syntax = model.syntax else { throw StaticRowHostError.noSyntax }
    _ = await syntax.ensureParsed(upTo: model.state.version)
    layOut()
  }

  /// The height of the row, in points.
  var rowHeight: CGFloat {
    hosting.fittingSize.height
  }

  /// The number of EditorKit text views in the row: zero in the static
  /// form, and one for each text area in the real form.
  var textViewCount: Int {
    views(ofType: NSTextView.self, in: hosting).count
  }

  /// The row drawn into a bitmap at the size of the host.
  ///
  /// - Returns: The bitmap.
  func bitmap() throws -> NSBitmapImageRep {
    let rep = try requireBitmap()
    hosting.cacheDisplay(in: hosting.bounds, to: rep)
    return rep
  }

  /// A bitmap of the size of the host.
  ///
  /// - Returns: The bitmap.
  private func requireBitmap() throws -> NSBitmapImageRep {
    guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
      throw StaticRowHostError.noBitmap
    }
    return rep
  }

  /// The row of the entry, with the environment of a thread.
  ///
  /// - Parameter rowsMove: Whether the rows of the thread move.
  /// - Returns: The row at ``width``.
  private func row(rowsMove: Bool) -> some View {
    TranscriptRowElement(
      slot: TranscriptRowSlot(position: 0, entry: entry), isLast: false, lines: [])
      .frame(width: width)
      .fixedSize(horizontal: false, vertical: true)
      .environment(\.transcriptRowsMove, rowsMove)
      .environment(\.measuredRowHeights, heights)
      .environment(\.sessionModel, session)
      .environment(\.codeBlockModelCache, cache)
      .threadTextSelection()
      .transaction { $0.disablesAnimations = true }
  }
}

/// The failure of a ``StaticRowHost``.
enum StaticRowHostError: Error {
  /// The host gave no bitmap to draw into.
  case noBitmap

  /// The model of the text has no syntax coordinator.
  case noSyntax
}

/// The vertical places of the lines of text in a bitmap: each band of pixel
/// rows that holds dark pixels (card ^9ync5h3).
///
/// The text of a row is dark on a clear background. A band is a run of
/// pixel rows with at least one dark pixel. Two bitmaps whose bands stand at
/// the same pixel rows show their text lines at the same places, so a change
/// from one to the other moves no line.
enum InkBands {
  /// The largest luminance of a dark pixel.
  static let darkLuminance: CGFloat = 0.5

  /// The smallest alpha of a dark pixel.
  static let opaqueAlpha: CGFloat = 0.5

  /// The bands of dark pixel rows of `bitmap`, from the top.
  ///
  /// - Parameter bitmap: The bitmap.
  /// - Returns: The range of pixel rows of each band.
  static func bands(in bitmap: NSBitmapImageRep) -> [ClosedRange<Int>] {
    let rows = (0..<bitmap.pixelsHigh).map { y in hasInk(bitmap, row: y) }
    return rows.indices.compactMap { y -> ClosedRange<Int>? in
      guard rows[y], y == 0 || !rows[y - 1] else { return nil }
      let end = rows[y...].firstIndex(of: false) ?? rows.endIndex
      return y...(end - 1)
    }
  }

  /// Tells if a pixel row of `bitmap` holds a dark pixel.
  ///
  /// - Parameters:
  ///   - bitmap: The bitmap.
  ///   - y: The pixel row, from the top.
  /// - Returns: `true` when a pixel of the row is dark and opaque.
  static func hasInk(_ bitmap: NSBitmapImageRep, row y: Int) -> Bool {
    (0..<bitmap.pixelsWide).contains { x in
      guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return false }
      let luminance = (color.redComponent + color.greenComponent + color.blueComponent) / 3
      return color.alphaComponent >= opaqueAlpha && luminance <= darkLuminance
    }
  }

  /// Tells if two lists of bands stand at the same pixel rows.
  ///
  /// - Parameters:
  ///   - first: The bands of one bitmap.
  ///   - second: The bands of the other bitmap.
  ///   - tolerance: The largest difference of an edge of a band, in pixels.
  /// - Returns: `true` when the lists have the same count, and each edge of
  ///   each band is within `tolerance` of the edge in the other list.
  static func match(_ first: [ClosedRange<Int>], _ second: [ClosedRange<Int>], tolerance: Int) -> Bool {
    match(first, second, tolerance: tolerance, edges: [\.lowerBound, \.upperBound])
  }

  /// Tells if the bottom edges of two lists of bands stand at the same
  /// pixel rows: the lines of the two bitmaps have the same baselines.
  ///
  /// The bottom edge of a band is the lowest dark pixel row of a line: the
  /// baseline of a line with no descender, and the descender line of a
  /// line with one. A line in a font that EditorKit draws with a taller
  /// glyph, such as a level 1 heading, has another top edge, and still the
  /// same baseline.
  ///
  /// - Parameters:
  ///   - first: The bands of one bitmap.
  ///   - second: The bands of the other bitmap.
  ///   - tolerance: The largest difference of a bottom edge, in pixels.
  /// - Returns: `true` when the lists have the same count, and each bottom
  ///   edge is within `tolerance` of the bottom edge in the other list.
  static func matchBaselines(_ first: [ClosedRange<Int>], _ second: [ClosedRange<Int>], tolerance: Int) -> Bool {
    match(first, second, tolerance: tolerance, edges: [\.upperBound])
  }

  /// Tells if the edges of two lists of bands stand at the same pixel rows.
  ///
  /// - Parameters:
  ///   - first: The bands of one bitmap.
  ///   - second: The bands of the other bitmap.
  ///   - tolerance: The largest difference of an edge, in pixels.
  ///   - edges: The edges of a band to compare.
  /// - Returns: `true` when the lists have the same count, and each edge
  ///   is within `tolerance` of the edge in the other list.
  private static func match(
    _ first: [ClosedRange<Int>], _ second: [ClosedRange<Int>], tolerance: Int,
    edges: [KeyPath<ClosedRange<Int>, Int>]
  ) -> Bool {
    first.count == second.count
      && zip(first, second).allSatisfy { one, other in
        edges.allSatisfy { abs(one[keyPath: $0] - other[keyPath: $0]) <= tolerance }
      }
  }
}
