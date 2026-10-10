import CoreGraphics
import Observation

/// A position that ``ScrollAnchorManager`` asks the thread list to scroll to.
public enum ScrollAnchorTarget: Equatable, Sendable {
  /// The end of the list.
  case bottom

  /// The item with this identifier.
  case item(String)
}

/// Keeps the scroll position of the thread list (plan.md §8).
///
/// The list feeds the manager from `onScrollTargetVisibilityChange` through
/// ``noteVisible(ids:distanceFromBottom:)``, and tells it about each new item
/// through ``noteAppended(ids:)``. The manager does not read absolute scroll
/// offsets.
///
/// - While the list shows its last item, the manager is pinned to the bottom,
///   and each append scrolls the list to the new end.
/// - While the user reads earlier items, the manager is unpinned, counts the
///   new items for the scroll-to-bottom pill, and does not move the list.
/// - ``requestScrollToBottom()`` sends at most one scroll for each main-actor
///   tick, so a stream of appends does not start a scroll for each chunk.
/// - ``saveAnchor()`` and ``restoreAnchor()`` keep the first visible item in
///   view across a list update.
///
/// The manager sends each scroll to its ``onScroll`` closure. The list applies
/// the target to its scroll position.
@MainActor
@Observable
public final class ScrollAnchorManager {
  /// The default tolerance, in points.
  public static let defaultTolerance: CGFloat = 24

  /// The largest distance, in points, from the bottom edge of the last item
  /// to the bottom edge of the viewport at which the list is at the bottom.
  public let tolerance: CGFloat

  /// `true` while the list shows its last item.
  ///
  /// A list with no item is pinned.
  public private(set) var isPinnedToBottom = true

  /// The identifier that ``saveAnchor()`` or ``noteJump(to:)`` kept, or
  /// `nil` when no anchor is kept.
  public private(set) var anchorID: String?

  /// The identifiers of the items in view, in the order that the list gave.
  ///
  /// After ``noteJump(to:)``, the value is the item of the jump, until the
  /// list reports a set of rows with that item. After a long jump, a lazy
  /// list can report the rows of a layout pass before it placed the item,
  /// and then not report again until the next scroll. The manager does not
  /// keep the rows of that first report. Thus ``saveAnchor()`` and the jump
  /// commands start from the item of the jump.
  public private(set) var visibleIDs: [String] = []

  /// The number of items appended since the list became unpinned.
  ///
  /// The scroll-to-bottom pill shows this count. The count is zero while the
  /// list is pinned.
  public private(set) var newItemsSinceUnpinned = 0

  /// The closure that gets each scroll target.
  @ObservationIgnored public var onScroll: (ScrollAnchorTarget) -> Void

  /// The identifier of the last item in the list, or `nil` for an empty list.
  @ObservationIgnored private var lastItemID: String?

  /// The item of the last jump, until the next report of new rows, or `nil`
  /// when the manager does not wait for the rows of a jump.
  @ObservationIgnored private var jumpItemID: String?

  /// The task that sends the requested scroll to the bottom, or `nil` when no
  /// scroll is requested.
  @ObservationIgnored private var pendingScroll: Task<Void, Never>?

  /// Makes a manager.
  ///
  /// - Parameters:
  ///   - tolerance: The largest distance, in points, from the bottom edge of
  ///     the last item to the bottom edge of the viewport at which the list is
  ///     at the bottom.
  ///   - onScroll: The closure that gets each scroll target.
  public init(
    tolerance: CGFloat = ScrollAnchorManager.defaultTolerance,
    onScroll: @escaping (ScrollAnchorTarget) -> Void = { _ in }
  ) {
    self.tolerance = tolerance
    self.onScroll = onScroll
  }

  /// Cancels the requested scroll.
  isolated deinit {
    pendingScroll?.cancel()
  }

  // MARK: - Visibility

  /// Records the items in view, and sets ``isPinnedToBottom``.
  ///
  /// The list is at the bottom when it has no item, or when the last visible
  /// identifier is the last item and `distanceFromBottom` is at most
  /// ``tolerance``. A change to pinned sets ``newItemsSinceUnpinned`` to zero
  /// and clears ``anchorID``.
  ///
  /// After ``noteJump(to:)``, the first report with identifiers that are not
  /// ``visibleIDs`` replaces ``visibleIDs`` only when it includes the item of
  /// the jump, or when it pins the list. A report without the item comes
  /// from a layout pass before the list placed the item. The report after it
  /// replaces ``visibleIDs`` again. A report equal to ``visibleIDs``, such as
  /// the report of a scroll geometry change, changes only the pin state.
  ///
  /// - Parameters:
  ///   - ids: The identifiers of the items in view, from
  ///     `onScrollTargetVisibilityChange`.
  ///   - distanceFromBottom: The distance, in points, from the bottom edge of
  ///     the last visible item to the bottom edge of the viewport.
  public func noteVisible(ids: [String], distanceFromBottom: CGFloat = 0) {
    let isAtBottom = isAtBottom(visibleIDs: ids, distanceFromBottom: distanceFromBottom)
    let isNewReport = ids != visibleIDs
    if acceptsReport(of: ids) || isAtBottom {
      visibleIDs = ids
    }
    if isNewReport {
      jumpItemID = nil
    }
    setPinned(isAtBottom)
  }

  /// Records items that the list appended.
  ///
  /// While pinned, the manager requests a scroll to the new end. While
  /// unpinned, it adds the count of `ids` to ``newItemsSinceUnpinned``.
  ///
  /// - Parameter ids: The identifiers of the new items, in list order. An
  ///   empty array does nothing.
  public func noteAppended(ids: [String]) {
    guard let last = ids.last else { return }
    lastItemID = last
    if isPinnedToBottom {
      requestScrollToBottom()
    } else {
      newItemsSinceUnpinned += ids.count
    }
  }

  /// Records a new last item that the list did not append, such as after a
  /// removal or a clear.
  ///
  /// The call does not add to ``newItemsSinceUnpinned``. While pinned, the
  /// manager requests a scroll to the new end. An empty list is pinned.
  ///
  /// - Parameter id: The identifier of the last item, or `nil` for an empty
  ///   list.
  public func noteLastItemChanged(to id: String?) {
    lastItemID = id
    guard id != nil else {
      setPinned(true)
      return
    }
    if isPinnedToBottom {
      requestScrollToBottom()
    }
  }

  // MARK: - Scroll

  /// Requests a scroll to the end of the list.
  ///
  /// The manager sends ``ScrollAnchorTarget/bottom`` one time on the next
  /// main-actor tick. The requests before that tick send nothing more.
  public func requestScrollToBottom() {
    guard pendingScroll == nil else { return }
    pendingScroll = Task { [weak self] in
      guard !Task.isCancelled else { return }
      self?.sendPendingScroll()
    }
  }

  /// Pins the list to the bottom and requests a scroll to the end, after the
  /// user taps the scroll-to-bottom pill.
  ///
  /// The call sets ``isPinnedToBottom`` to `true`, sets
  /// ``newItemsSinceUnpinned`` to zero, and clears the kept anchor. Then it
  /// calls ``requestScrollToBottom()``.
  public func pinToBottom() {
    anchorID = nil
    setPinned(true)
    requestScrollToBottom()
  }

  // MARK: - Anchor

  /// Keeps the first visible item as the anchor, before a list update.
  ///
  /// With no visible item, the manager keeps no anchor.
  public func saveAnchor() {
    anchorID = visibleIDs.first
  }

  /// Keeps `id` as the anchor, after the user picks an item to go to.
  ///
  /// The caller scrolls the list to the item. The manager sends no scroll.
  /// The call cancels a scroll to the bottom that ``requestScrollToBottom()``
  /// requested and did not send yet, so that this scroll does not move the
  /// list away from the item. A later ``restoreAnchor()`` keeps the item in
  /// view across a list update. The Show Error button of
  /// ``ConversationView``, the thread minimap and the jump commands call this
  /// function.
  ///
  /// The call also sets ``visibleIDs`` to the item, and the manager waits
  /// for the rows of the jump (see ``noteVisible(ids:distanceFromBottom:)``).
  /// Thus a ``saveAnchor()`` right after the jump, such as for a Load
  /// Earlier press, keeps the item as the anchor.
  ///
  /// - Parameter id: The identifier of the item that the user picked.
  public func noteJump(to id: String) {
    anchorID = id
    visibleIDs = [id]
    jumpItemID = id
    pendingScroll?.cancel()
    pendingScroll = nil
  }

  /// Scrolls back to the kept anchor, after a list update, and clears it.
  ///
  /// While pinned, the list follows the bottom, so the manager clears the
  /// anchor and sends no scroll to it.
  public func restoreAnchor() {
    guard let anchor = anchorID else { return }
    anchorID = nil
    guard !isPinnedToBottom else { return }
    onScroll(.item(anchor))
  }

  // MARK: - Private

  /// Tells if the list is at the bottom.
  ///
  /// - Parameters:
  ///   - visibleIDs: The identifiers of the items in view.
  ///   - distanceFromBottom: The distance, in points, from the bottom edge of
  ///     the last visible item to the bottom edge of the viewport.
  /// - Returns: `true` when the list has no item, or when it shows its last
  ///   item in the tolerance.
  private func isAtBottom(visibleIDs: [String], distanceFromBottom: CGFloat) -> Bool {
    guard let lastItemID else { return true }
    return visibleIDs.last == lastItemID && distanceFromBottom <= tolerance
  }

  /// Tells if a report of the rows in view replaces ``visibleIDs``.
  ///
  /// The function does not change state.
  /// ``noteVisible(ids:distanceFromBottom:)`` ends the wait for the rows of a
  /// jump at the first new report.
  ///
  /// - Parameter ids: The identifiers of the items in view.
  /// - Returns: `false` when `ids` is the first new report after a jump and
  ///   does not include the item of the jump, else `true`.
  private func acceptsReport(of ids: [String]) -> Bool {
    guard ids != visibleIDs, let jumpItemID else { return true }
    return ids.contains(jumpItemID)
  }

  /// Sets ``isPinnedToBottom``, and clears the new item count and the kept
  /// anchor on a change to pinned.
  ///
  /// A pinned list follows the bottom, so a kept anchor, such as the item of
  /// an earlier jump, has no use after the list is back at the bottom.
  ///
  /// - Parameter pinned: The new value.
  private func setPinned(_ pinned: Bool) {
    guard pinned != isPinnedToBottom else { return }
    isPinnedToBottom = pinned
    if pinned {
      newItemsSinceUnpinned = 0
      anchorID = nil
    }
  }

  /// Clears the requested scroll and sends it.
  private func sendPendingScroll() {
    pendingScroll = nil
    onScroll(.bottom)
  }
}
