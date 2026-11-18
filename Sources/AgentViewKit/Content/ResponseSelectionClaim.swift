import EditorSwiftUI

/// The text selection region of the editor of one ``ResponseView``.
///
/// The claim stands between the editor of the response and the selection
/// region of the thread (``ThreadTextSelection``). It forwards each claim
/// and each release of the editor to the thread, and records whether the
/// editor holds the selection. A response whose editor holds the selection
/// keeps its editor when its row scrolls far away, so the selection stays
/// and a copy still copies it (task ^t9416x5).
///
/// The claim is not observable. The response reads it when its body
/// evaluates.
@MainActor
final class ResponseSelectionClaim: TextSelectionRegion {
  /// Whether the editor of the response holds the selection of the thread.
  private(set) var holdsSelection = false

  /// The selection region of the thread, or `nil` when the response has no
  /// region in its environment.
  private var thread: (any TextSelectionRegion)?

  /// Makes a claim that forwards to no region.
  init() {}

  /// Sets the region of the thread, and returns the region that the editor
  /// of the response takes part in.
  ///
  /// The response calls this function each time its body evaluates, with the
  /// region of its environment. The claim keeps its identity, so the editor
  /// does not release its region at each evaluation.
  ///
  /// - Parameter region: The selection region of the thread, or `nil` when
  ///   the environment has none.
  /// - Returns: This claim, or `nil` when `region` is `nil`: with no region,
  ///   the editor keeps a selection of its own.
  func forwarding(to region: (any TextSelectionRegion)?) -> ResponseSelectionClaim? {
    thread = region
    return region == nil ? nil : self
  }

  /// Gives the selection of the thread to the editor of the response.
  ///
  /// - Parameters:
  ///   - owner: The editor of the response.
  ///   - clear: Clears the selection of the editor. The thread calls it when
  ///     a different area claims the selection, and the claim then ends its
  ///     hold.
  func claim(_ owner: AnyObject, clear: @escaping @MainActor () -> Void) {
    holdsSelection = true
    thread?.claim(owner) { [weak self] in
      self?.holdsSelection = false
      clear()
    }
  }

  /// Ends the hold, and tells the thread that the editor of the response
  /// goes away.
  ///
  /// - Parameter owner: The editor of the response.
  func release(_ owner: AnyObject) {
    holdsSelection = false
    thread?.release(owner)
  }
}
