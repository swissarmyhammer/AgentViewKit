import CoreGraphics
import EditorSwiftUI
import EditorTheme
import FoundationModelsACPClient
import Observation
import SwiftUI

/// The heights of the static rows of a thread (card ^9ync5h3): the exact
/// height of the cache of the rows, else the height of the last layout of
/// the real row.
///
/// The cache (``TranscriptRowHeights``) computes the height of each row from
/// data, so a row can show its static form from its first frame. The cache
/// gives only a height whose text parts are each exact with its text
/// measure (``TranscriptTextMeasure/isExact(_:)``). For each other row, the
/// record of the real rows (``TranscriptMeasuredRowHeights``) gives the
/// height of the last layout of the real row. A row that neither one knows
/// shows its real form.
///
/// The heights feed the cache with the transcript of the session and the
/// rows in view. The cache computes each row of the transcript, the rows in
/// view first and then the rows out from them, so a row that a flick
/// reaches has its height before it comes into view. The cache copies only
/// the entries that it does not know yet, and the copy of
/// a known entry observes its own values, so a row that does not change
/// costs no work on the main thread. The text measure is EditorKit's
/// `EditorLayoutMeasure` (``EditorLayoutTranscriptTextMeasure``), so the
/// cache gives the height of each row whose text parts EditorKit measures
/// exactly.
@MainActor final class TranscriptStaticRowHeights: TranscriptRowHeightProvider {
  /// The record of the size of each real row.
  let measured = TranscriptMeasuredRowHeights()

  /// The cache of the rows, or `nil` when the rows have no cache.
  private(set) var cache: TranscriptRowHeights?

  /// The session whose transcript feeds the cache.
  private weak var session: SessionModel?

  /// The width of the rows, or zero before the first layout.
  private var width: CGFloat = .zero

  /// The appearance of the rows, or `nil` before the first
  /// ``noteAppearance(_:)``. The cache draws the pictures of the static text
  /// in it.
  private var appearance: TranscriptTextAppearance?

  /// The positions of the rows in view, or an empty range before the list
  /// reports them. The cache computes them first, then the rows out from
  /// them.
  private var rowsInView: Range<Int> = .zero ..< .zero

  /// Whether a change of the transcript of the session feeds the cache.
  private var tracksTranscript = false

  /// The count of calls to ``attach(cache:session:)``. A change callback of
  /// an older session or cache does nothing.
  private var generation = 0

  /// Makes the heights with no cache: each static row takes the height of
  /// the last layout of its real row.
  init() {}

  /// Gives the heights a cache, and the session whose transcript feeds it.
  ///
  /// - Parameters:
  ///   - cache: The cache of the rows, or `nil` for no cache.
  ///   - session: The session of the rows.
  func attach(cache: TranscriptRowHeights?, session: SessionModel) {
    self.cache = cache
    self.session = session
    generation += 1
    tracksTranscript = false
    if let appearance {
      cache?.noteAppearance(appearance)
    }
    feed()
  }

  /// Records the width of the rows. A new width feeds the cache, which then
  /// computes each row again, the rows in view first.
  ///
  /// - Parameter width: The width that the list gives each row.
  func noteRowWidth(_ width: CGFloat) {
    guard width != self.width else { return }
    self.width = width
    feed()
  }

  /// Records the appearance of the rows: their color scheme and their
  /// display scale. A new appearance makes the cache draw the pictures of
  /// the static text again.
  ///
  /// - Parameter appearance: The color scheme and the scale of the rows.
  func noteAppearance(_ appearance: TranscriptTextAppearance) {
    guard appearance != self.appearance else { return }
    self.appearance = appearance
    cache?.noteAppearance(appearance)
  }

  /// The picture of a text part of a row, from the cache
  /// (``TranscriptRowHeights/picture(of:inRow:appearance:)``).
  ///
  /// - Parameters:
  ///   - part: A text part of the row.
  ///   - rowKey: The row key of the entry.
  ///   - appearance: The appearance of the view that shows the picture.
  /// - Returns: The picture, or `nil` when the rows have no cache or the
  ///   cache has no picture of the part.
  func picture(
    of part: TranscriptTextPart, inRow rowKey: String, appearance: TranscriptTextAppearance
  ) -> EditorStaticRendering? {
    cache?.picture(of: part, inRow: rowKey, appearance: appearance)
  }

  /// Records the positions of the rows in view, and gives them to the
  /// cache, so the next batch of the cache starts at them.
  ///
  /// - Parameter positions: The positions in the transcript of the rows in
  ///   view.
  func noteRowsInView(positions: [Int]) {
    guard let span = positions.positionSpan else { return }
    rowsInView = Range(span)
    cache?.noteRowsInView(rowsInView)
  }

  /// Records the size of a real row.
  ///
  /// - Parameters:
  ///   - size: The size of the real row.
  ///   - id: The id of the entry of the row.
  func record(_ size: CGSize, for id: TranscriptEntry.ID) {
    measured.record(size, for: id)
  }

  func knowsHeight(of id: TranscriptEntry.ID) -> Bool {
    cache?.knowsHeight(of: id) == true || measured.knowsHeight(of: id)
  }

  func height(of id: TranscriptEntry.ID, width: CGFloat) -> CGFloat? {
    cache?.height(of: id, width: width) ?? measured.height(of: id, width: width)
  }

  /// Gives the transcript and the width to the cache, when the heights have
  /// a cache, a session and a width.
  private func feed() {
    guard let cache, let session, width > .zero else { return }
    cache.update(entries: transcript(of: session), width: width, rowsInView: rowsInView)
  }

  /// The transcript of the session. The first read after a change also
  /// observes the transcript, so its next change feeds the cache again.
  ///
  /// - Parameter session: The session.
  /// - Returns: The transcript.
  private func transcript(of session: SessionModel) -> [TranscriptEntry] {
    guard !tracksTranscript else { return session.transcript }
    tracksTranscript = true
    let generation = generation
    return withObservationTracking {
      session.transcript
    } onChange: { [weak self] in
      Task { @MainActor in self?.transcriptDidChange(generation: generation) }
    }
  }

  /// Feeds the cache after a change of the transcript.
  ///
  /// - Parameter generation: The generation of the observation.
  private func transcriptDidChange(generation: Int) {
    guard generation == self.generation else { return }
    tracksTranscript = false
    feed()
  }

  /// The cache of the rows of a thread, or `nil` when no cache can give
  /// the heights of the rows.
  ///
  /// The cache needs the store of the expanded blocks of the rows: with no
  /// store, each row keeps its expanded state itself, and the cache cannot
  /// read it. The cache also needs the default look of the rows
  /// (``SwiftUI/EnvironmentValues/transcriptRowsHaveDefaultLook``): its
  /// chrome rules follow the default views of the rows.
  ///
  /// - Parameters:
  ///   - theme: The theme of the rows.
  ///   - expandedBlocks: The store of the expanded blocks of the rows, or
  ///     `nil`.
  ///   - hasDefaultLook: Whether the rows have their default look.
  ///   - imageFolder: The folder that the images of the Markdown of the
  ///     rows load from (``RenderedMarkdownView/imageFolder(of:)``), or `nil`.
  /// - Returns: The cache, with the EditorKit text measure
  ///   (``EditorLayoutTranscriptTextMeasure``) and the metrics of the theme.
  static func makeCache(
    theme: any Theme, expandedBlocks: ExpandedBlocksStore?, hasDefaultLook: Bool, imageFolder: URL?
  ) -> TranscriptRowHeights? {
    guard let expandedBlocks, hasDefaultLook else { return nil }
    return TranscriptRowHeights(
      measure: EditorLayoutTranscriptTextMeasure(theme: theme, imageFolder: imageFolder),
      metrics: TranscriptRowMetrics.probe(theme: theme), expandedBlocks: expandedBlocks)
  }
}

/// The values of the environment of the rows that set the cache of a thread
/// (``TranscriptStaticRowHeights/makeCache(theme:expandedBlocks:hasDefaultLook:imageFolder:)``).
/// A change of one of them makes a new cache.
nonisolated struct TranscriptRowCacheSetup: Equatable {
  /// The font faces of the theme: the UI, the display and the code face.
  let faces: [FontFace]

  /// The identity of the store of the expanded blocks, or `nil`.
  let expandedBlocks: ObjectIdentifier?

  /// The identity of the session.
  let session: ObjectIdentifier

  /// Whether the rows have their default look.
  let hasDefaultLook: Bool

  /// The folder that the images of the Markdown of the rows load from, or
  /// `nil`.
  let imageFolder: URL?

  /// Tells if two setups make the same cache: each value of the one setup
  /// is the value of the other setup.
  ///
  /// - Parameters:
  ///   - lhs: A setup.
  ///   - rhs: A setup.
  /// - Returns: `true` when the faces, the store of the expanded blocks, the
  ///   session, the look and the image folder are the same.
  static func == (lhs: TranscriptRowCacheSetup, rhs: TranscriptRowCacheSetup) -> Bool {
    lhs.faces == rhs.faces && lhs.expandedBlocks == rhs.expandedBlocks && lhs.session == rhs.session
      && lhs.hasDefaultLook == rhs.hasDefaultLook && lhs.imageFolder == rhs.imageFolder
  }
}

/// Feeds the heights of the static rows of a thread with a cache for the
/// environment of the rows, with the width of the rows, and with their
/// appearance: the color scheme and the display scale of the pictures of
/// the static text.
///
/// ``ConversationView`` puts the modifier on the stack of its rows. The
/// width of the stack is the width that the stack proposes to each row.
struct TranscriptRowHeightsFeed: ViewModifier {
  /// The heights of the static rows.
  let heights: TranscriptStaticRowHeights

  /// The session of the rows.
  let session: SessionModel

  @Environment(\.editorTheme) private var theme
  @Environment(\.expandedBlocksStore) private var expandedBlocks
  @Environment(\.transcriptRowsHaveDefaultLook) private var hasDefaultLook
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.displayScale) private var displayScale

  func body(content: Content) -> some View {
    content
      .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
        heights.noteRowWidth(width)
      }
      .onChange(of: TranscriptTextAppearance(colorScheme: colorScheme, scale: displayScale), initial: true) {
        _, appearance in
        heights.noteAppearance(appearance)
      }
      .onChange(of: setup, initial: true) {
        let cache = TranscriptStaticRowHeights.makeCache(
          theme: theme, expandedBlocks: expandedBlocks, hasDefaultLook: hasDefaultLook,
          imageFolder: setup.imageFolder)
        heights.attach(cache: cache, session: session)
      }
  }

  /// The values of the environment that set the cache.
  private var setup: TranscriptRowCacheSetup {
    TranscriptRowCacheSetup(
      faces: [theme.uiFace, theme.displayFace, theme.codeFace], expandedBlocks: expandedBlocks.map(ObjectIdentifier.init),
      session: ObjectIdentifier(session), hasDefaultLook: hasDefaultLook,
      imageFolder: RenderedMarkdownView.imageFolder(of: session))
  }
}

extension EnvironmentValues {
  /// Whether the rows of a thread show their default look: no item view
  /// override, no registered view of a content block or a tool call, and
  /// no time of the entries.
  ///
  /// The chrome rules of the height cache (``TranscriptRowChrome``) follow
  /// the default views of the rows. A row with another view can have
  /// another height, so a thread whose rows do not have the default look
  /// has no cache (``TranscriptStaticRowHeights``).
  var transcriptRowsHaveDefaultLook: Bool {
    !hasItemViewOverride && contentBlockRegistry.keys.isEmpty && toolCallRegistry.keys.isEmpty
      && !showsTranscriptTiming
  }
}
