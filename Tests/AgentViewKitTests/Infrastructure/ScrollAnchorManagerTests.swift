import AgentViewKit
import CoreGraphics
import Testing

@Suite @MainActor struct ScrollAnchorManagerTests {
  /// Records each scroll target that the manager sends.
  private final class ScrollRecorder {
    private(set) var targets: [ScrollAnchorTarget] = []

    func record(_ target: ScrollAnchorTarget) {
      targets.append(target)
    }
  }

  /// A distance from the bottom that is in the tolerance of the manager.
  private static let distanceInsideTolerance: CGFloat = 10

  /// A distance from the bottom that is not in the tolerance of the manager.
  private static let distanceOutsideTolerance: CGFloat = 40

  /// The tolerance of each manager in these tests.
  private static let tolerance: CGFloat = 24

  /// Makes a manager that sends its scroll targets to `recorder`.
  private static func makeManager(recorder: ScrollRecorder) -> ScrollAnchorManager {
    ScrollAnchorManager(tolerance: tolerance) { recorder.record($0) }
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
    let recorder = ScrollRecorder()
    let manager = Self.makeManager(recorder: recorder)
    manager.noteAppended(ids: ["a", "b", "c"])

    manager.noteVisible(ids: ["b", "c"], distanceFromBottom: Self.distanceOutsideTolerance)
    #expect(!manager.isPinnedToBottom)

    manager.noteVisible(ids: ["b", "c"], distanceFromBottom: Self.distanceInsideTolerance)
    #expect(manager.isPinnedToBottom)
  }

  @Test func theToleranceIncludesItsOwnValue() {
    let recorder = ScrollRecorder()
    let manager = Self.makeManager(recorder: recorder)
    manager.noteAppended(ids: ["a"])

    manager.noteVisible(ids: ["a"], distanceFromBottom: Self.tolerance)

    #expect(manager.isPinnedToBottom)
  }

  @Test func theLastIdOutsideTheToleranceIsUnpinned() {
    let recorder = ScrollRecorder()
    let manager = Self.makeManager(recorder: recorder)
    manager.noteAppended(ids: ["a", "b"])

    manager.noteVisible(ids: ["a", "b"], distanceFromBottom: Self.distanceOutsideTolerance)

    #expect(!manager.isPinnedToBottom)
  }

  @Test func aViewWithoutTheLastIdIsUnpinned() {
    let recorder = ScrollRecorder()
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

  @Test func visibleIdsEqualTheIdsInOrder() {
    let manager = ScrollAnchorManager()
    manager.noteAppended(ids: ["a", "b", "c"])

    manager.noteVisible(ids: ["c", "a", "b"])

    #expect(manager.visibleIDs == ["c", "a", "b"])
  }

  // MARK: - New item count

  @Test func eachIdAppendedWhileUnpinnedIncrementsTheCount() {
    let recorder = ScrollRecorder()
    let manager = Self.makeManager(recorder: recorder)
    manager.noteAppended(ids: ["a", "b"])
    manager.noteVisible(ids: ["a"])

    manager.noteAppended(ids: ["c"])
    #expect(manager.newItemsSinceUnpinned == 1)

    manager.noteAppended(ids: ["d", "e"])
    #expect(manager.newItemsSinceUnpinned == 3)
  }

  @Test func pinningResetsTheCountToZero() {
    let recorder = ScrollRecorder()
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
    let recorder = ScrollRecorder()
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
    #expect(recorder.targets == [.bottom, .bottom])
  }

  @Test func aNewLastItemWhileUnpinnedDoesNotCount() async {
    let recorder = ScrollRecorder()
    let manager = Self.makeManager(recorder: recorder)
    manager.noteAppended(ids: ["a", "b", "c"])
    manager.noteVisible(ids: ["a"])
    await Self.runScheduledTasks()

    manager.noteLastItemChanged(to: "b")
    await Self.runScheduledTasks()

    #expect(!manager.isPinnedToBottom)
    #expect(manager.newItemsSinceUnpinned == 0)
    #expect(recorder.targets == [.bottom])

    manager.noteVisible(ids: ["a", "b"])
    #expect(manager.isPinnedToBottom)
  }

  @Test func aNewLastItemWhilePinnedScrolls() async {
    let recorder = ScrollRecorder()
    let manager = Self.makeManager(recorder: recorder)

    manager.noteLastItemChanged(to: "a")
    await Self.runScheduledTasks()

    #expect(manager.isPinnedToBottom)
    #expect(recorder.targets == [.bottom])
  }

  @Test func noLastItemPinsAndDoesNotScroll() async {
    let recorder = ScrollRecorder()
    let manager = Self.makeManager(recorder: recorder)
    manager.noteAppended(ids: ["a", "b"])
    manager.noteVisible(ids: ["a"])
    await Self.runScheduledTasks()

    manager.noteLastItemChanged(to: nil)
    await Self.runScheduledTasks()

    #expect(manager.isPinnedToBottom)
    #expect(recorder.targets == [.bottom])
  }

  @Test func anAppendWhilePinnedDoesNotCount() async {
    let recorder = ScrollRecorder()
    let manager = Self.makeManager(recorder: recorder)

    manager.noteAppended(ids: ["a", "b"])
    await Self.runScheduledTasks()

    #expect(manager.newItemsSinceUnpinned == 0)
    #expect(recorder.targets == [.bottom])
  }

  @Test func anEmptyAppendChangesNothing() async {
    let recorder = ScrollRecorder()
    let manager = Self.makeManager(recorder: recorder)
    manager.noteAppended(ids: ["a"])
    manager.noteVisible(ids: [])
    await Self.runScheduledTasks()

    manager.noteAppended(ids: [])
    await Self.runScheduledTasks()

    #expect(!manager.isPinnedToBottom)
    #expect(manager.newItemsSinceUnpinned == 0)
    #expect(recorder.targets == [.bottom])
  }

  // MARK: - Coalesce

  @Test func tenRequestsInOneTickScrollOneTime() async {
    let recorder = ScrollRecorder()
    let manager = Self.makeManager(recorder: recorder)

    for _ in 0..<10 {
      manager.requestScrollToBottom()
    }
    #expect(recorder.targets.isEmpty)
    await Self.runScheduledTasks()

    #expect(recorder.targets == [.bottom])
  }

  @Test func aRequestAfterTheTickScrollsAgain() async {
    let recorder = ScrollRecorder()
    let manager = Self.makeManager(recorder: recorder)

    manager.requestScrollToBottom()
    await Self.runScheduledTasks()
    manager.requestScrollToBottom()
    await Self.runScheduledTasks()

    #expect(recorder.targets == [.bottom, .bottom])
  }

  // MARK: - Anchor

  @Test func theAnchorIsSavedAndRestoredWhileUnpinned() {
    let recorder = ScrollRecorder()
    let manager = Self.makeManager(recorder: recorder)
    manager.noteAppended(ids: ["a", "b", "c", "d"])
    manager.noteVisible(ids: ["b", "c"])

    manager.saveAnchor()
    #expect(manager.anchorID == "b")

    manager.restoreAnchor()
    #expect(recorder.targets == [.item("b")])
    #expect(manager.anchorID == nil)
  }

  @Test func restoreWhilePinnedClearsTheAnchorAndDoesNotScrollToIt() {
    let recorder = ScrollRecorder()
    let manager = Self.makeManager(recorder: recorder)
    manager.noteAppended(ids: ["a", "b"])
    manager.noteVisible(ids: ["a", "b"])

    manager.saveAnchor()
    #expect(manager.anchorID == "a")
    manager.restoreAnchor()

    #expect(manager.anchorID == nil)
    #expect(!recorder.targets.contains(.item("a")))
  }

  @Test func restoreWithNoAnchorDoesNothing() {
    let recorder = ScrollRecorder()
    let manager = Self.makeManager(recorder: recorder)
    manager.noteAppended(ids: ["a", "b"])
    manager.noteVisible(ids: ["a"])

    manager.restoreAnchor()

    #expect(recorder.targets.isEmpty)
    #expect(manager.anchorID == nil)
  }

  @Test func saveWithNoVisibleIdKeepsNoAnchor() {
    let manager = ScrollAnchorManager()

    manager.saveAnchor()

    #expect(manager.anchorID == nil)
  }

  @Test func aJumpKeepsTheItemAsTheAnchorAndSendsNoScroll() {
    let recorder = ScrollRecorder()
    let manager = Self.makeManager(recorder: recorder)
    manager.noteAppended(ids: ["a", "b", "c", "d"])
    manager.noteVisible(ids: ["a", "b"])

    manager.noteJump(to: "c")

    #expect(manager.anchorID == "c")
    #expect(recorder.targets.isEmpty)
  }
}
