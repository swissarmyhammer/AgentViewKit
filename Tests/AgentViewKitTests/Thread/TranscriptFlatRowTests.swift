import AppKit
import EditorTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// The flat form of a static row: one view of the pictures of the row, in a
/// frame of the exact height of the row (card ^9ync5h3).
///
/// While the rows move, a row with an exact height, a picture of each text
/// part and a picture of each chrome line shows one flat view
/// (``TranscriptFlatRow``) in place of the views of the real row. Each row
/// shows in a ``StaticRowHost``: a borderless window that is never ordered
/// in.
@MainActor @Suite struct TranscriptFlatRowTests {
  /// The width of the rows, in points.
  static let width: CGFloat = 480

  /// The row kinds that show the flat form: a user message, an agent
  /// message of prose, an agent message with a code fence, a closed
  /// thought and a closed tool call.
  nonisolated static let flatRows: [TranscriptRowFixtures.Row] = [
    .userMessage, .agentProse, .agentFenced, .thought, .toolCall,
  ]

  /// The largest difference between the heights of the two forms of a row,
  /// in points.
  static let heightTolerance: CGFloat = 0.5

  /// The ``BodyEvaluationCounter`` keys of the views of the real row of a
  /// row key: the row, the item view, the content of the entry, the first
  /// response and the header of a tool call.
  ///
  /// - Parameter rowKey: The row key of the entry.
  /// - Returns: The keys.
  static func realViewKeys(of rowKey: String) -> [String] {
    [
      ItemRow.counterKey(for: rowKey), ItemRow.contentCounterKey(for: rowKey),
      EntryContentView.counterKey(for: rowKey),
      ResponseView.counterKey(for: EntryContentView.blockID(entryID: rowKey, index: 0)),
      ToolCallView.rowCounterKey(for: rowKey),
    ]
  }

  /// Shows the row of a host again as a new row that comes into the list
  /// while the rows move, and counts the body evaluations of the views of
  /// its real row in that one layout.
  ///
  /// The count starts after the last `await` of the test, so no other test
  /// evaluates a row of the same row key while it counts.
  ///
  /// - Parameter host: The host of the row, from
  ///   ``StaticRowHost/makeCached(_:width:frames:movesLive:colorScheme:)``.
  /// - Returns: The count.
  static func realViewBodies(whenEntering host: StaticRowHost) -> Int {
    let keys = realViewKeys(of: host.entry.rowKey)
    BodyEvaluationCounter.reset(keys)
    host.enterWhileMoving()
    return keys.map(BodyEvaluationCounter.count).reduce(.zero, +)
  }

  // MARK: - The views

  /// A production change that fails this test: a row that comes into a
  /// moving list with an exact height and each of its pictures builds the
  /// views of its real row (the item view, its content, its responses,
  /// its buttons), and SwiftUI measures them in each frame of the motion.
  @Test(arguments: flatRows)
  func aRowThatEntersWhileMovingBuildsNoViewOfTheRealRow(row: TranscriptRowFixtures.Row) async {
    let host = await StaticRowHost.makeCached(row, width: Self.width)

    #expect(Self.realViewBodies(whenEntering: host) == 0)
  }

  /// The most layouts of a flat row that comes into a moving list: one
  /// size computation and one placement.
  static let flatLayoutLimit = 2

  /// A production change that fails this test: the flat form of a row asks
  /// SwiftUI for more than one body and one layout pass of its parts when
  /// it comes into a moving list, such as a stack that measures each part.
  @Test(arguments: flatRows)
  func aFlatRowThatEntersHasOneBodyAndOneLayoutPass(row: TranscriptRowFixtures.Row) async {
    let host = await StaticRowHost.makeCached(row, width: Self.width)
    let rowKey = host.entry.rowKey
    let keys = [TranscriptFlatRow.counterKey(for: rowKey), TranscriptFlatRowLayout.counterKey(for: rowKey)]
    BodyEvaluationCounter.reset(keys)

    host.enterWhileMoving()

    #expect(
      BodyEvaluationCounter.count(keys[0]) == 1 && BodyEvaluationCounter.count(keys[1]) <= Self.flatLayoutLimit,
      "\(keys.map(BodyEvaluationCounter.count))")
  }

  /// A production change that fails this test: each flat row that comes
  /// into the list draws the pictures of its chrome lines again, so each
  /// new row runs the renderer on the main thread.
  @Test func aFlatRowThatEntersAgainDrawsNoChromePicture() async {
    let header = TranscriptToolCallHeader(
      title: "Read Sources/FlatRow/Chrome.swift", kind: .read, status: .completed, isExpanded: false)
    let host = await StaticRowHost.makeCached(
      .toolCall(title: header.title, kind: header.kind, status: header.status), width: Self.width)
    let key = TranscriptChromePictures.counterKey(for: .toolCallHeader(header))
    BodyEvaluationCounter.reset(key)

    host.enterWhileMoving()

    #expect(BodyEvaluationCounter.count(key) == 0)
  }

  /// A production change that fails this test: a message row with a footer
  /// shows the flat form, which draws no footer, so the actions of the
  /// footer go while the rows move.
  @Test func aMessageWithAFooterKeepsTheViewsOfItsRealRow() async {
    let host = await StaticRowHost.makeCached(.agentProse, width: Self.width)
    host.messageFooter = { entry in AnyView(MessageActions(entry: entry)) }

    #expect(Self.realViewBodies(whenEntering: host) > 0)
  }

  /// A production change that fails this test: a row with a find hit shows
  /// the flat form, which draws no find mark.
  @Test func aRowWithAFindHitKeepsTheViewsOfItsRealRow() async throws {
    let host = await StaticRowHost.makeCached(.agentProse, width: Self.width)
    let search = TranscriptSearch()
    host.search = search
    let id = try #require(host.entry.wireID, "the entry has no wire id")
    search.show(TranscriptSearchTests.hits([id]), in: host.session)

    #expect(Self.realViewBodies(whenEntering: host) > 0)
  }

  /// A production change that fails this test: the flat form of a row has
  /// another height than its real row, so the row jumps when it becomes
  /// real at rest.
  @Test(arguments: flatRows)
  func aFlatRowKeepsItsHeightWhenItBecomesReal(row: TranscriptRowFixtures.Row) async throws {
    let host = await StaticRowHost.makeCached(row, width: Self.width)
    try #require(Self.realViewBodies(whenEntering: host) == 0)
    let flat = host.rowHeight

    host.showAtRestAndSettle()

    #expect(abs(host.rowHeight - flat) <= Self.heightTolerance, "flat \(flat), real \(host.rowHeight)")
  }

  // MARK: - The pixels

  /// A production change that fails this test: the flat form draws the
  /// chrome or the text of a row in other fonts, colors or places than the
  /// real row, in light or in dark.
  @Test(arguments: flatRows, [ColorScheme.light, .dark])
  func theFlatRowIsNearTheRealRow(row: TranscriptRowFixtures.Row, colorScheme: ColorScheme) async throws {
    let host = await StaticRowHost.makeCached(row, width: Self.width, colorScheme: colorScheme)
    try #require(Self.realViewBodies(whenEntering: host) == 0)
    let flat = try host.bitmap()
    host.showAtRestAndSettle()
    await host.awaitSegmentParses()
    let real = try host.bitmap()

    let difference = try RowPixelDifference.between(
      flat, and: real, over: RowPixelDifference.background(of: colorScheme))

    #expect(
      difference.isWithin(
        meanLimit: TranscriptStaticPictureTests.meanLimit, largePartLimit: TranscriptStaticPictureTests.largePartLimit),
      "\(difference)")
  }

  // MARK: - Accessibility

  /// A production change that fails this test: the flat form of a row is
  /// not one accessibility element with the text of the row, so an
  /// assistive app reads no text of the row while the rows move.
  @Test func aFlatRowIsOneAccessibilityElementWithTheTextOfTheRow() async throws {
    let host = await StaticRowHost.makeCached(.agentProse, width: Self.width)
    try #require(Self.realViewBodies(whenEntering: host) == 0)

    let labels = try await withAccessibilityTree {
      host.accessibilityElements(identifiedAs: StaticSlotAccessibility.identifier).map {
        accessibilityLabel(of: $0) ?? ""
      }
    }

    #expect(labels.count == 1 && labels.allSatisfy { $0.contains(TranscriptRowFixtures.paragraph) }, "\(labels)")
  }

  /// A production change that fails this test: an accessibility press on
  /// the flat form of a row that waits at rest does not make the row real.
  @Test func anAccessibilityPressOnAWaitingFlatRowMakesTheRowReal() async throws {
    let frames = ManualFrames()
    let host = await StaticRowHost.makeCached(.agentProse, width: Self.width, frames: frames)
    try #require(Self.realViewBodies(whenEntering: host) == 0)
    PendingRunLoopBlocks.run()
    host.show(rowsMove: false)
    try #require(host.textViewCount == 0)

    try await withAccessibilityTree {
      let still = try #require(host.accessibilityElements(identifiedAs: StaticSlotAccessibility.identifier).first)
      _ = try performAccessibilityPress(on: still)
    }
    host.layOut()

    #expect(host.textViewCount > 0)
  }
}
