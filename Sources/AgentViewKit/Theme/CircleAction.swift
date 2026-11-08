import EditorSwiftUI
import SwiftUI

extension View {
  /// Makes this EditorKit `EditorButton` in the action look a round button
  /// of a bar, such as Send, Stop or the microphone of the composer.
  ///
  /// The button shows its symbol alone (`.editorButtonCaptions(_:)`), so its
  /// title is its label and its tooltip. Its bezel is a circle
  /// (`.editorButtonBorderShape(_:)`), and the focus ring of its scope
  /// follows that circle. It is a control of a bar of a thread, with the
  /// accessibility identifier `identifier` and its own focus scope
  /// (``SwiftUI/View/agentControlScope(_:corners:yieldsToHostScope:)``).
  ///
  /// - Parameter identifier: The accessibility identifier of the button, also
  ///   the id of its focus scope.
  /// - Returns: The button as a round button of a bar.
  func circleAction(identifier: String) -> some View {
    editorButtonCaptions(.hidden)
      .editorButtonBorderShape(.circle)
      .accessibilityIdentifier(identifier)
      .agentControlScope(identifier)
  }
}
