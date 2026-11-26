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
///   version that the worker knows is not computed again.
/// - The cache publishes the heights to the main actor, as observable
///   values. After a width change, it computes each row again, the rows in
///   view first, and publishes the rows in view before the other rows.
@MainActor @Observable public final class TranscriptRowHeights {
  /// The published height of each row at ``width``, by row key. A row that
  /// no chrome rule covers has no height.
  private var heights: [String: CGFloat] = [:]

  /// The same heights, not observable, for the static rows
  /// (``TranscriptRowHeightProvider``): a new height does not make a row
  /// evaluate its body again.
  @ObservationIgnored private var unobservedHeights: [String: CGFloat] = [:]

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
  ///     ``InterimTranscriptTextMeasure``, until EditorKit's exact measure is
  ///     on EditorKit main.
  ///   - metrics: The theme metrics of the rows.
  ///   - expandedBlocks: The store that tells whether the blocks of a row are
  ///     expanded, or `nil` when each block is collapsed.
  public init(
    measure: any TranscriptTextMeasure = InterimTranscriptTextMeasure(), metrics: TranscriptRowMetrics,
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
    self.width = width
    var changed: [String] = []
    for entry in entries where objects[entry.rowKey] != ObjectIdentifier(entry.object) {
      copy(entry)
      changed.append(entry.rowKey)
    }
    let inView = Set(entries.indices.clamped(to: rowsInView).map { entries[$0].rowKey })
    guard widthChanged else {
      compute(changed, inView: inView)
      return
    }
    generation += 1
    heights = [:]
    unobservedHeights = [:]
    compute(entries.map(\.rowKey), inView: inView)
  }

  /// The height of a row at the width of the last update.
  ///
  /// - Parameter rowKey: The row key of the entry.
  /// - Returns: The height, or `nil` before it is computed or when no chrome
  ///   rule covers the row.
  public func height(of rowKey: String) -> CGFloat? {
    heights[rowKey]
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

  /// Computes the heights of rows on the worker, and publishes them: the
  /// rows in view first, then the other rows.
  ///
  /// - Parameters:
  ///   - keys: The row keys.
  ///   - inView: The row keys of the rows in view.
  private func compute(_ keys: [String], inView: Set<String>) {
    let jobs = keys.compactMap { key in
      contents[key].map { TranscriptRowHeightWorker.Job(content: $0, revision: revisions[key, default: .zero]) }
    }
    guard !jobs.isEmpty else { return }
    let first = jobs.filter { inView.contains($0.content.rowKey) }
    let rest = jobs.filter { !inView.contains($0.content.rowKey) }
    let width = width
    let generation = generation
    let worker = worker
    Task {
      for batch in [first, rest] where !batch.isEmpty {
        let results = await worker.heights(of: batch, width: width)
        publish(results, generation: generation)
      }
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
      unobservedHeights[result.rowKey] = result.height
    }
  }
}

/// The cache is the height provider of the static rows (^9ync5h3): a row
/// whose height the cache knows can show its static form from its first
/// frame.
extension TranscriptRowHeights: TranscriptRowHeightProvider {
  func knowsHeight(of id: TranscriptEntry.ID) -> Bool {
    unobservedHeights[id.rowKey] != nil
  }

  func height(of id: TranscriptEntry.ID, width: CGFloat) -> CGFloat? {
    guard abs(width - self.width) <= TranscriptMeasuredRowHeights.widthTolerance else { return nil }
    return unobservedHeights[id.rowKey]
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
  }

  /// A computed height of a row at one width.
  private struct Kept {
    /// The width.
    let width: CGFloat

    /// The content digest.
    let digest: Int

    /// The height.
    let height: CGFloat?
  }

  /// The most widths that the worker keeps for one row.
  static let widthLimit = 4

  /// The text measure.
  private let measure: any TranscriptTextMeasure

  /// The theme metrics.
  private let metrics: TranscriptRowMetrics

  /// The kept heights of each row, by row key, the newest last.
  private var kept: [String: [Kept]] = [:]

  /// Makes a worker.
  ///
  /// - Parameters:
  ///   - measure: The text measure.
  ///   - metrics: The theme metrics.
  init(measure: any TranscriptTextMeasure, metrics: TranscriptRowMetrics) {
    self.measure = measure
    self.metrics = metrics
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
      Result(rowKey: job.content.rowKey, revision: job.revision, height: height(of: job.content, width: width))
    }
  }

  /// The height of one row at a width, from the kept heights or the rule.
  ///
  /// - Parameters:
  ///   - content: The copy of the row.
  ///   - width: The width.
  /// - Returns: The height.
  private func height(of content: TranscriptRowContent, width: CGFloat) -> CGFloat? {
    let key = content.rowKey
    let digest = content.hashValue
    var versions = kept[key, default: []]
    if let hit = versions.first(where: { $0.width == width && $0.digest == digest }) {
      return hit.height
    }
    let measure = measure
    let height = TranscriptRowChrome.height(of: content, width: width, metrics: metrics) {
      measure.height(of: $0, width: $1)
    }
    versions.removeAll { $0.width == width }
    versions.append(Kept(width: width, digest: digest, height: height))
    kept[key] = Array(versions.suffix(Self.widthLimit))
    return height
  }
}
