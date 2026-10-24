@testable import AgentViewKit
import CoreGraphics
import Testing

@Suite @MainActor struct ScrollAnchorManagerTests {
  /// A distance from the bottom that is in the tolerance of the manager.
  private static let distanceInsideTolerance: CGFloat = 10

  /// A distance from the bottom that is not in the tolerance of the manager.
  private static let distanceOutsideTolerance: CGFloat = 40

  /// The tolerance of each manager in these tests.
  private static let tolerance: CGFloat = 24

  /// Makes a manager that sends its scroll targets to `recorder`.
  private static func makeManager(recorder: ReportRecorder<ScrollAnchorTarget>) -> ScrollAnchorManager {
    ScrollAnchorManager(tolerance: tolerance) { recorder.report($0) }
  }

  /// Lets each main-actor task that is scheduled now run to its end.
  private static func runScheduledTasks() async {
    await Task {}.value
  }

  // MARK: - Pin

  @Test func aNewManagerIsPinnedWithNoCount() {
    let manager = ScrollAnchorManager()

    #expect(manager.isPinnedToBottom)
    #expect(manager.newItemsSinceUnpinned == 0)
    #expect(manager.visibleIDs.isEmpty)
    #expect(manager.anchorID == nil)
    #expect(manager.tolerance == ScrollAnchorManager.defaultTolerance)
  }

  @Test func theLastIdInsideTheToleranceIsPinned() {
    let recorder = ReportRecorder<ScrollAnchorTarget>()
    let manager = Self.makeManager(recorder: recorder)
    manager.noteAppended(ids: ["a", "b", "c"])

    manager.noteVisible(ids: ["b", "c"], distanceFromBottom: Self.distanceOutsideTolerance)
    #expect(!manager.isPinnedToBottom)

    manager.noteVisible(ids: ["b", "c"], distanceFromBottom: Self.distanceInsideTolerance)
    #expect(manager.isPinnedToBottom)
  }

  @Test func theToleranceIncludesItsOwnValue() {
    let recorder = ReportRecorder<ScrollAnchorTarget>()
    let manager = Self.makeManager(recorder: recorder)
    manager.noteAppended(ids: ["a"])

    manager.noteVisible(ids: ["a"], distanceFromBottom: Self.tolerance)

    #expect(manager.isPinnedToBottom)
  }

  @Test func theLastIdOutsideTheToleranceIsUnpinned() {
    let recorder = ReportRecorder<ScrollAnchorTarget>()
    let manager = Self.makeManager(recorder: recorder)
    manager.noteAppended(ids: ["a", "b"])

    manager.noteVisible(ids: ["a", "b"], distanceFromBottom: Self.distanceOutsideTolerance)

    #expect(!manager.isPinnedToBottom)
  }

  @Test func aViewWithoutTheLastIdIsUnpinned() {
    let recorder = ReportRecorder<ScrollAnchorTarget>()
    let manager = Self.makeManager(recorder: recorder)
    manager.noteAppended(ids: ["a", "b", "c"])

    manager.noteVisible(ids: ["a", "b"])

    #expect(!manager.isPinnedToBottom)
  }

  @Test func anEmptyListIsPinned() {
    let manager = ScrollAnchorManager()

    manager.noteVisible(ids: [], distanceFromBottom: Self.distanceOutsideTolerance)

    #expect(manager.isPinnedToBottom)
  }

  /// A list whose bars are taller than its viewport can report no row. Then
  /// the report must not unpin the list: the scroll-to-bottom pill would
  /// change the height of the bars, and the layout would loop (^4yw9781).
  @Test func anEmptyReportOfAListWithItemsKeepsThePin() {
    let manager = ScrollAnchorManager()
    manager.noteAppended(ids: ["a", "b"])

    manager.noteVisible(ids: [], distanceFromBottom: Self.distanceOutsideTolerance)

    #expect(manager.isPinnedToBottom)
  }

  @Test func anEmptyReportOfAListWithItemsKeepsTheVisibleIds() {
    let manager = ScrollAnchorManager()
    manager.noteAppended(ids: ["a", "b"])
    manager.noteVisible(ids: ["a", "b"])

    manager.noteVisible(ids: [])

    #expect(manager.visibleIDs == ["a", "b"])
  }

  @Test func visibleIdsEqualTheIdsInOrder() {
    let manager = ScrollAnchorManager()
    manager.noteAppended(ids: ["a", "b", "c"])

    manager.noteVisible(ids: ["c", "a", "b"])

    #expect(manager.visibleIDs == ["c", "a", "b"])
  }

  /// The visibility reports of a list whose thread grows from one row to
  /// two rows, and then scrolls so that it shows only the second row, in
  /// the order that the list sends them. Each report holds the row keys in
  /// transcript order, as `ConversationView` gives them.
  private static let growingListReports = [["u"], ["u", "m"], ["m"]]

  @Test func eachVisibilityReportSetsTheVisibleIdsToItsIds() {
    let manager = ScrollAnchorManager()
    manager.noteAppended(ids: ["u", "m"])

    for report in Self.growingListReports {
      manager.noteVisible(ids: report)

      #expect(manager.visibleIDs == report)
    }
  }

  // MARK: - New item count

  @Test func eachIdAppendedWhileUnpinnedIncrementsTheCount() {
    let recorder = ReportRecorder<ScrollAnchorTarget>()
    let manager = Self.makeManager(recorder: recorder)
    manager.noteAppended(ids: ["a", "b"])
    manager.noteVisible(ids: ["a"])

    manager.noteAppended(ids: ["c"])
    #expect(manager.newItemsSinceUnpinned == 1)

    manager.noteAppended(ids: ["d", "e"])
    #expect(manager.newItemsSinceUnpinned == 3)
  }

  @Test func pinningResetsTheCountToZero() {
    let recorder = ReportRecorder<ScrollAnchorTarget>()
    let manager = Self.makeManager(recorder: recorder)
    manager.noteAppended(ids: ["a", "b"])
    manager.noteVisible(ids: ["a"])
    manager.noteAppended(ids: ["c", "d"])
    #expect(manager.newItemsSinceUnpinned == 2)

    manager.noteVisible(ids: ["c", "d"])

    #expect(manager.isPinnedToBottom)
    #expect(manager.newItemsSinceUnpinned == 0)
  }

  @Test func pinToBottomPinsClearsTheCountAndScrolls() async {
    let recorder = ReportRecorder<ScrollAnchorTarget>()
    let manager = Self.makeManager(recorder: recorder)
    manager.noteAppended(ids: ["a", "b"])
    manager.noteVisible(ids: ["a"])
    await Self.runScheduledTasks()
    manager.noteAppended(ids: ["c"])
    manager.saveAnchor()
    #expect(!manager.isPinnedToBottom)
    #expect(manager.newItemsSinceUnpinned == 1)

    manager.pinToBottom()
    await Self.runScheduledTasks()

    #expect(manager.isPinnedToBottom)
    #expect(manager.newItemsSinceUnpinned == 0)
    #expect(manager.anchorID == nil)
    #expect(recorder.values == [.bottom, .bottom])
  }

  // MARK: - Pin after a press on the pill

  /// Makes a manager whose list shows the first two of four items, and
  /// presses the pill: the manager calls ``ScrollAnchorManager/pinToBottom()``.
  ///
  /// - Parameter recorder: The recorder that gets the scroll targets.
  /// - Returns: The manager, after the press and before the next report.
  private static func makePressedManager(recorder: ReportRecorder<ScrollAnchorTarget>) -> ScrollAnchorManager {
    let manager = makeManager(recorder: recorder)
    manager.noteAppended(ids: ["a", "b", "c", "d"])
    manager.noteVisible(ids: ["a", "b"], distanceFromBottom: distanceOutsideTolerance)
    manager.pinToBottom()
    return manager
  }

  @Test func aReportOfTheOldRowsAfterAPressOnThePillKeepsThePin() {
    let manager = Self.makePressedManager(recorder: ReportRecorder())

    // The press removes the pill, and the geometry change of the list sends
    // the old rows again, before the list moves to the bottom.
    manager.noteVisible(ids: ["a", "b"], distanceFromBottom: Self.distanceOutsideTolerance)

    #expect(manager.isPinnedToBottom)
    #expect(manager.visibleIDs == ["a", "b"])
  }

  @Test func anAppendBeforeTheReportOfTheBottomRowsScrollsAndDoesNotCount() async {
    let recorder = ReportRecorder<ScrollAnchorTarget>()
    let manager = Self.makePressedManager(recorder: recorder)
    manager.noteVisible(ids: ["a", "b"], distanceFromBottom: Self.distanceOutsideTolerance)
    await Self.runScheduledTasks()

    manager.noteAppended(ids: ["e"])
    await Self.runScheduledTasks()

    #expect(manager.newItemsSinceUnpinned == 0)
    // The scroll of the first append and of the press is one scroll, and the
    // new append sends one more.
    #expect(recorder.values == [.bottom, .bottom])
  }

  @Test func theReportOfTheBottomRowsEndsTheWaitAfterAPressOnThePill() {
    let manager = Self.makePressedManager(recorder: ReportRecorder())
    manager.noteVisible(ids: ["c", "d"], distanceFromBottom: Self.distanceInsideTolerance)

    // The user scrolls up.
    manager.noteVisible(ids: ["a", "b"], distanceFromBottom: Self.distanceOutsideTolerance)

    #expect(!manager.isPinnedToBottom)
  }

  @Test func theLastRowOutsideTheToleranceDoesNotEndTheWaitAfterAPressOnThePill() {
    let manager = Self.makePressedManager(recorder: ReportRecorder())

    manager.noteVisible(ids: ["c", "d"], distanceFromBottom: Self.distanceOutsideTolerance)

    #expect(manager.isPinnedToBottom)
  }

  @Test func aJumpEndsTheWaitAfterAPressOnThePill() {
    let manager = Self.makePressedManager(recorder: ReportRecorder())

    manager.noteJump(to: "a")
    manager.noteVisible(ids: ["a", "b"], distanceFromBottom: Self.distanceOutsideTolerance)

    #expect(!manager.isPinnedToBottom)
  }

  @Test func pinToBottomWhilePinnedDoesNotKeepThePin() {
    let manager = Self.makeManager(recorder: ReportRecorder())
    manager.noteAppended(ids: ["a", "b", "c", "d"])
    manager.noteVisible(ids: ["c", "d"])

    manager.pinToBottom()
    manager.noteVisible(ids: ["a", "b"], distanceFromBottom: Self.distanceOutsideTolerance)

    #expect(!manager.isPinnedToBottom)
  }

  @Test func aNewLastItemWhileUnpinnedDoesNotCount() async {
    let recorder = ReportRecorder<ScrollAnchorTarget>()
    let manager = Self.makeManager(recorder: recorder)
    manager.noteAppended(ids: ["a", "b", "c"])
    manager.noteVisible(ids: ["a"])
    await Self.runScheduledTasks()

    manager.noteLastItemChanged(to: "b")
    await Self.runScheduledTasks()

    #expect(!manager.isPinnedToBottom)
    #expect(manager.newItemsSinceUnpinned == 0)
    #expect(recorder.values == [.bottom])

    manager.noteVisible(ids: ["a", "b"])
    #expect(manager.isPinnedToBottom)
  }

  @Test func aNewLastItemWhilePinnedScrolls() async {
    let recorder = ReportRecorder<ScrollAnchorTarget>()
    let manager = Self.makeManager(recorder: recorder)

    manager.noteLastItemChanged(to: "a")
    await Self.runScheduledTasks()

    #expect(manager.isPinnedToBottom)
    #expect(recorder.values == [.bottom])
  }

  @Test func noLastItemPinsAndDoesNotScroll() async {
    let recorder = ReportRecorder<ScrollAnchorTarget>()
    let manager = Self.makeManager(recorder: recorder)
    manager.noteAppended(ids: ["a", "b"])
    manager.noteVisible(ids: ["a"])
    await Self.runScheduledTasks()

    manager.noteLastItemChanged(to: nil)
    await Self.runScheduledTasks()

    #expect(manager.isPinnedToBottom)
    #expect(recorder.values == [.bottom])
  }

  @Test func anAppendWhilePinnedDoesNotCount() async {
    let recorder = ReportRecorder<ScrollAnchorTarget>()
    let manager = Self.makeManager(recorder: recorder)

    manager.noteAppended(ids: ["a", "b"])
    await Self.runScheduledTasks()

    #expect(manager.newItemsSinceUnpinned == 0)
    #expect(recorder.values == [.bottom])
  }

  @Test func anEmptyAppendChangesNothing() async {
    let recorder = ReportRecorder<ScrollAnchorTarget>()
    let manager = Self.makeManager(recorder: recorder)
    manager.noteAppended(ids: ["a"])
    manager.noteVisible(ids: ["a"], distanceFromBottom: Self.distanceOutsideTolerance)
    await Self.runScheduledTasks()

    manager.noteAppended(ids: [])
    await Self.runScheduledTasks()

    #expect(!manager.isPinnedToBottom)
    #expect(manager.newItemsSinceUnpinned == 0)
    #expect(recorder.values == [.bottom])
  }

  // MARK: - Coalesce

  @Test func tenRequestsInOneTickScrollOneTime() async {
    let recorder = ReportRecorder<ScrollAnchorTarget>()
    let manager = Self.makeManager(recorder: recorder)

    for _ in 0..<10 {
      manager.requestScrollToBottom()
    }
    #expect(recorder.values.isEmpty)
    await Self.runScheduledTasks()

    #expect(recorder.values == [.bottom])
  }

  @Test func aRequestAfterTheTickScrollsAgain() async {
    let recorder = ReportRecorder<ScrollAnchorTarget>()
    let manager = Self.makeManager(recorder: recorder)

    manager.requestScrollToBottom()
    await Self.runScheduledTasks()
    manager.requestScrollToBottom()
    await Self.runScheduledTasks()

    #expect(recorder.values == [.bottom, .bottom])
  }

  // MARK: - Anchor

  @Test func theAnchorIsSavedAndRestoredWhileUnpinned() {
    let recorder = ReportRecorder<ScrollAnchorTarget>()
    let manager = Self.makeManager(recorder: recorder)
    manager.noteAppended(ids: ["a", "b", "c", "d"])
    manager.noteVisible(ids: ["b", "c"])

    manager.saveAnchor()
    #expect(manager.anchorID == "b")

    manager.restoreAnchor()
    #expect(recorder.values == [.item("b")])
    #expect(manager.anchorID == nil)
  }

  @Test func restoreWhilePinnedClearsTheAnchorAndDoesNotScrollToIt() {
    let recorder = ReportRecorder<ScrollAnchorTarget>()
    let manager = Self.makeManager(recorder: recorder)
    manager.noteAppended(ids: ["a", "b"])
    manager.noteVisible(ids: ["a", "b"])

    manager.saveAnchor()
    #expect(manager.anchorID == "a")
    manager.restoreAnchor()

    #expect(manager.anchorID == nil)
    #expect(!recorder.values.contains(.item("a")))
  }

  @Test func restoreWithNoAnchorDoesNothing() {
    let recorder = ReportRecorder<ScrollAnchorTarget>()
    let manager = Self.makeManager(recorder: recorder)
    manager.noteAppended(ids: ["a", "b"])
    manager.noteVisible(ids: ["a"])

    manager.restoreAnchor()

    #expect(recorder.values.isEmpty)
    #expect(manager.anchorID == nil)
  }

  @Test func saveWithNoVisibleIdKeepsNoAnchor() {
    let manager = ScrollAnchorManager()

    manager.saveAnchor()

    #expect(manager.anchorID == nil)
  }

  @Test func aJumpKeepsTheItemAsTheAnchorAndSendsNoScroll() {
    let recorder = ReportRecorder<ScrollAnchorTarget>()
    let manager = Self.makeManager(recorder: recorder)
    manager.noteAppended(ids: ["a", "b", "c", "d"])
    manager.noteVisible(ids: ["a", "b"])

    manager.noteJump(to: "c")

    #expect(manager.anchorID == "c")
    #expect(recorder.values.isEmpty)
  }

  @Test func aJumpCancelsTheRequestedScrollToTheBottom() async {
    let recorder = ReportRecorder<ScrollAnchorTarget>()
    let manager = Self.makeManager(recorder: recorder)
    manager.noteLastItemChanged(to: "d")

    manager.noteJump(to: "a")
    await Self.runScheduledTasks()

    #expect(manager.anchorID == "a")
    #expect(recorder.values.isEmpty)
  }

  @Test func aReturnToTheBottomClearsTheJumpAnchor() {
    let manager = ScrollAnchorManager()
    manager.noteAppended(ids: ["a", "b", "c", "d"])
    manager.noteVisible(ids: ["a", "b"])
    manager.noteJump(to: "b")

    manager.noteVisible(ids: ["c", "d"])

    #expect(manager.isPinnedToBottom)
    #expect(manager.anchorID == nil)
  }

  // MARK: - Jump report

  /// Makes a manager whose list shows the last two of five items, and jumps
  /// it to the item "c".
  ///
  /// - Parameter recorder: The recorder that gets the scroll targets.
  /// - Returns: The manager, after the jump and before the next report.
  private static func makeJumpedManager(recorder: ReportRecorder<ScrollAnchorTarget>) -> ScrollAnchorManager {
    let manager = makeManager(recorder: recorder)
    manager.noteAppended(ids: ["a", "b", "c", "d", "e"])
    manager.noteVisible(ids: ["d", "e"])
    manager.noteJump(to: "c")
    return manager
  }

  @Test func aJumpSetsTheVisibleIdsToTheItem() {
    let manager = Self.makeJumpedManager(recorder: ReportRecorder())

    #expect(manager.visibleIDs == ["c"])
  }

  @Test func aSaveAfterAJumpAndAReportWithoutTheItemKeepsTheItem() {
    let recorder = ReportRecorder<ScrollAnchorTarget>()
    let manager = Self.makeJumpedManager(recorder: recorder)

    // A layout pass before the list placed the item reports other rows.
    manager.noteVisible(ids: ["a", "b"], distanceFromBottom: Self.distanceOutsideTolerance)
    manager.saveAnchor()
    manager.restoreAnchor()

    #expect(manager.visibleIDs == ["c"])
    #expect(!manager.isPinnedToBottom)
    #expect(recorder.values == [.item("c")])
  }

  @Test func aReportEqualToTheVisibleIdsDoesNotEndTheWaitForTheJumpReport() {
    let manager = Self.makeJumpedManager(recorder: ReportRecorder())

    // The scroll geometry callback reports the same identifiers again.
    manager.noteVisible(ids: ["c"], distanceFromBottom: Self.distanceOutsideTolerance)
    manager.noteVisible(ids: ["a", "b"], distanceFromBottom: Self.distanceOutsideTolerance)

    #expect(manager.visibleIDs == ["c"])
  }

  @Test func aJumpReportWithTheItemReplacesTheVisibleIds() {
    let manager = Self.makeJumpedManager(recorder: ReportRecorder())

    manager.noteVisible(ids: ["b", "c"], distanceFromBottom: Self.distanceOutsideTolerance)

    #expect(manager.visibleIDs == ["b", "c"])
  }

  @Test func theReportAfterAReportWithoutTheItemReplacesTheVisibleIds() {
    let manager = Self.makeJumpedManager(recorder: ReportRecorder())
    manager.noteVisible(ids: ["a", "b"], distanceFromBottom: Self.distanceOutsideTolerance)

    // The user scrolls.
    manager.noteVisible(ids: ["b"], distanceFromBottom: Self.distanceOutsideTolerance)

    #expect(manager.visibleIDs == ["b"])
  }
}
