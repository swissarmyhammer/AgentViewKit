import CoreGraphics
import FoundationModelsACPClient
import Observation

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
/// - The cache publishes the heights to the main actor, as observable
///   values. After a width change, it computes each row again, the rows in
///   view first, and publishes the rows in view before the other rows.
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

  /// Makes a cache.
  ///
  /// - Parameters:
  ///   - measure: The text measure. The default is
  ///     ``EditorLayoutTranscriptTextMeasure`` in the default theme, which
  ///     uses EditorKit's `EditorLayoutMeasure`.
  ///   - metrics: The theme metrics of the rows.
  ///   - expandedBlocks: The store that tells whether the blocks of a row are
  ///     expanded, or `nil` when each block is collapsed.
  public init(
    measure: any TranscriptTextMeasure = EditorLayoutTranscriptTextMeasure(), metrics: TranscriptRowMetrics,
    expandedBlocks: ExpandedBlocksStore? = nil
  ) {
    worker = TranscriptRowHeightWorker(measure: measure, metrics: metrics)
    self.expandedBlocks = expandedBlocks
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
  /// height. When the width changes, it computes each row again, the rows in
  /// view first.
  ///
  /// - Parameters:
  ///   - entries: The transcript entries, in the order of the rows.
  ///   - width: The width of the rows.
  ///   - rowsInView: The indices of the rows in view.
  public func update(entries: [TranscriptEntry], width: CGFloat, rowsInView: Range<Int>) {
    let widthChanged = width != self.width
    let changed = register(entries, width: width)
    let inView = Set(entries.indices.clamped(to: rowsInView).map { entries[$0].rowKey })
    compute(widthChanged ? entries.map(\.rowKey) : changed, inView: inView)
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
    compute([entry.rowKey], inView: [])
  }

  /// Computes the heights of rows on the worker in a new task, and
  /// publishes them: the rows in view first, then the other rows.
  ///
  /// - Parameters:
  ///   - keys: The row keys.
  ///   - inView: The row keys of the rows in view.
  private func compute(_ keys: [String], inView: Set<String>) {
    let batches = batches(of: keys, inView: inView)
    guard !batches.isEmpty else { return }
    let width = width
    let generation = generation
    let previous = computation
    computation = Task {
      await previous?.value
      await self.computeHeights(in: batches, width: width, generation: generation)
    }
  }

  /// The last computation that the cache started.
  @ObservationIgnored private var computation: Task<Void, Never>?

  /// Returns when the cache has computed each row that it started to
  /// compute.
  func finishPendingHeights() async {
    await computation?.value
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
    await computeHeights(in: batches(of: rowKeys, inView: []), width: width, generation: generation)
  }

  /// The jobs of the copied rows of `keys`, in batches: the rows in view,
  /// then the other rows. A batch with no job is not in the list.
  ///
  /// - Parameters:
  ///   - keys: The row keys.
  ///   - inView: The row keys of the rows in view.
  /// - Returns: The batches, in the order of their computation.
  private func batches(of keys: [String], inView: Set<String>) -> [[TranscriptRowHeightWorker.Job]] {
    let jobs = keys.compactMap { key in
      contents[key].map { TranscriptRowHeightWorker.Job(content: $0, revision: revisions[key, default: .zero]) }
    }
    let first = jobs.filter { inView.contains($0.content.rowKey) }
    let rest = jobs.filter { !inView.contains($0.content.rowKey) }
    return [first, rest].filter { !$0.isEmpty }
  }

  /// Computes each batch on the worker, off the main thread, and publishes
  /// its results on the main actor before the next batch.
  ///
  /// - Parameters:
  ///   - batches: The batches of jobs, in the order of their computation.
  ///   - width: The width of the rows.
  ///   - generation: The width generation of the jobs.
  private func computeHeights(
    in batches: [[TranscriptRowHeightWorker.Job]], width: CGFloat, generation: Int
  ) async {
    for batch in batches {
      let results = await worker.heights(of: batch, width: width)
      publish(results, generation: generation)
    }
  }

  /// Publishes the results of the worker that are still current.
  ///
  /// - Parameters:
  ///   - results: The results.
  ///   - generation: The width generation of the results.
  private func publish(_ results: [TranscriptRowHeightWorker.Result], generation: Int) {
    guard generation == self.generation else { return }
    for result in results where revisions[result.rowKey] == result.revision {
      heights[result.rowKey] = result.height
      exactHeights[result.rowKey] = result.isExact ? result.height : nil
    }
  }
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

/// Computes row heights off the main thread, and keeps them by version.
actor TranscriptRowHeightWorker {
  /// One row to compute.
  struct Job: Sendable {
    /// The copy of the row.
    let content: TranscriptRowContent

    /// The copy count of the row when it was copied.
    let revision: Int
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
  }

  /// A computed height of a row at one width.
  private struct Kept {
    /// The width.
    let width: CGFloat

    /// The content digest.
    let digest: Int

    /// The height, and whether it is exact.
    let measured: Measured
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

  /// Makes a worker.
  ///
  /// - Parameters:
  ///   - measure: The text measure.
  ///   - metrics: The theme metrics.
  ///   - preparedRowLimit: The most rows whose prepared parts the worker
  ///     keeps.
  init(
    measure: any TranscriptTextMeasure, metrics: TranscriptRowMetrics,
    preparedRowLimit: Int = defaultPreparedRowLimit
  ) {
    self.measure = measure
    self.metrics = metrics
    self.preparedRowLimit = preparedRowLimit
  }

  /// The heights of rows at a width. A version that the worker keeps is not
  /// computed again.
  ///
  /// - Parameters:
  ///   - jobs: The rows.
  ///   - width: The width.
  /// - Returns: The height of each row, in the order of the jobs.
  func heights(of jobs: [Job], width: CGFloat) -> [Result] {
    jobs.map { job in
      let measured = measured(job.content, width: width)
      return Result(
        rowKey: job.content.rowKey, revision: job.revision, height: measured.height, isExact: measured.isExact)
    }
  }

  /// The height of one row at a width, from the kept heights or the rule.
  ///
  /// The row is exact when the text measure is exact for each text part
  /// that the rule measures. A row with no text part, such as a collapsed
  /// thought, has only chrome, so it is exact.
  ///
  /// - Parameters:
  ///   - content: The copy of the row.
  ///   - width: The width.
  /// - Returns: The height, and whether it is exact.
  private func measured(_ content: TranscriptRowContent, width: CGFloat) -> Measured {
    let key = content.rowKey
    let digest = content.hashValue
    var versions = kept[key, default: []]
    if let hit = versions.first(where: { $0.width == width && $0.digest == digest }) {
      return hit.measured
    }
    var isExact = true
    let height = withPreparedParts(of: key) { measurement in
      TranscriptRowChrome.height(of: content, width: width, metrics: metrics) { part, partWidth in
        let measured = measurement(part, partWidth)
        isExact = isExact && measured.isExact
        return measured.height
      }
    }
    let measured = Measured(height: height, isExact: isExact)
    versions.removeAll { $0.width == width }
    versions.append(Kept(width: width, digest: digest, measured: measured))
    kept[key] = Array(versions.suffix(Self.widthLimit))
    return measured
  }

  /// Runs a measure of one row with the prepared parts of the row.
  ///
  /// The measure of a part takes its prepared value from the last measure
  /// of the row, or prepares the part. After the measure, the row keeps the
  /// prepared parts that the measure used, and the worker drops the
  /// prepared parts of the oldest row past ``preparedRowLimit``.
  ///
  /// - Parameters:
  ///   - key: The row key.
  ///   - body: The measure of the row. It gets the measurement of a part at
  ///     a width.
  /// - Returns: The result of `body`.
  private func withPreparedParts<Value>(
    of key: String, _ body: ((TranscriptTextPart, CGFloat) -> TranscriptTextMeasurement) -> Value
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
    keep(used, for: key)
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
