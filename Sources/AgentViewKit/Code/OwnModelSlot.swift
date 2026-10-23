import EditorSwiftUI

/// The model that an editor view keeps when the host gives no model.
///
/// ``CodeBlockView``, ``CommandOutputView``, and ``TerminalView`` keep a slot
/// of a read-only model in a `@State` value. ``ElicitationTextField``, the
/// comment field of ``PermissionView`` and the search field of
/// ``SessionListView`` keep a slot of an editable model. The slot makes the
/// model at the first read. A `@State` value that holds the model directly
/// would make a new model each time SwiftUI makes the view value again.
final class OwnModelSlot {
  /// The model, or `nil` before the first read.
  private var model: EditorModel?

  /// The function that makes the model from its first text.
  private let makeModel: (String) -> EditorModel

  /// Makes an empty slot.
  ///
  /// - Parameter makeModel: The function that makes the model from its first
  ///   text. The default makes a read-only model.
  init(makeModel: @escaping (String) -> EditorModel = { EditorModel.makeReadOnly($0) }) {
    self.makeModel = makeModel
  }

  /// Makes an empty slot of an editable model.
  ///
  /// - Returns: The slot.
  static func makeEditable() -> OwnModelSlot {
    OwnModelSlot { EditorModel($0) }
  }

  /// The model of the slot. The first read makes the model that holds
  /// `text`.
  ///
  /// - Parameter text: The text of a new model.
  /// - Returns: The model.
  func model(text: String) -> EditorModel {
    if let model {
      return model
    }
    let model = makeModel(text)
    self.model = model
    return model
  }
}
