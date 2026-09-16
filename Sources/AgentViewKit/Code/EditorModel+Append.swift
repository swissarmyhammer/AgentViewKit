import EditorCore
import EditorSwiftUI

extension EditorModel {
  /// Adds `text` at the end of the document, as a streaming response does
  /// (plan.md §4.1, §8).
  ///
  /// EditorKit has no append operation. This helper makes a transaction that
  /// replaces the empty range at the end of the document with `text`, and
  /// dispatches it. The edit does not go into the undo history.
  ///
  /// A read-only model rejects a document change. The helper sets
  /// ``EditorModel/isReadOnly`` to `false` for the dispatch, and then sets
  /// the prior value again.
  ///
  /// - Parameter text: The text to add.
  /// - Returns: The outcome of the dispatch. For an empty `text`, the helper
  ///   does not dispatch and returns the current state as applied.
  @discardableResult
  public func appendStreaming(_ text: String) -> DispatchOutcome {
    guard !text.isEmpty else { return .applied(state) }
    // The rope keeps its UTF-8 length, so this read does not copy the text.
    let end = state.document.utf8Count
    return dispatchIgnoringReadOnly(
      ChangeSet(fromLength: end, replacements: [(end..<end, text)]))
  }

  /// Changes the document to `text` with the smallest streaming edit.
  ///
  /// When the document is a prefix of `text`, the helper adds only the new
  /// suffix with ``appendStreaming(_:)``. When the document is not a prefix,
  /// the helper replaces the full document. When the document is equal to
  /// `text`, the helper does nothing.
  ///
  /// - Parameter text: The full text that the document must have.
  public func syncStreaming(to text: String) {
    // The comparison uses the UTF-8 bytes, because the document ranges are
    // UTF-8 byte ranges. A comparison of characters can join the last
    // character of the document with the first new scalar.
    let current = self.text.utf8
    let target = text.utf8
    guard !current.elementsEqual(target) else { return }
    if target.starts(with: current) {
      appendStreaming(String(decoding: target.dropFirst(current.count), as: UTF8.self))
    } else {
      dispatchIgnoringReadOnly(
        ChangeSet(fromLength: current.count, replacements: [(0..<current.count, text)]))
    }
  }

  /// Dispatches `changes` with no undo history, also on a read-only model.
  ///
  /// - Parameter changes: The document change to dispatch.
  /// - Returns: The outcome of the dispatch.
  @discardableResult
  private func dispatchIgnoringReadOnly(_ changes: ChangeSet) -> DispatchOutcome {
    var annotations = TransactionAnnotations()
    annotations.addToHistory = .disabled
    let wasReadOnly = isReadOnly
    isReadOnly = false
    defer { isReadOnly = wasReadOnly }
    return dispatch(Transaction(changes: changes, annotations: annotations))
  }
}
