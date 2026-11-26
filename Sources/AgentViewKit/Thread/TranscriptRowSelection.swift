import EditorSwiftUI
import Observation

/// The text selection region of one row of a thread (card ^9ync5h3).
///
/// The region stands between the text areas of the row and the selection
/// region of the thread (``ThreadTextSelection``). It forwards each claim
/// and each release to the thread, and records whether a text area of the
/// row holds the selection. The row holds its real form while a text area
/// of it holds the selection (``TranscriptRowHolds/hasSelection``), so a
/// move of the list keeps the selection and a copy still copies it.
///
/// ``holdsSelection`` is observable, so a claim and a release evaluate the
/// row again.
@MainActor @Observable
final class TranscriptRowSelection: TextSelectionRegion {
  /// Whether a text area of the row holds the selection of the thread.
  private(set) var holdsSelection = false

  /// The identity of the text area of the row that holds the selection, or
  /// `nil`. The region keeps no reference to the area: the thread clears
  /// the hold also after the area goes away.
  @ObservationIgnored private var owner: ObjectIdentifier?

  /// The selection region of the thread, or `nil` when the row has no
  /// region in its environment.
  @ObservationIgnored private var thread: (any TextSelectionRegion)?

  /// Makes a region that forwards to no region.
  init() {}

  /// Sets the region of the thread, and returns the region that the text
  /// areas of the row take part in.
  ///
  /// The row calls this function each time that its body evaluates, with
  /// the region of its environment. The region keeps its identity, so a
  /// text area does not release its region at each evaluation.
  ///
  /// - Parameter region: The selection region of the thread, or `nil`.
  /// - Returns: This region, or `nil` when `region` is `nil`: with no
  ///   region, each text area keeps a selection of its own.
  func forwarding(to region: (any TextSelectionRegion)?) -> TranscriptRowSelection? {
    thread = region
    return region == nil ? nil : self
  }

  /// Gives the selection of the thread to `owner`, a text area of the row.
  ///
  /// - Parameters:
  ///   - owner: The text area that now holds the selection.
  ///   - clear: Clears the selection of `owner`. The thread calls it when a
  ///     different area claims the selection, and the row then ends its
  ///     hold of that area.
  func claim(_ owner: AnyObject, clear: @escaping @MainActor () -> Void) {
    let id = ObjectIdentifier(owner)
    self.owner = id
    setHoldsSelection(true)
    thread?.claim(owner) { [weak self] in
      self?.didClear(id)
      clear()
    }
  }

  /// Tells the thread that `owner` goes away, and ends the hold when
  /// `owner` holds the selection.
  ///
  /// - Parameter owner: The text area that goes away.
  func release(_ owner: AnyObject) {
    didClear(ObjectIdentifier(owner))
    thread?.release(owner)
  }

  /// Ends the hold when `cleared` is the text area that holds the
  /// selection.
  ///
  /// - Parameter cleared: The identity of the text area whose selection
  ///   ends.
  private func didClear(_ cleared: ObjectIdentifier) {
    guard owner == cleared else { return }
    owner = nil
    setHoldsSelection(false)
  }

  /// Sets ``holdsSelection``, and writes the observable value only when it
  /// changes, so a claim again by the same area evaluates no row.
  ///
  /// - Parameter value: The new value.
  private func setHoldsSelection(_ value: Bool) {
    guard holdsSelection != value else { return }
    holdsSelection = value
  }
}
