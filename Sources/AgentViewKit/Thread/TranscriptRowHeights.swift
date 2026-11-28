import CoreGraphics
import EditorSwiftUI
import Foundation
import FoundationModelsACPClient
import Observation
import os

/// The height of each transcript row, from data, off the main thread
/// (card ^9h7bm9j).
///
/// The cache keeps a height by entry id, entry version and width. The entry
/// version is the row key and the content digest: the hash of the
/// ``TranscriptRowContent`` copy of the entry. The flow:
///
/// - ``update(entries:width:rowsInView:)`` copies each entry that the cache
///   does not know yet, on the main actor. The copy observes the values of
///   the entry that it reads. A row that does not change thus costs no work
///   on the main thread.
/// - A change to an observed value copies that one entry again. While the
///   last row streams, only it is copied and computed again.
/// - A worker actor computes the heights with the chrome rules
///   (``TranscriptRowChrome``) and the text measure, off the main thread. A
///   version that the worker knows is not computed again. The worker
///   prepares each text part one time (``TranscriptTextMeasure/prepared(_:)``),
///   so a new width measures the prepared parts again at a small part of the
///   cost of a first measure.
/// - The cache computes each row of the transcript as soon as it knows the
///   transcript and the width, and each new or changed row when it comes
///   (card ^9ync5h3). A row that a fast flick reaches thus has its height
///   before it comes into view. The rows go to the worker in batches of
///   ``batchSize``, in the order of a ``TranscriptRowHeightQueue``: the rows
///   in view first, then out from them in the two directions, and the last
///   rows first when no row in view is known. Each batch takes the order of
///   the rows in view of its time (``noteRowsInView(_:)``).
/// - The cache publishes the heights of each batch to the main actor, as
///   observable values, before it sends the next batch: one store step per
///   row. After a width change, it computes each row again in the same
///   order. A batch of an older width is the last one of that width.
/// - With an appearance (``noteAppearance(_:)``), the worker also draws a
///   picture of each Markdown, code and output text part that EditorKit
///   draws (``TranscriptTextMeasure/picture(of:width:appearance:)``), at the
///   width of its measure, in the same batch as the height of the row, and
///   thus in the same order. The cache publishes the pictures of a row
///   with its height. A static row then shows the pictures in place of the
///   SwiftUI `Text` of its text (card ^9ync5h3). A new width or a new
///   appearance drops the pictures, and the worker draws them again.
@MainActor @Observable public final class TranscriptRowHeights {
  /// The published height of each row at ``width``, by row key. A row that
  /// no chrome rule covers has no height.
  private var heights: [String: CGFloat] = [:]

  /// The heights of the rows whose text parts are each exact
  /// (``TranscriptTextMeasure/isExact(_:)``), by row key, for the static
  /// rows (``TranscriptRowHeightProvider``). They are not observable, so a
  /// new height does not make a row evaluate its body again.
  @ObservationIgnored private var exactHeights: [String: CGFloat] = [:]

  /// The worker that computes the heights.
  @ObservationIgnored private let worker: TranscriptRowHeightWorker

  /// The store that tells whether the blocks of a row are expanded.
  @ObservationIgnored private let expandedBlocks: ExpandedBlocksStore?

  /// The width of the last update.
  @ObservationIgnored public private(set) var width: CGFloat = .zero

  /// The last copy of each known row, by row key.
  @ObservationIgnored private var contents: [String: TranscriptRowContent] = [:]

  /// The entry object of each known row, by row key.
  @ObservationIgnored private var objects: [String: ObjectIdentifier] = [:]

  /// The count of copies of each row, by row key. A result of an older copy
  /// is not published.
  @ObservationIgnored private var revisions: [String: Int] = [:]

  /// The count of width changes. A result for an older width is not
  /// published.
  @ObservationIgnored private var generation = 0

  /// The appearance of the pictures, or `nil` before the first
  /// ``noteAppearance(_:)``. With no appearance, the worker draws no
  /// picture.
  @ObservationIgnored private var appearance: TranscriptTextAppearance?

  /// The count of appearance changes. A picture of an older appearance is
  /// not published.
  @ObservationIgnored private var appearanceGeneration = 0

  /// The published pictures of each row at ``width`` in ``appearance``, by
  /// row key, and in a row by text part. They are not observable: the
  /// cache publishes them with the height of the row, so a row that shows
  /// its static form from the cache height finds its pictures. Past the
  /// byte bound, the pictures of the rows farthest from the rows in view
  /// go first, so the cache keeps the pictures that a flick needs next.
  @ObservationIgnored private var pictures: TranscriptPictureCache<String, [TranscriptTextPart: EditorStaticRendering]>

  /// The rows whose last result has a picture: the rows whose pictures the
  /// cache draws again when its bound dropped them
  /// (``drawPicturesNearView()``).
  @ObservationIgnored private var picturedRows: Set<String> = []

  /// The signal of the pictures of each row whose picture a slot read, by
  /// row key (``TranscriptPictureSignal``).
  @ObservationIgnored private var pictureSignals: [String: TranscriptPictureSignal] = [:]

  /// The rows that the cache must still compute, in the order of their
  /// computation.
  @ObservationIgnored private var queue = TranscriptRowHeightQueue()

  /// The task that sends the rows of the queue to the worker, batch by
  /// batch, or `nil` when no row waits.
  @ObservationIgnored private var drain: Task<Void, Never>?

  /// The most rows of one computation on the worker. A small batch
  /// publishes the rows near the view soon, and takes the new rows in view
  /// soon.
  static let batchSize = 16

  /// The number of rows nearest the view (``TranscriptRowHeightQueue/Pick/rank``)
  /// whose prepared parts the worker keeps: its limit of prepared rows. A
  /// row farther out does not push out the prepared parts of a row near the
  /// view, so a width change measures the rows near the view again with
  /// their prepared parts.
  static let preparedRank = TranscriptRowHeightWorker.defaultPreparedRowLimit

  /// The default of the most bytes of the bitmaps of the pictures that the
  /// cache publishes, and that its worker keeps.
  public static let defaultPictureByteLimit = TranscriptRowHeightWorker.defaultPictureByteLimit

  /// Makes a cache.
  ///
  /// - Parameters:
  ///   - measure: The text measure. The default is
  ///     ``EditorLayoutTranscriptTextMeasure`` in the default theme, which
  ///     uses EditorKit's `EditorLayoutMeasure`.
  ///   - metrics: The theme metrics of the rows.
  ///   - expandedBlocks: The store that tells whether the blocks of a row are
  ///     expanded, or `nil` when each block is collapsed.
  ///   - pictureByteLimit: The most bytes of the bitmaps of the pictures
  ///     that the cache publishes, and that its worker keeps.
  public init(
    measure: any TranscriptTextMeasure = EditorLayoutTranscriptTextMeasure(), metrics: TranscriptRowMetrics,
    expandedBlocks: ExpandedBlocksStore? = nil,
    pictureByteLimit: Int = TranscriptRowHeights.defaultPictureByteLimit
  ) {
    worker = TranscriptRowHeightWorker(measure: measure, metrics: metrics, pictureByteLimit: pictureByteLimit)
    pictures = TranscriptPictureCache(byteLimit: pictureByteLimit)
    self.expandedBlocks = expandedBlocks
  }

  /// Stops the drain of the queue: a cache that no thread holds computes no
  /// more rows.
  isolated deinit {
    drain?.cancel()
  }

  /// The ``BodyEvaluationCounter`` key of each copy of the data of a row on
  /// the main thread.
  ///
  /// - Parameter rowKey: The row key of the entry.
  /// - Returns: `row-heights-copy-<rowKey>`.
  static func copyCounterKey(for rowKey: String) -> String {
    BodyEvaluationKey.make(prefix: copyCounterKeyPrefix, id: rowKey)
  }

  /// The start of the ``BodyEvaluationCounter`` key of a copy.
  static let copyCounterKeyPrefix = "row-heights-copy-"

  /// Gives the rows and their width.
  ///
  /// The cache copies each entry that it does not know yet, and computes its
  /// height. When the width changes, it computes each row again. The rows
  /// in view come first, then the rows out from them.
  ///
  /// - Parameters:
  ///   - entries: The transcript entries, in the order of the rows.
  ///   - width: The width of the rows.
  ///   - rowsInView: The indices of the rows in view, or an empty range
  ///     when no row in view is known: the last rows then come first.
  public func update(entries: [TranscriptEntry], width: CGFloat, rowsInView: Range<Int>) {
    let widthChanged = width != self.width
    let changed = register(entries, width: width)
    let keys = entries.map(\.rowKey)
    queue.setRows(keys)
    queue.noteRowsInView(rowsInView)
    compute(widthChanged ? keys : changed)
  }

  /// Gives the cache the rows in view. The next batch of the computation
  /// starts at them.
  ///
  /// - Parameter rowsInView: The indices of the rows in view, or an empty
  ///   range when no row in view is known.
  public func noteRowsInView(_ rowsInView: Range<Int>) {
    queue.noteRowsInView(rowsInView)
    drawPicturesNearView()
  }

  /// The number of rows above and below the rows in view whose pictures
  /// the cache draws again when its bound dropped them
  /// (``drawPicturesNearView()``): about two screens of rows on each side.
  static let pictureReach = 8

  /// Draws again the pictures that the bound of the cache dropped, of the
  /// rows in view and of the ``pictureReach`` rows on each side of them.
  ///
  /// The queue sends these rows to the worker in its order: the rows in
  /// view first, then the rows out from them, so a row that a flick
  /// reaches gets its picture before it comes into view. The worker keeps
  /// the height of each such row, so it only draws the picture.
  private func drawPicturesNearView() {
    let dropped = queue.rowKeys(near: Self.pictureReach).filter { picturedRows.contains($0) && pictures[$0] == nil }
    guard !dropped.isEmpty else { return }
    compute(Array(dropped))
  }

  /// Records the rows and their width, and starts no computation.
  ///
  /// The cache copies each entry that it does not know yet. A new width
  /// starts a new width generation, and removes each published height.
  /// ``update(entries:width:rowsInView:)`` then computes the rows, and
  /// ``computeHeights(of:)`` computes the rows that its caller names.
  ///
  /// - Parameters:
  ///   - entries: The transcript entries, in the order of the rows.
  ///   - width: The width of the rows.
  /// - Returns: The row keys of the entries that the cache copied.
  func register(_ entries: [TranscriptEntry], width: CGFloat) -> [String] {
    if width != self.width {
      self.width = width
      generation += 1
      heights = [:]
      exactHeights = [:]
      pictures.removeAll()
    }
    let changed = entries.filter { objects[$0.rowKey] != ObjectIdentifier($0.object) }
    for entry in changed {
      copy(entry)
    }
    return changed.map(\.rowKey)
  }

  /// The height of a row at the width of the last update.
  ///
  /// - Parameter rowKey: The row key of the entry.
  /// - Returns: The height, or `nil` before it is computed or when no chrome
  ///   rule covers the row.
  public func height(of rowKey: String) -> CGFloat? {
    heights[rowKey]
  }

  /// Gives the appearance of the pictures of the static text: the color
  /// scheme and the display scale of the rows.
  ///
  /// A new appearance drops each picture, and computes each known row
  /// again, so the worker draws its pictures in the new appearance. The
  /// heights do not change.
  ///
  /// - Parameter appearance: The color scheme and the scale of the rows.
  public func noteAppearance(_ appearance: TranscriptTextAppearance) {
    guard appearance != self.appearance else { return }
    self.appearance = appearance
    appearanceGeneration += 1
    pictures.removeAll()
    compute(Array(contents.keys))
  }

  /// The published picture of a text part of a row, at the width of the
  /// last update.
  ///
  /// - Parameters:
  ///   - part: A text part of the row.
  ///   - rowKey: The row key of the entry.
  ///   - appearance: The appearance of the view that shows the picture.
  /// - Returns: The picture, or `nil` when the worker did not draw it yet,
  ///   when EditorKit does not draw the text, or when `appearance` is not
  ///   the appearance of the pictures.
  func picture(
    of part: TranscriptTextPart, inRow rowKey: String, appearance: TranscriptTextAppearance
  ) -> EditorStaticRendering? {
    // The read observes the pictures of the row, so a slot that reads no
    // picture now shows the picture when the cache publishes it.
    _ = pictureSignal(ofRow: rowKey).revision
    guard appearance == self.appearance else { return nil }
    return pictures[rowKey]?[part]
  }

  /// The signal of the pictures of a row, which a read of a picture of the
  /// row observes (``TranscriptPictureSignal``).
  ///
  /// - Parameter rowKey: The row key of the entry.
  /// - Returns: The signal of the row.
  private func pictureSignal(ofRow rowKey: String) -> TranscriptPictureSignal {
    if let signal = pictureSignals[rowKey] {
      return signal
    }
    let signal = TranscriptPictureSignal()
    pictureSignals[rowKey] = signal
    return signal
  }

  /// Whether the cache publishes a picture of a text part of a row now.
  ///
  /// - Parameter rowKey: The row key of the entry.
  /// - Returns: `true` when the cache holds a picture of the row.
  func hasPictures(ofRow rowKey: String) -> Bool {
    pictures[rowKey] != nil
  }

  /// The count of text parts that the worker prepared for a measure: the
  /// work of a text part that does not depend on the width.
  ///
  /// - Returns: The count of prepares since the cache was made.
  func prepareCount() async -> Int {
    await worker.prepareCount
  }

  /// Copies the data of an entry, and observes the values that the copy
  /// reads.
  ///
  /// - Parameter entry: The entry.
  private func copy(_ entry: TranscriptEntry) {
    let key = entry.rowKey
    let store = expandedBlocks
    #if DEBUG
      BodyEvaluationCounter.note(Self.copyCounterKey(for: key))
    #endif
    let content = withObservationTracking {
      TranscriptRowContent(entry: entry, isExpanded: store?.isExpanded(entry: entry) ?? false)
    } onChange: { [weak self] in
      Task { @MainActor in self?.entryChanged(entry) }
    }
    contents[key] = content
    objects[key] = ObjectIdentifier(entry.object)
    revisions[key, default: .zero] += 1
  }

  /// Copies a changed entry again, and computes its height.
  ///
  /// - Parameter entry: The entry.
  private func entryChanged(_ entry: TranscriptEntry) {
    guard objects[entry.rowKey] == ObjectIdentifier(entry.object) else { return }
    copy(entry)
    compute([entry.rowKey])
  }

  /// Adds rows to the queue, and starts the drain of the queue when it
  /// does not run.
  ///
  /// - Parameter keys: The row keys.
  private func compute(_ keys: [String]) {
    queue.add(keys)
    guard drain == nil, !queue.isEmpty else { return }
    drain = Task { [weak self] in
      while let batch = self?.nextBatch(), !Task.isCancelled {
        guard let worker = self?.worker else { return }
        let results = await worker.heights(
          of: batch.jobs, width: batch.pass.width, appearance: batch.pass.appearance)
        self?.publish(results, pass: batch.pass)
      }
      self?.drain = nil
    }
  }

  /// The width, the appearance and their generations of a new computation.
  private var currentPass: TranscriptRowHeightWorker.Pass {
    TranscriptRowHeightWorker.Pass(
      width: width, generation: generation, appearance: appearance, appearanceGeneration: appearanceGeneration)
  }

  /// One batch of the drain: the jobs, and the width, the appearance and
  /// their generations of the time that the drain took them.
  private struct Batch {
    /// The jobs.
    let jobs: [TranscriptRowHeightWorker.Job]

    /// The width, the appearance and their generations of the jobs.
    let pass: TranscriptRowHeightWorker.Pass
  }

  /// Takes the next batch out of the queue.
  ///
  /// - Returns: The batch, or `nil` when no row waits.
  private func nextBatch() -> Batch? {
    let jobs = queue.next(limit: Self.batchSize).compactMap { pick in
      contents[pick.rowKey].map {
        TranscriptRowHeightWorker.Job(
          content: $0, revision: revisions[pick.rowKey, default: .zero], keepsPrepared: pick.rank < Self.preparedRank)
      }
    }
    return jobs.isEmpty ? nil : Batch(jobs: jobs, pass: currentPass)
  }

  /// Returns when the cache has computed and published each row of its
  /// queue: the rows of the transcript and of its width, and each row that
  /// changed. The call awaits the drain task of the cache, with no clock.
  func finishPendingHeights() async {
    await drain?.value
  }

  /// Computes the heights of rows on the worker at the width of the last
  /// update, and returns when the cache holds them.
  ///
  /// The call awaits the worker itself, and publishes the results in the
  /// main-actor step that resumes it: the same step in which the call
  /// returns. Thus the call needs one turn of the main actor after the
  /// worker, and no main-actor job that is ready at that turn runs between
  /// the publish and the return. A row that the cache did not copy yet has
  /// no height.
  ///
  /// - Parameter rowKeys: The row keys.
  func computeHeights(of rowKeys: [String]) async {
    let jobs = rowKeys.compactMap { key in
      contents[key].map {
        TranscriptRowHeightWorker.Job(content: $0, revision: revisions[key, default: .zero], keepsPrepared: true)
      }
    }
    guard !jobs.isEmpty else { return }
    let pass = currentPass
    publish(await worker.heights(of: jobs, width: pass.width, appearance: pass.appearance), pass: pass)
  }

  /// Publishes the results of the worker that are still current: the
  /// heights of the current width, and the pictures of the current
  /// appearance.
  ///
  /// - Parameters:
  ///   - results: The results.
  ///   - pass: The width, the appearance and their generations of the
  ///     results.
  private func publish(_ results: [TranscriptRowHeightWorker.Result], pass: TranscriptRowHeightWorker.Pass) {
    guard pass.generation == generation else { return }
    let picturesAreCurrent = pass.appearanceGeneration == appearanceGeneration
    for result in results where revisions[result.rowKey] == result.revision {
      heights[result.rowKey] = result.height
      exactHeights[result.rowKey] = result.isExact ? result.height : nil
      if picturesAreCurrent {
        publishPictures(result.pictures, of: result.rowKey)
      }
    }
  }

  /// Publishes the pictures of a row, or drops the old pictures of a row
  /// with no picture.
  ///
  /// - Parameters:
  ///   - rowPictures: The pictures of the row, by text part.
  ///   - rowKey: The row key.
  private func publishPictures(_ rowPictures: [TranscriptTextPart: EditorStaticRendering], of rowKey: String) {
    guard !rowPictures.isEmpty else {
      picturedRows.remove(rowKey)
      pictures.remove(rowKey)
      return
    }
    picturedRows.insert(rowKey)
    let hadPictures = pictures[rowKey] != nil
    let queue = queue
    pictures.insert(rowPictures, forKey: rowKey) { queue.distance(ofRow: $0) }
    if !hadPictures {
      pictureSignals[rowKey]?.revision &+= 1
    }
  }
}

/// The signal of the pictures of one row of the height cache (card
/// ^9ync5h3).
///
/// The slot of a static text reads the signal of its row when it reads its
/// picture (``TranscriptRowHeights/picture(of:inRow:appearance:)``). The
/// cache changes the signal when it publishes the pictures of a row that
/// had none, so only the slots of that row evaluate their bodies again,
/// and a row that the list made before its picture, such as the lead row
/// of a flick, shows the picture before it comes into view.
@MainActor @Observable final class TranscriptPictureSignal {
  /// The count of the publishes of the pictures of the row.
  var revision = 0

  /// Makes a signal of a row with no picture.
  init() {}
}

/// The cache is the height provider of the static rows (^9ync5h3): a row
/// whose height the cache knows can show its static form from its first
/// frame.
///
/// The provider gives only the height of a row whose text parts are each
/// exact with the text measure. A height that is not exact can differ from
/// the height of the real row, and the row then jumps when it changes form.
extension TranscriptRowHeights: TranscriptRowHeightProvider {
  func knowsHeight(of id: TranscriptEntry.ID) -> Bool {
    exactHeights[id.rowKey] != nil
  }

  func height(of id: TranscriptEntry.ID, width: CGFloat) -> CGFloat? {
    guard abs(width - self.width) <= TranscriptMeasuredRowHeights.widthTolerance else { return nil }
    return exactHeights[id.rowKey]
  }
}

/// Computes row heights off the main thread, and keeps them by version. With
/// an appearance, it also draws the pictures of the Markdown text parts of
/// the rows (card ^9ync5h3).
actor TranscriptRowHeightWorker {
  /// The width, the appearance and their generations of one computation of
  /// the cache.
  struct Pass: Sendable {
    /// The width of the rows.
    let width: CGFloat

    /// The width generation of the cache.
    let generation: Int

    /// The appearance of the pictures, or `nil` for no picture.
    let appearance: TranscriptTextAppearance?

    /// The appearance generation of the cache.
    let appearanceGeneration: Int
  }

  /// One row to compute.
  struct Job: Sendable {
    /// The copy of the row.
    let content: TranscriptRowContent

    /// The copy count of the row when it was copied.
    let revision: Int

    /// Whether the worker keeps the prepared parts of the row after the
    /// measure. The cache keeps them for the rows nearest the view only
    /// (``TranscriptRowHeights/preparedRank``).
    let keepsPrepared: Bool

    /// Makes a job.
    ///
    /// - Parameters:
    ///   - content: The copy of the row.
    ///   - revision: The copy count of the row when it was copied.
    ///   - keepsPrepared: Whether the worker keeps the prepared parts of
    ///     the row. The default is `true`.
    init(content: TranscriptRowContent, revision: Int, keepsPrepared: Bool = true) {
      self.content = content
      self.revision = revision
      self.keepsPrepared = keepsPrepared
    }
  }

  /// The height of one row.
  struct Result: Sendable {
    /// The row key.
    let rowKey: String

    /// The copy count of the row of the job.
    let revision: Int

    /// The height, or `nil` when no chrome rule covers the row.
    let height: CGFloat?

    /// Whether each text part of the row is exact with the text measure.
    let isExact: Bool

    /// The pictures of the text parts of the row, by part. A part that
    /// EditorKit does not draw has no picture.
    let pictures: [TranscriptTextPart: EditorStaticRendering]
  }

  /// A computed height of a row at one width.
  private struct Kept {
    /// The width.
    let width: CGFloat

    /// The content digest.
    let digest: Int

    /// The height, and whether it is exact.
    let measured: Measured

    /// The text parts that the chrome rule measured, in order.
    let parts: [MeasuredPart]
  }

  /// One text part of a row, at the width and the height of its measure.
  private struct MeasuredPart {
    /// The text part.
    let part: TranscriptTextPart

    /// The width that the view of the part gets.
    let width: CGFloat

    /// The measured height of the part.
    let height: CGFloat
  }

  /// The key of a drawn picture: the text part, the width of its measure,
  /// and the appearance. The measure of the worker is fixed, so the key
  /// also names the style of the picture: its theme, its font and its row
  /// height.
  private struct PictureKey: Hashable {
    /// The text part.
    let part: TranscriptTextPart

    /// The width.
    let width: CGFloat

    /// The appearance.
    let appearance: TranscriptTextAppearance
  }

  /// The height of a row from the rule, and whether each text part of the
  /// row is exact with the text measure.
  private struct Measured {
    /// The height, or `nil` when no chrome rule covers the row.
    let height: CGFloat?

    /// Whether each text part of the row is exact.
    let isExact: Bool
  }

  /// The most widths that the worker keeps for one row.
  static let widthLimit = 4

  /// The text measure.
  private let measure: any TranscriptTextMeasure

  /// The theme metrics.
  private let metrics: TranscriptRowMetrics

  /// The kept heights of each row, by row key, the newest last.
  private var kept: [String: [Kept]] = [:]

  /// The prepared text parts of each row (``TranscriptTextMeasure/prepared(_:)``),
  /// by row key: the parts of the last measure of the row. A measure of the
  /// row at a new width measures them again, with no new prepare.
  private var preparedParts: [String: [TranscriptTextPart: any PreparedTranscriptTextPart]] = [:]

  /// The row keys of ``preparedParts``, the newest measure last. The worker
  /// keeps the prepared parts of only the newest ``preparedRowLimit`` rows,
  /// as it keeps only the newest ``widthLimit`` widths of a row.
  private var preparedRows: [String] = []

  /// The default of the most rows whose prepared parts the worker keeps.
  /// The prepared parts of a row keep the shaped lines of its last width:
  /// about 100 KiB for a message of 4 KB.
  static let defaultPreparedRowLimit = 256

  /// The most rows whose prepared parts the worker keeps.
  private let preparedRowLimit: Int

  /// The count of text parts that the worker prepared for a measure.
  private(set) var prepareCount = 0

  /// The bytes in one mebibyte.
  static let bytesPerMebibyte = 1 << 20

  /// The default of the most mebibytes of the bitmaps of the pictures that
  /// the worker keeps, and that the cache publishes. A picture of an
  /// answer of 600 × 400 points at a scale of 2 takes about 4 MiB.
  static let defaultPictureMebibytes = 128

  /// The default of the most bytes of the bitmaps of the kept pictures.
  static let defaultPictureByteLimit = defaultPictureMebibytes * bytesPerMebibyte

  /// The largest difference between the height of a picture and the
  /// measured height of its part, in points.
  static let pictureHeightTolerance: CGFloat = 0.5

  /// The log of a picture that the worker cannot use.
  private static let logger = Logger(subsystem: "AgentViewKit", category: "TranscriptRowHeightWorker")

  /// The drawn pictures, by part, width and appearance, the newest last.
  private var drawnPictures: TranscriptPictureCache<PictureKey, EditorStaticRendering>

  /// Makes a worker.
  ///
  /// - Parameters:
  ///   - measure: The text measure.
  ///   - metrics: The theme metrics.
  ///   - preparedRowLimit: The most rows whose prepared parts the worker
  ///     keeps.
  ///   - pictureByteLimit: The most bytes of the bitmaps of the pictures
  ///     that the worker keeps.
  init(
    measure: any TranscriptTextMeasure, metrics: TranscriptRowMetrics,
    preparedRowLimit: Int = defaultPreparedRowLimit, pictureByteLimit: Int = defaultPictureByteLimit
  ) {
    self.measure = measure
    self.metrics = metrics
    self.preparedRowLimit = preparedRowLimit
    drawnPictures = TranscriptPictureCache(byteLimit: pictureByteLimit)
  }

  /// The heights of rows at a width, and the pictures of their text parts
  /// in an appearance. A version that the worker keeps is not
  /// computed again, and a picture that the worker keeps is not drawn
  /// again.
  ///
  /// - Parameters:
  ///   - jobs: The rows.
  ///   - width: The width.
  ///   - appearance: The appearance of the pictures, or `nil` (the default) for no
  ///     picture.
  /// - Returns: The height and the pictures of each row, in the order of
  ///   the jobs.
  func heights(of jobs: [Job], width: CGFloat, appearance: TranscriptTextAppearance? = nil) -> [Result] {
    jobs.map { job in
      let kept = kept(job.content, width: width, keepsPrepared: job.keepsPrepared)
      return Result(
        rowKey: job.content.rowKey, revision: job.revision, height: kept.measured.height,
        isExact: kept.measured.isExact, pictures: appearance.map { pictures(of: kept.parts, appearance: $0) } ?? [:])
    }
  }

  /// The pictures of the parts of a row, by part: the kept pictures, and
  /// the pictures that the measure draws. A part with no picture is not in
  /// the result.
  ///
  /// - Parameters:
  ///   - parts: The measured text parts of the row.
  ///   - appearance: The appearance of the pictures.
  /// - Returns: The pictures, by their parts.
  private func pictures(
    of parts: [MeasuredPart], appearance: TranscriptTextAppearance
  ) -> [TranscriptTextPart: EditorStaticRendering] {
    assert(!Thread.isMainThread, "the worker draws a picture on the main thread")
    let drawn = parts.compactMap { part in picture(of: part, appearance: appearance).map { (part.part, $0) } }
    return Dictionary(drawn) { _, last in last }
  }

  /// The picture of one part: the kept picture, or a new picture from the
  /// measure, which the worker then keeps as the newest.
  ///
  /// A picture whose height is not the measured height of its part is not
  /// used: the static row would then have another height than the cache
  /// gives it.
  ///
  /// - Parameters:
  ///   - part: The measured text part.
  ///   - appearance: The appearance of the picture.
  /// - Returns: The picture, or `nil` when the measure draws no picture of
  ///   the part.
  private func picture(of part: MeasuredPart, appearance: TranscriptTextAppearance) -> EditorStaticRendering? {
    let key = PictureKey(part: part.part, width: part.width, appearance: appearance)
    guard
      let picture = drawnPictures[key] ?? measure.picture(of: part.part, width: part.width, appearance: appearance)
    else { return nil }
    guard abs(picture.size.height - part.height) <= Self.pictureHeightTolerance else {
      assertionFailure("the picture height \(picture.size.height) is not the measured height \(part.height)")
      Self.logger.error("a picture has another height than its measure; the row keeps its text")
      return nil
    }
    drawnPictures.insert(picture, forKey: key)
    return picture
  }

  /// The height of one row at a width, and its measured text parts, from
  /// the kept heights or the rule.
  ///
  /// The row is exact when the text measure is exact for each text part
  /// that the rule measures. A row with no text part, such as a collapsed
  /// thought, has only chrome, so it is exact.
  ///
  /// - Parameters:
  ///   - content: The copy of the row.
  ///   - width: The width.
  ///   - keepsPrepared: Whether the worker keeps the prepared parts of the
  ///     row after the measure.
  /// - Returns: The height, whether it is exact, and the measured parts.
  private func kept(_ content: TranscriptRowContent, width: CGFloat, keepsPrepared: Bool) -> Kept {
    let key = content.rowKey
    let digest = content.hashValue
    var versions = kept[key, default: []]
    if let hit = versions.first(where: { $0.width == width && $0.digest == digest }) {
      return hit
    }
    var isExact = true
    var parts: [MeasuredPart] = []
    let height = withPreparedParts(of: key, keeps: keepsPrepared) { measurement in
      TranscriptRowChrome.height(of: content, width: width, metrics: metrics) { part, partWidth in
        let measured = measurement(part, partWidth)
        isExact = isExact && measured.isExact
        parts.append(MeasuredPart(part: part, width: partWidth, height: measured.height))
        return measured.height
      }
    }
    let computed = Kept(
      width: width, digest: digest, measured: Measured(height: height, isExact: isExact), parts: parts)
    versions.removeAll { $0.width == width }
    versions.append(computed)
    kept[key] = Array(versions.suffix(Self.widthLimit))
    return computed
  }

  /// Runs a measure of one row with the prepared parts of the row.
  ///
  /// The measure of a part takes its prepared value from the last measure
  /// of the row, or prepares the part. After the measure, a row that keeps
  /// its prepared parts keeps the parts that the measure used, and the
  /// worker drops the prepared parts of the oldest row past
  /// ``preparedRowLimit``. A row that does not keep them drops them, and
  /// pushes out no other row.
  ///
  /// - Parameters:
  ///   - key: The row key.
  ///   - keeps: Whether the row keeps its prepared parts.
  ///   - body: The measure of the row. It gets the measurement of a part at
  ///     a width.
  /// - Returns: The result of `body`.
  private func withPreparedParts<Value>(
    of key: String, keeps: Bool, _ body: ((TranscriptTextPart, CGFloat) -> TranscriptTextMeasurement) -> Value
  ) -> Value {
    let measure = measure
    var last = preparedParts.removeValue(forKey: key) ?? [:]
    var used: [TranscriptTextPart: any PreparedTranscriptTextPart] = [:]
    var prepares = 0
    let result = body { part, width in
      var prepared = used.removeValue(forKey: part) ?? last.removeValue(forKey: part) ?? {
        prepares += 1
        return measure.prepared(part)
      }()
      let measured = prepared.measurement(width: width)
      used[part] = prepared
      return measured
    }
    prepareCount += prepares
    if keeps {
      keep(used, for: key)
    } else {
      preparedRows.removeAll { $0 == key }
    }
    return result
  }

  /// Keeps the prepared parts of a row as the newest, and drops the
  /// prepared parts of the oldest rows past ``preparedRowLimit``.
  ///
  /// - Parameters:
  ///   - parts: The prepared parts of the row.
  ///   - key: The row key.
  private func keep(_ parts: [TranscriptTextPart: any PreparedTranscriptTextPart], for key: String) {
    preparedRows.removeAll { $0 == key }
    preparedRows.append(key)
    preparedParts[key] = parts
    for dropped in preparedRows.dropLast(preparedRowLimit) {
      preparedParts[dropped] = nil
    }
    preparedRows = Array(preparedRows.suffix(preparedRowLimit))
  }
}
