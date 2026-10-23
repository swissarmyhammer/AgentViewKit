import EditorSwiftUI

/// The model that a view keeps in its state when the host gives no model.
///
/// ``CodeBlockView``, ``CommandOutputView``, and ``TerminalView`` keep a
/// read-only slot in a `@State` value. The text inputs of the kit, such as
/// the comment field of ``PermissionView``, the search field of
/// ``SessionListView``, and ``ElicitationTextField``, keep an editable slot.
/// The slot makes the model at the first read. A `@State` value that holds
/// the model directly would make a new model each time SwiftUI makes the
/// view value again.
final class OwnModelSlot {
  /// Whether the model of the slot takes edits.
  private let isEditable: Bool

  /// The model, or `nil` before the first read.
  private var model: EditorModel?

  /// Makes an empty slot.
  ///
  /// - Parameter editable: Whether the model of the slot takes edits. The
  ///   default makes a read-only model.
  init(editable: Bool = false) {
    isEditable = editable
  }

  /// The model of the slot. The first read makes a model that holds `text`:
  /// an editable model when the slot is editable, and a read-only model
  /// otherwise.
  ///
  /// - Parameter text: The text of a new model.
  /// - Returns: The model.
  func model(text: String) -> EditorModel {
    if let model {
      return model
    }
    let model = isEditable ? EditorModel(text) : EditorModel.makeReadOnly(text)
    self.model = model
    return model
  }
}
