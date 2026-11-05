import AgentViewKitStyle
import EditorSwiftUI

/// The sample parts of a ``StatusBar`` that more than one suite shows.
@MainActor
enum StatusBarFixtures {
  /// Makes a Reload button of a bar that takes a press. A press does nothing.
  ///
  /// - Parameters:
  ///   - identifier: The accessibility identifier of the button.
  ///   - hint: The accessibility hint of the button, or `nil` for no hint.
  /// - Returns: The action.
  static func reloadAction(identifier: String, hint: String? = nil) -> StatusBar.Action {
    StatusBar.Action(
      title: "Reload", systemImage: EditorSymbol.action(.reload).systemImage, identifier: identifier,
      isEnabled: true, hint: hint, perform: {})
  }
}
