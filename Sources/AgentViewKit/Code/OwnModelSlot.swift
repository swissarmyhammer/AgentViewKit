import EditorCore
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

  /// The model of the slot. The first read makes the model with `make`.
  ///
  /// - Parameters:
  ///   - text: The text of a new model.
  ///   - make: Makes a model that holds a text, such as a read-only model in
  ///     the rendered presentation (``RenderedMarkdownView``).
  /// - Returns: The model.
  func model(text: String, make: (String) -> EditorModel) -> EditorModel {
    if let model {
      return model
    }
    let model = make(text)
    self.model = model
    return model
  }

  /// The model of the slot. The first read makes a model that holds `text`:
  /// an editable model when the slot is editable, and a read-only model
  /// otherwise.
  ///
  /// - Parameters:
  ///   - text: The text of a new model.
  ///   - recordsUndo: `false` to make an editable model that keeps no undo
  ///     history, such as the input of a sensitive answer
  ///     (``EditorModel/makeWithNoUndo(_:)``).
  /// - Returns: The model.
  func model(text: String, recordsUndo: Bool = true) -> EditorModel {
    if let model {
      return model
    }
    let model =
      if !isEditable {
        EditorModel.makeReadOnly(text)
      } else if recordsUndo {
        EditorModel(text)
      } else {
        EditorModel.makeWithNoUndo(text)
      }
    self.model = model
    return model
  }
}

extension EditorModel {
  /// Makes an editable model that keeps no undo history: its engine has an
  /// undo depth of zero, so an edit leaves no undo step with the text.
  ///
  /// - Parameter text: The text of the model.
  /// - Returns: The model.
  static func makeWithNoUndo(_ text: String) -> EditorModel {
    EditorModel(engine: EditorEngine(text, maxUndoDepth: 0))
  }
}
