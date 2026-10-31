import AgentViewKitStyle
import Testing

/// Checks the Dismiss action of a dismissible ``StatusBar``.
@Suite @MainActor struct StatusBarDismissTests {
  @Test func theDismissActionHasTheDismissSymbol() {
    let action = StatusBar.Action.makeDismiss(identifier: "dismiss", perform: {})

    #expect(action.systemImage == SharedSymbol.dismiss)
  }

  @Test func theDismissActionHasItsIdentifier() {
    let action = StatusBar.Action.makeDismiss(identifier: "dismiss", perform: {})

    #expect(action.identifier == "dismiss")
  }

  @Test func theDismissActionTakesAPress() {
    let action = StatusBar.Action.makeDismiss(identifier: "dismiss", perform: {})

    #expect(action.isEnabled)
  }

  @Test func theDismissActionShowsOnlyItsSymbol() {
    let action = StatusBar.Action.makeDismiss(identifier: "dismiss", perform: {})

    #expect(action.isIconOnly)
  }

  @Test func anActionShowsItsTitleByDefault() {
    let action = StatusBar.Action(
      title: "Retry", systemImage: SharedSymbol.reload, identifier: "retry", isEnabled: true, perform: {})

    #expect(!action.isIconOnly)
  }

  @Test func theDismissActionRunsItsClosure() {
    var pressed = false
    let action = StatusBar.Action.makeDismiss(identifier: "dismiss") { pressed = true }

    action.perform()

    #expect(pressed)
  }
}
