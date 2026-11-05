import EditorStyle
import SwiftUI

extension View {
  /// Makes this EditorKit `EditorButton` in the action look a capsule of its
  /// own glass in the container of the floating controls, such as a
  /// suggestion chip or the scroll-to-bottom pill.
  ///
  /// The button is its own glass, not a button on another glass, so it
  /// declares the content surface and keeps the glass style
  /// (`.editorButtonSurface(_:)`, EditorKit `style.md`, rule 4). Its glass has
  /// the id `glassID`, so a change of the floating controls morphs it
  /// (`.floatingGlassID(_:)`, D113 answer 2). It is a control of a bar of a
  /// thread, with the accessibility identifier `identifier` and its own focus
  /// scope (``SwiftUI/View/agentControlScope(_:corners:yieldsToHostScope:)``).
  ///
  /// - Parameters:
  ///   - glassID: The id of the glass of the button.
  ///   - identifier: The accessibility identifier of the button, also the id
  ///     of its focus scope.
  /// - Returns: The button as a floating glass capsule.
  func floatingGlassAction(glassID: FloatingGlassID, identifier: String) -> some View {
    editorButtonSurface(.content)
      .buttonBorderShape(.capsule)
      .floatingGlassID(glassID)
      .accessibilityIdentifier(identifier)
      .agentControlScope(identifier)
  }
}
