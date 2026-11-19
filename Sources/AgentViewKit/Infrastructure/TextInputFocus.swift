import AppKit

/// The one rule of the kit that tells if a text input has the focus.
///
/// A text input that has the focus has an editable text view as the first
/// responder of its window: the field editor of an `NSTextField`, or the
/// input text view of an EditorKit editor or field. That text view must get
/// Return, Esc, the arrow keys and the typed characters, and Command-G stays
/// its find (D133, D137 (d)). A text view that does not edit, such as a
/// selectable label or a rendered message, is not a text input.
enum TextInputFocus {
  /// Tells if `responder` is a text input that edits.
  ///
  /// - Parameter responder: The first responder of a window, or `nil`.
  /// - Returns: `true` when `responder` is an editable text view.
  static func isEditing(_ responder: NSResponder?) -> Bool {
    guard let text = responder as? NSText else { return false }
    return text.isEditable
  }
}
