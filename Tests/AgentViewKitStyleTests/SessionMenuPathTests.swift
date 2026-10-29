import AgentViewKitStyle
import EditorCommands
import Testing

/// Checks that the Session menu path comes from the style library, so a kit
/// that links only `AgentViewKitStyle` puts its commands in the same menu as
/// the agent verbs.
@Suite struct SessionMenuPathTests {
  @Test func theSessionMenuPathIsTheSessionMenu() {
    #expect(MenuPath.session == "Session")
  }
}
