import EditorSwiftUI

/// The model that a read-only editor view keeps when the host gives no model.
///
/// ``CodeBlockView``, ``CommandOutputView``, and ``TerminalView`` keep a slot in a `@State`
/// value. The slot makes the model at the first read. A `@State` value that
/// holds the model directly would make a new model each time SwiftUI makes
/// the view value again.
final class OwnModelSlot {
  /// The model, or `nil` before the first read.
  private var model: EditorModel?

  /// The model of the slot. The first read makes a read-only model that
  /// holds `text`.
  ///
  /// - Parameter text: The text of a new model.
  /// - Returns: The model.
  func model(text: String) -> EditorModel {
    if let model {
      return model
    }
    let model = EditorModel.makeReadOnly(text)
    self.model = model
    return model
  }
}
