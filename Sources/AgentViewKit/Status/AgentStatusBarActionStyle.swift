import SwiftUI

/// The style of the button of each ``StatusBar`` of the kit: the button style
/// of its place, and the focus scope of a bar control.
///
/// The button is a secondary action (``RequestAction/secondary``), so its
/// place gives its button style (``RequestDeckPlace/style(of:)``): the
/// `.glass` style in content and in a bar with no glass, and the `.bordered`
/// style on the glass of the request deck. The button is a control of a bar
/// of a thread, so it takes the focus scope `agentControl:<identifier>`
/// (``SwiftUI/View/agentControlScope(_:corners:yieldsToHostScope:)``), and it
/// is a target of the EditorKit jump and navigation.
///
/// Each view of the kit that shows a ``StatusBar`` sets this style with
/// ``SwiftUI/View/statusBarActionStyle(_:)``: the ``StateBanner``, the
/// ``SessionStreamBanner``, the ``AgentConnectionBanner`` and the row of a
/// notice (``NoticeRow``). This is the one
/// place where the kit gives the button of a bar its look and its scope.
struct AgentStatusBarActionStyle: StatusBarActionStyle {
  /// Gives the button the button style of its place and the scope of a bar
  /// control.
  ///
  /// - Parameter configuration: The action and its button.
  /// - Returns: The styled button in its scope.
  func makeBody(configuration: StatusBarActionConfiguration) -> some View {
    configuration.button
      .requestActionStyle(.secondary)
      .agentControlScope(configuration.action.identifier)
  }
}

#Preview("A bar with the kit style, in content and on the glass of the deck") {
  VStack(alignment: .leading) {
    StatusBar(
      message: PreviewFixtures.failedTurnStatusMessage, action: PreviewFixtures.statusAction(isEnabled: true))
    StatusBar(
      message: PreviewFixtures.failedTurnStatusMessage, action: PreviewFixtures.statusAction(isEnabled: true))
      .requestActionPlace(.bar)
  }
  .statusBarActionStyle(AgentStatusBarActionStyle())
  .padding()
}
