/// Keeps the last ``ParagraphView`` of each paragraph of one response, so that
/// a settled paragraph gives SwiftUI the same stored value on each update.
///
/// SwiftUI computes the compare layout of a view type on a background queue.
/// Until that layout is ready, SwiftUI compares the bytes of the old and the
/// new view value, and it does not call `==`. Each update of a response splits
/// its text again, so each new ``ParagraphView`` holds new text storage, and
/// its bytes differ from the old value. Then each settled paragraph evaluates
/// its body again, although `==` gives `true`. This occurs early in a process,
/// and when the process is busy, for as long as the layout is not ready.
///
/// The cache gives back the stored view of a paragraph when the new view is
/// equal to it. The old and the new value then have the same bytes, so
/// SwiftUI finds no change with the layout or without it.
///
/// The cache is a class, because the list changes it while SwiftUI evaluates
/// the body of the list. A change of a value in `@State` would start a new
/// update. The cache is not observable, so a change starts no update.
@MainActor final class ParagraphViewCache {
  /// The view that the cache gave last for each paragraph, keyed by the
  /// paragraph id.
  private var views: [ParagraphSplitter.Paragraph.ID: ParagraphView] = [:]

  /// Gives the stored view of each paragraph that did not change, and the
  /// new view of each other paragraph. Then the cache keeps the views that it
  /// gives, and forgets the paragraphs that are not in `views`.
  ///
  /// - Parameter views: The new views, in message order.
  /// - Returns: The views to show, in message order.
  func reuse(_ views: [ParagraphView]) -> [ParagraphView] {
    let result = views.map(storedView(for:))
    self.views = Dictionary(result.map { ($0.paragraph.id, $0) }) { first, _ in first }
    return result
  }

  /// The stored view of a paragraph when it is equal to `view`, else `view`.
  ///
  /// - Parameter view: The new view of a paragraph.
  /// - Returns: The view to show.
  private func storedView(for view: ParagraphView) -> ParagraphView {
    guard let stored = views[view.paragraph.id], stored == view else { return view }
    return stored
  }
}
