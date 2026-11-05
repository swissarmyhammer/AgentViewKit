import EditorStyle
import SwiftUI

/// The style of the button of each ``StatusBar`` of the kit: the focus scope
/// of a bar control around the button of the action.
///
/// The button is an EditorKit `EditorButton` in the action look, so the
/// surface it stands on gives its button style: the glass style in content
/// and in a bar with no glass, and the bordered style on the glass of the
/// request deck (`.editorButtonSurface(_:)`). The button is a control of a bar
/// of a thread, so it takes the focus scope `agentControl:<identifier>`
/// (``SwiftUI/View/agentControlScope(_:corners:yieldsToHostScope:)``), and it
/// is a target of the EditorKit jump and navigation.
///
/// Each view of the kit that shows a ``StatusBar`` sets this style with
/// ``SwiftUI/View/statusBarActionStyle(_:)``: the ``StateBanner``, the
/// ``SessionStreamBanner``, the ``AgentConnectionBanner`` and the row of a
/// notice (``NoticeRow``). This is the one
/// place where the kit gives the button of a bar its scope.
struct AgentStatusBarActionStyle: StatusBarActionStyle {
  /// Gives the button the scope of a bar control.
  ///
  /// - Parameter configuration: The action and its button.
  /// - Returns: The styled button in its scope.
  func makeBody(configuration: StatusBarActionConfiguration) -> some View {
    configuration.button
      .agentControlScope(configuration.action.identifier)
  }
}

#Preview("A bar with the kit style, in content and on the glass of the deck") {
  VStack(alignment: .leading) {
    StatusBar(
      message: PreviewFixtures.failedTurnStatusMessage, action: PreviewFixtures.statusAction(isEnabled: true))
    StatusBar(
      message: PreviewFixtures.failedTurnStatusMessage, action: PreviewFixtures.statusAction(isEnabled: true))
      .editorButtonSurface(.glass)
  }
  .statusBarActionStyle(AgentStatusBarActionStyle())
  .padding()
}
