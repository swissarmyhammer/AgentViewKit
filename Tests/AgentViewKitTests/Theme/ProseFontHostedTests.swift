import AgentViewKit
import AgentViewKitTestSupport
import SwiftUI
import Testing

/// Checks that the prose of the kit uses the `proseFont` role of the
/// EditorKit theme in the environment.
///
/// ``DistinctRolesTheme`` has a prose font that is much larger than the body
/// text, so a view that reads the role is taller with that theme than with no
/// theme.
@Suite(.serialized, .hostedSerially) @MainActor struct ProseFontHostedTests {
  @Test func theMessageHeaderUsesTheProseFontOfTheEditorTheme() throws {
    try ThemeHeightExpectations.expectThemeIncreasesHeight(
      of: MessageHeader(role: .assistant), identifier: MessageHeader.roleIdentifier)
  }
}
