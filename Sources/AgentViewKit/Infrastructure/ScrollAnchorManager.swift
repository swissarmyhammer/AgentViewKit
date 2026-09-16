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
  /// ``tolerance``. A change to pinned sets ``newItemsSinceUnpinned`` to zero.
  ///
  /// - Parameters:
  ///   - ids: The identifiers of the items in view, from
  ///     `onScrollTargetVisibilityChange`.
  ///   - distanceFromBottom: The distance, in points, from the bottom edge of
  ///     the last visible item to the bottom edge of the viewport.
  public func noteVisible(ids: [String], distanceFromBottom: CGFloat = 0) {
    visibleIDs = ids
    setPinned(isAtBottom(visibleIDs: ids, distanceFromBottom: distanceFromBottom))
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
  /// A later ``restoreAnchor()`` keeps the item in view across a list
  /// update. The thread minimap calls this function.
  ///
  /// - Parameter id: The identifier of the item that the user picked.
  public func noteJump(to id: String) {
    anchorID = id
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

  /// Sets ``isPinnedToBottom``, and clears the new item count on a change to
  /// pinned.
  ///
  /// - Parameter pinned: The new value.
  private func setPinned(_ pinned: Bool) {
    guard pinned != isPinnedToBottom else { return }
    isPinnedToBottom = pinned
    if pinned {
      newItemsSinceUnpinned = 0
    }
  }

  /// Clears the requested scroll and sends it.
  private func sendPendingScroll() {
    pendingScroll = nil
    onScroll(.bottom)
  }
}
