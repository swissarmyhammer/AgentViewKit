@testable import AgentViewKit
import AgentViewKitTestSupport
import CoreGraphics
import Testing

/// A streamed append never unpins a thread that follows the bottom, in each
/// order of the events of the list (task ^fmaanyq).
///
/// After an append, ``ConversationView`` tells the manager of the new last
/// row, and the manager sends its scroll to the new end on the next
/// main-actor tick. Until the list applies that scroll, the list shows the
/// old end. In that time, the list can send a visibility report or a
/// geometry change. Under load, such a report came before the scroll, and it
/// unpinned the manager (`ThreadFloatingControlsHostedTests`).
///
/// Each test calls the manager as the handlers of ``ConversationView`` do,
/// in a fixed order:
///
/// - The visibility action tells the manager of the new last row first, and
///   then gives the rows in view, with a distance of zero when the list was
///   near the bottom at the last geometry change, else with the largest
///   distance.
/// - The geometry action gives the rows that the manager holds, with the new
///   near state.
///
/// The tests do not use a window or a run loop, so the order of the events
/// does not change with the load of the machine.
@Suite @MainActor struct ConversationStreamedAppendPinTests {
  /// The distance that the list gives when the list is near the bottom.
  private static let nearBottom: CGFloat = 0

  /// The distance that the list gives when the list is not near the bottom.
  private static let awayFromBottom = CGFloat.greatestFiniteMagnitude

  /// Lets each main-actor task that is scheduled now run to its end.
  private static func runScheduledTasks() async {
    await Task {}.value
  }

  /// Makes a manager whose list shows its last rows "b" and "c" at the
  /// bottom, and then appends the row "d" of a streamed turn.
  ///
  /// The list has not applied the scroll to the new end yet.
  ///
  /// - Parameter scrolls: The recorder that gets the scroll targets.
  /// - Returns: The manager, after the append.
  private static func makeAppendedManager(scrolls: ReportRecorder<ScrollAnchorTarget>) -> ScrollAnchorManager {
    let manager = ScrollAnchorManager { scrolls.report($0) }
    manager.noteAppended(ids: ["a", "b", "c"])
    manager.noteVisible(ids: ["b", "c"], distanceFromBottom: nearBottom)
    manager.noteAppended(ids: ["d"])
    return manager
  }

  /// A production change that fails this test: a visibility report of the
  /// old end, after the append and before the scroll to the new end, unpins
  /// the manager, because the report does not hold the new last row.
  @Test func aReportOfTheOldEndBeforeTheScrollKeepsThePin() {
    let manager = Self.makeAppendedManager(scrolls: ReportRecorder())

    manager.noteVisible(ids: ["b", "c"], distanceFromBottom: Self.nearBottom)

    #expect(manager.isPinnedToBottom)
    #expect(manager.newItemsSinceUnpinned == 0)
  }

  /// A production change that fails this test: the geometry action of the
  /// taller content, after the append and before the scroll to the new end,
  /// unpins the manager.
  @Test func aGeometryChangeOfTheTallerContentBeforeTheScrollKeepsThePin() {
    let manager = Self.makeAppendedManager(scrolls: ReportRecorder())

    manager.noteVisible(ids: manager.visibleIDs, distanceFromBottom: Self.awayFromBottom)

    #expect(manager.isPinnedToBottom)
  }

  /// A production change that fails this test: a report that shows the top
  /// of the new row, before the scroll puts the end of the row in view,
  /// unpins the manager.
  @Test func aReportOfThePartOfTheNewRowBeforeTheScrollKeepsThePin() {
    let manager = Self.makeAppendedManager(scrolls: ReportRecorder())

    manager.noteVisible(ids: ["c", "d"], distanceFromBottom: Self.awayFromBottom)

    #expect(manager.isPinnedToBottom)
  }

  /// The manager sent the scroll, and the list did not apply it yet, as when
  /// the hosted test holds the scroll. A report of the old end keeps the pin.
  @Test func aReportOfTheOldEndAfterTheSentScrollKeepsThePin() async {
    let scrolls = ReportRecorder<ScrollAnchorTarget>()
    let manager = Self.makeAppendedManager(scrolls: scrolls)
    await Self.runScheduledTasks()
    #expect(scrolls.values == [.bottom])

    manager.noteVisible(ids: ["b", "c"], distanceFromBottom: Self.awayFromBottom)

    #expect(manager.isPinnedToBottom)
  }

  /// Each append of a stream adds its row to the end that the manager waits
  /// for. A report of an earlier row of the stream keeps the pin.
  @Test func aReportOfAnEarlierRowOfTheStreamKeepsThePin() {
    let manager = Self.makeAppendedManager(scrolls: ReportRecorder())
    manager.noteAppended(ids: ["e"])

    manager.noteVisible(ids: ["b", "c"], distanceFromBottom: Self.nearBottom)
    manager.noteVisible(ids: ["c", "d"], distanceFromBottom: Self.awayFromBottom)

    #expect(manager.isPinnedToBottom)
  }

  /// A new last row that the list did not append, such as after a removal,
  /// keeps the pin in the same way.
  @Test func aReportOfTheOldEndAfterANewLastItemKeepsThePin() {
    let manager = ScrollAnchorManager()
    manager.noteAppended(ids: ["a", "b", "c"])
    manager.noteVisible(ids: ["b", "c"], distanceFromBottom: Self.nearBottom)
    manager.noteLastItemChanged(to: "b")

    manager.noteVisible(ids: ["a", "b"], distanceFromBottom: Self.awayFromBottom)

    #expect(manager.isPinnedToBottom)
  }

  // MARK: - End of the wait

  @Test func aReportOfTheRowsAboveTheOldEndUnpins() {
    let manager = Self.makeAppendedManager(scrolls: ReportRecorder())

    // The user scrolls up, past the old end.
    manager.noteVisible(ids: ["a", "b"], distanceFromBottom: Self.awayFromBottom)

    #expect(!manager.isPinnedToBottom)
  }

  @Test func theReportOfTheNewEndEndsTheWait() {
    let manager = Self.makeAppendedManager(scrolls: ReportRecorder())
    manager.noteVisible(ids: ["c", "d"], distanceFromBottom: Self.nearBottom)

    // The user scrolls up a little, and the old end stays in view.
    manager.noteVisible(ids: ["b", "c"], distanceFromBottom: Self.awayFromBottom)

    #expect(!manager.isPinnedToBottom)
  }

  @Test func aScrollOfTheUserEndsTheWait() {
    let manager = Self.makeAppendedManager(scrolls: ReportRecorder())

    manager.noteScrollByUser()
    manager.noteVisible(ids: ["b", "c"], distanceFromBottom: Self.awayFromBottom)

    #expect(!manager.isPinnedToBottom)
  }

  @Test func aJumpEndsTheWait() {
    let manager = Self.makeAppendedManager(scrolls: ReportRecorder())

    manager.noteJump(to: "b")
    manager.noteVisible(ids: ["b", "c"], distanceFromBottom: Self.awayFromBottom)

    #expect(!manager.isPinnedToBottom)
  }

  @Test func anAppendWhileUnpinnedStartsNoWait() {
    let manager = ScrollAnchorManager()
    manager.noteAppended(ids: ["a", "b", "c"])
    manager.noteVisible(ids: ["a", "b"], distanceFromBottom: Self.awayFromBottom)
    manager.noteAppended(ids: ["d"])

    manager.noteVisible(ids: ["c", "d"], distanceFromBottom: Self.awayFromBottom)

    #expect(!manager.isPinnedToBottom)
    #expect(manager.newItemsSinceUnpinned == 1)
  }
}
