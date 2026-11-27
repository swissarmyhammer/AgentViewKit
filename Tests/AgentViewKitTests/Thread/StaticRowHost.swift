import AgentViewKitTestSupport
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
/// session, with the heights of the static rows and the motion signal of a
/// thread. A host from ``makeCached(_:width:frames:movesLive:colorScheme:)`` gives the rows the height cache
/// of a thread too. ``show(rowsMove:)`` sets the motion signal and lays the row out
/// again, so a test reads the row at rest and while the rows move. No
/// window shows, and no window takes the focus. The window has the light
/// appearance, so the text is dark on a clear background, or the dark
/// appearance of a host from ``makeCached(_:width:frames:movesLive:colorScheme:)``
/// with the dark color scheme.
@MainActor final class StaticRowHost {
  /// The session whose one entry the host shows.
  let session: SessionModel

  /// The width of the row, in points.
  let width: CGFloat

  /// The heights of the static row: the record of the real row, and the
  /// height cache of a host from ``makeCached(_:width:frames:movesLive:colorScheme:)``.
  let heights = TranscriptStaticRowHeights()

  /// The store of the expanded blocks of the row.
  let store: ExpandedBlocksStore

  /// The cache of the EditorKit models of the row, as a thread gives it.
  let cache = CodeBlockModelCache(limit: CodeBlockModelCache.threadLimit)

  /// Whether a motion of the rows is a live motion of the user, as a flick
  /// is (``TranscriptRowMotion/isLiveMotion(_:)``). With `false`, a motion
  /// is a scroll of the kit, such as an animated scroll to a row.
  var movesLive = true

  /// The queue that mounts the real row at rest, or `nil` for a row that
  /// shows its real form at once at rest (card ^7625j1b).
  var mounts: TranscriptRowMountQueue?

  /// Whether the row is in a SwiftUI scroll view of the size of the window,
  /// as the rows of a thread are. Set it before ``show(rowsMove:)``.
  var isInScrollView = false

  /// The footer of the message row, as the `messageFooter` slot gives it.
  /// Set it before ``show(rowsMove:)``.
  var messageFooter: ItemViewRenderer<MessageEntry>?

  /// The window of the host. It is never ordered in.
  private let window: NSWindow

  /// The host of the row.
  private let hosting: NSHostingView<AnyView>

  /// The identity of the row. A new identity is a new row, as the list
  /// makes for a row that comes into it.
  private var rowIdentity = 0

  /// Shows the row of `item` at rest, at `width`.
  ///
  /// - Parameters:
  ///   - item: The transcript item of the one entry.
  ///   - width: The width of the row, in points.
  convenience init(_ item: PreviewTranscriptItem, width: CGFloat) {
    self.init(item, width: width, isExpanded: false, colorScheme: .light, showsAtRest: true)
  }

  /// Makes the host of the row of `item`, and shows the row at rest only
  /// when `showsAtRest` is `true`.
  ///
  /// - Parameters:
  ///   - item: The transcript item of the one entry.
  ///   - width: The width of the row, in points.
  ///   - isExpanded: Whether the blocks of the row are expanded.
  ///   - colorScheme: The appearance of the window.
  ///   - showsAtRest: Whether the host shows the row at rest.
  private init(
    _ item: PreviewTranscriptItem, width: CGFloat, isExpanded: Bool, colorScheme: ColorScheme, showsAtRest: Bool
  ) {
    store = ExpandedBlocksStore { _ in isExpanded }
    session = .preview(transcript: [item])
    self.width = width
    hosting = NSHostingView(rootView: AnyView(EmptyView()))
    window = UnorderedWindow.make(holding: hosting, size: CGSize(width: width, height: width))
    window.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
    appearance = TranscriptTextAppearance(colorScheme: colorScheme, scale: window.backingScaleFactor)
    if showsAtRest {
      show(rowsMove: false)
    }
  }

  /// The appearance of the window: its color scheme and its backing scale.
  /// The height cache of a host from ``makeCached(_:width:frames:movesLive:colorScheme:)``
  /// draws the pictures of the static text in it.
  let appearance: TranscriptTextAppearance

  /// Gives the row of a fixture the height cache of a thread, waits until the
  /// cache publishes the height and the pictures of the row, and then shows
  /// the row for the first time, while the rows move.
  ///
  /// The row has no record of a real layout, so the cache alone can give
  /// the height of its static form. The row of each fixture has a chrome
  /// rule, so the cache publishes a height. The host waits only for the
  /// computation of the cache (``TranscriptRowHeights/computeHeights(of:)``),
  /// not for the main-actor jobs of other tests.
  ///
  /// - Parameters:
  ///   - row: The fixture of the row.
  ///   - width: The width of the row, in points.
  ///   - frames: The frames of the queue of the row, or `nil` for a row
  ///     with no queue (``mounts``). The queue knows that the rows move,
  ///     and whether the motion is live (`movesLive`).
  ///   - movesLive: Whether the motion is a live motion of the user
  ///     (``movesLive``).
  ///   - colorScheme: The appearance of the window. The default is light.
  /// - Returns: The host, with the row in its first frame.
  static func makeCached(
    _ row: TranscriptRowFixtures.Row, width: CGFloat, frames: (any TranscriptFrameSource)? = nil,
    movesLive: Bool = true, colorScheme: ColorScheme = .light
  ) async -> StaticRowHost {
    await makeCached(
      row.item, width: width, isExpanded: row.isExpanded, frames: frames, movesLive: movesLive,
      colorScheme: colorScheme)
  }

  /// Gives the row of `item` the height cache of a thread, as
  /// ``makeCached(_:width:frames:movesLive:colorScheme:)`` gives the row of
  /// a fixture.
  ///
  /// - Parameters:
  ///   - item: The transcript item of the one entry.
  ///   - width: The width of the row, in points.
  ///   - isExpanded: Whether the blocks of the row are expanded. The default
  ///     is `false`.
  ///   - frames: The frames of the queue of the row, or `nil` for a row
  ///     with no queue (``mounts``).
  ///   - movesLive: Whether the motion is a live motion of the user
  ///     (``movesLive``). The default is `true`.
  ///   - colorScheme: The appearance of the window. The default is light.
  /// - Returns: The host, with the row in its first frame.
  static func makeCached(
    _ item: PreviewTranscriptItem, width: CGFloat, isExpanded: Bool = false,
    frames: (any TranscriptFrameSource)? = nil, movesLive: Bool = true, colorScheme: ColorScheme = .light
  ) async -> StaticRowHost {
    let host = StaticRowHost(
      item, width: width, isExpanded: isExpanded, colorScheme: colorScheme, showsAtRest: false)
    host.movesLive = movesLive
    if let frames {
      let mounts = TranscriptRowMountQueue(frames: frames)
      mounts.noteRowsMove(true)
      mounts.noteRowsMoveLive(movesLive)
      host.mounts = mounts
    }
    let cache = TranscriptRowHeights(metrics: TranscriptRowMetrics.probe(), expandedBlocks: host.store)
    host.heights.noteAppearance(host.appearance)
    host.heights.attach(cache: cache, session: host.session)
    host.heights.noteRowWidth(width)
    let rowKey = host.entry.rowKey
    await cache.computeHeights(of: [rowKey])
    host.show(rowsMove: true)
    return host
  }

  /// Shows the row at rest, runs the blocks of the main run loop that the
  /// layout added (``PendingRunLoopBlocks``), and lays the row out again, so
  /// each EditorKit view of the row has its height.
  func showAtRestAndSettle() {
    show(rowsMove: false)
    PendingRunLoopBlocks.run()
    layOut()
  }

  /// Whether the height cache of the row gives the height of its static
  /// form. The record of the real row does not count.
  var cacheKnowsHeight: Bool {
    heights.cache?.knowsHeight(of: entry.id) == true
  }

  /// The entry of the row.
  var entry: TranscriptEntry {
    session.transcript[0]
  }

  /// Shows the row as a row that comes into the list while the rows move: a
  /// new row, with no state of the row that showed before, and lays it out.
  /// The heights of the static rows keep the size of the real row.
  func enterWhileMoving() {
    rowIdentity += 1
    show(rowsMove: true)
  }

  /// Sets the motion signal of the thread, and lays the row out again. The
  /// row keeps its identity, as a row in view of a list keeps it when the
  /// rows start or stop to move.
  ///
  /// - Parameter rowsMove: Whether the rows of the thread move.
  func show(rowsMove: Bool) {
    let row = row(rowsMove: rowsMove)
    hosting.rootView =
      isInScrollView ? AnyView(ScrollView { row }.frame(width: width, height: width)) : AnyView(row)
    layOut()
  }

  /// Lays the row out at its fitting size in two passes: the first pass
  /// lays out the editors, and the second pass gives the host the size
  /// that the editors then have.
  func layOut() {
    StyleViewHost.layOut(hosting, passes: Self.layoutPasses)
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

  /// The view that the window hit-tests at the center of the first
  /// EditorKit text view of the row, as AppKit hit-tests a click or a
  /// scroll-wheel event there, and that text view. Each is `nil` when the
  /// row has no text view; the hit is `nil` when no view takes the point.
  var hitAtText: (hit: NSView?, text: NSTextView?) {
    guard let text = views(ofType: NSTextView.self, in: hosting).first, let frame = hosting.superview else {
      return (nil, nil)
    }
    let center = text.convert(CGPoint(x: text.bounds.midX, y: text.bounds.midY), to: frame)
    return (hosting.hitTest(center), text)
  }

  /// Whether the hit test at the text of the row (``hitAtText``) reaches a
  /// view of the row: a view of the host that is not the host, and that
  /// does not hold the text view, such as a scroll view does.
  var hitReachesRow: Bool {
    let (hit, text) = hitAtText
    guard let hit, let text, hit !== hosting else { return false }
    return hit === text || !text.isDescendant(of: hit)
  }

  /// Whether the hit test at the text of the row (``hitAtText``) reaches
  /// the scroll view of a host with ``isInScrollView``: the AppKit scroll
  /// view, or a view in it. A scroll-wheel event at that point then goes
  /// up the responder chain to the scroll view.
  var hitReachesScrollView: Bool {
    guard let hit = hitAtText.hit else { return false }
    return hit is NSScrollView || hit.enclosingScrollView != nil
  }

  /// Moves the mouse into the host and over the hover responder of
  /// `probe`, as AppKit sends the moves of a still mouse while the content
  /// moves under it, and runs the blocks of the main run loop that each
  /// move added (``PendingRunLoopBlocks``).
  ///
  /// The window is never ordered in, so AppKit sends it no mouse event of
  /// its own. The host first takes `mouseEntered(with:)`, as its tracking
  /// area gives it when the mouse comes in: with no enter, SwiftUI
  /// hit-tests no hover responder for a move. Each move goes to a point one
  /// point to the right of the last one, at the middle of the responder.
  ///
  /// - Parameters:
  ///   - probe: The probe whose responder is in the footer of the row
  ///     (``messageFooter``).
  ///   - moves: The number of moves.
  func moveMouse(over probe: HoverResponderProbe, moves: Int) throws {
    guard let marker = probe.marker(in: hosting) else { throw StaticRowHostError.noProbe }
    let start = marker.convert(CGPoint(x: marker.bounds.minX, y: marker.bounds.midY), to: nil)
    let points = (0...moves).map { CGPoint(x: start.x + CGFloat($0), y: start.y) }
    hosting.mouseEntered(with: try mouseMoved(at: points[0], number: 0))
    for (number, point) in points.enumerated().dropFirst() {
      hosting.mouseMoved(with: try mouseMoved(at: point, number: number))
      PendingRunLoopBlocks.run()
    }
  }

  /// A mouse move of the window of the host.
  ///
  /// - Parameters:
  ///   - point: The place of the mouse, in the coordinates of the window.
  ///   - number: The number of the event.
  /// - Returns: The event.
  private func mouseMoved(at point: CGPoint, number: Int) throws -> NSEvent {
    let event = NSEvent.mouseEvent(
      with: .mouseMoved, location: point, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
      context: nil, eventNumber: number, clickCount: 0, pressure: 0)
    guard let event else { throw StaticRowHostError.noMouseEvent }
    return event
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

  /// The row of the entry, with the environment of a thread. A new row
  /// that the host makes in a live motion (``movesLive``) enters while the
  /// rows move, as the list of a thread makes it in a flick.
  ///
  /// - Parameter rowsMove: Whether the rows of the thread move.
  /// - Returns: The row at ``width``.
  private func row(rowsMove: Bool) -> some View {
    TranscriptRowElement(
      slot: TranscriptRowSlot(position: 0, entry: entry), isLast: false, lines: [],
      entersWhileMoving: rowsMove && movesLive)
      .id(rowIdentity)
      .frame(width: width)
      .fixedSize(horizontal: false, vertical: true)
      .environment(\.transcriptRowsMove, rowsMove)
      .environment(\.transcriptRowsMoveLive, rowsMove && movesLive)
      .environment(\.staticRowHeights, heights)
      .environment(\.transcriptRowMounts, mounts)
      .environment(\.expandedBlocksStore, store)
      .environment(\.sessionModel, session)
      .environment(\.codeBlockModelCache, cache)
      .environment(\.messageFooter, messageFooter)
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

  /// The row shows no hover responder of a ``HoverResponderProbe``.
  case noProbe

  /// AppKit gave no mouse event.
  case noMouseEvent
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

  /// The count of color components of a pixel: red, green and blue. The
  /// luminance of a pixel is their mean.
  static let colorComponentCount: CGFloat = 3

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
      let luminance = (color.redComponent + color.greenComponent + color.blueComponent) / colorComponentCount
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
