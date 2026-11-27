import CoreGraphics
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// The cache of the row heights computes each row of the transcript, the
/// rows in view first and then outward from them, so a row that a fast
/// flick reaches has its height before it comes into view (card ^9ync5h3).
///
/// Each test gives a transcript of ``rowCount`` agent answers to a cache
/// with a recording measure, and waits for the computation of the cache
/// (``TranscriptRowHeights/finishPendingHeights()``). The order of the
/// measured texts is the order of the computation.
@MainActor @Suite struct TranscriptRowHeightOrderTests {
  /// The number of rows of the transcript: more than the rows whose
  /// prepared parts the worker keeps
  /// (``TranscriptRowHeightWorker/defaultPreparedRowLimit``).
  static let rowCount = 300

  /// The positions of the rows in view.
  static let rowsInView = 250..<253

  /// The position of a row next to the rows in view.
  static let nearRow = 248

  /// The position of a row 200 rows from the rows in view.
  static let farRow = 50

  /// The positions of the rows in view at the end of the transcript.
  static let lastRowsInView = 297..<300

  /// A cache of the rows of a transcript of answers, with a recording
  /// measure.
  struct Bed {
    /// The session that holds the entries.
    let session: SessionModel

    /// The cache.
    let heights: TranscriptRowHeights

    /// The measure of the cache.
    let measure: RecordingTextMeasure

    /// The name of the answer texts (``AnswerText/answer(_:in:withCodeFence:)``).
    let name: String

    /// The entries of the transcript.
    var entries: [TranscriptEntry] {
      session.transcript
    }

    /// The row key of the entry at a position.
    ///
    /// - Parameter position: The position in the transcript.
    /// - Returns: The row key.
    func rowKey(at position: Int) -> String {
      entries[position].rowKey
    }

    /// The place of the first measure of the row at a position in the order
    /// of the measures, or `nil` when the measure did not measure the row.
    ///
    /// - Parameter position: The position in the transcript.
    /// - Returns: The index of the first measured text of the row.
    func measureOrder(of position: Int) -> Int? {
      let marker = "\(name) answer \(position):"
      return measure.measuredTexts.firstIndex { $0.contains(marker) }
    }
  }

  /// Makes a cache of ``rowCount`` answers of `name`, with no rows given
  /// yet.
  ///
  /// - Parameter name: The name of the answer texts of the test.
  /// - Returns: The bed.
  static func emptyBed(_ name: String) -> Bed {
    let measure = RecordingTextMeasure()
    return Bed(
      session: .preview(transcript: AnswerText.transcript(count: rowCount, in: name)),
      heights: TranscriptRowHeights(measure: measure, metrics: TranscriptRowMetrics.probe()), measure: measure,
      name: name)
  }

  /// Gives the transcript of a new bed to its cache at the width of the
  /// row height tests, and waits until the cache has computed each row.
  ///
  /// - Parameters:
  ///   - name: The name of the answer texts of the test.
  ///   - rowsInView: The positions of the rows in view.
  /// - Returns: The bed.
  static func computedBed(_ name: String, rowsInView: Range<Int>) async -> Bed {
    let bed = emptyBed(name)
    bed.heights.update(entries: bed.entries, width: TranscriptRowHeightsTests.width, rowsInView: rowsInView)
    await bed.heights.finishPendingHeights()
    return bed
  }

  /// A production change that fails this test: the cache computes only the
  /// rows in view and near them, so a row that a flick reaches later has
  /// no height when it comes into view.
  @Test func theCacheHoldsTheHeightOfARowFarFromTheViewAfterTheTranscriptIsSet() async {
    let bed = await Self.computedBed("farRow", rowsInView: Self.rowsInView)

    #expect(bed.heights.height(of: bed.rowKey(at: Self.farRow)) != nil)
  }

  /// A production change that fails this test: the cache computes the
  /// rows in transcript order, so the rows in view wait for each row
  /// before them.
  @Test func theCacheMeasuresTheRowsInViewBeforeTheRowsNextToThem() async throws {
    let bed = await Self.computedBed("inViewFirst", rowsInView: Self.rowsInView)
    let inView = try #require(bed.measureOrder(of: Self.rowsInView.upperBound - 1))
    let near = try #require(bed.measureOrder(of: Self.nearRow))

    #expect(inView < near)
  }

  /// A production change that fails this test: the cache computes the
  /// rows out of view in transcript order, so a row far above the view
  /// gets its height before a row next to the view.
  @Test func theCacheMeasuresARowNearTheViewBeforeARowFarFromIt() async throws {
    let bed = await Self.computedBed("nearFirst", rowsInView: Self.rowsInView)
    let near = try #require(bed.measureOrder(of: Self.nearRow))
    let far = try #require(bed.measureOrder(of: Self.farRow))

    #expect(near < far)
  }

  /// A production change that fails this test: with no row in view, the
  /// cache computes the rows in transcript order, so the last rows, which
  /// a thread shows first, get their heights last.
  @Test func withNoRowInViewTheCacheMeasuresTheLastRowFirst() async throws {
    let bed = await Self.computedBed("lastFirst", rowsInView: .zero ..< .zero)
    let last = try #require(bed.measureOrder(of: Self.rowCount - 1))
    let first = try #require(bed.measureOrder(of: .zero))

    #expect(last < first)
  }

  /// A production change that fails this test: the heights of the static
  /// rows record the rows in view, and the cache keeps the order of the
  /// first feed, so a row in view waits for the rows that the cache took
  /// before it.
  @Test func theRowsInViewOfTheStaticRowsComeFirstInTheCache() async throws {
    let bed = Self.emptyBed("staticRowsInView")
    let heights = TranscriptStaticRowHeights()
    heights.attach(cache: bed.heights, session: bed.session)
    heights.noteRowWidth(TranscriptRowHeightsTests.width)

    heights.noteRowsInView(positions: [Self.farRow])
    await bed.heights.finishPendingHeights()

    let inView = try #require(bed.measureOrder(of: Self.farRow))
    let first = try #require(bed.measureOrder(of: .zero))
    #expect(inView < first)
  }

  /// A production change that fails this test: the worker keeps the
  /// prepared parts of the rows that it measured last, which are the rows
  /// far from the view, so a new width prepares the rows in view again.
  @Test func aNewWidthPreparesNoRowInViewAgainInALongTranscript() async {
    let bed = await Self.computedBed("preparedInView", rowsInView: Self.lastRowsInView)
    let prepares = await bed.heights.prepareCount()
    _ = bed.heights.register(bed.entries, width: TranscriptRowHeightsTests.newWidth)

    await bed.heights.computeHeights(of: Self.lastRowsInView.map(bed.rowKey(at:)))

    #expect(await bed.heights.prepareCount() == prepares)
  }
}
