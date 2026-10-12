import AgentViewKit
import AgentViewKitTestSupport
import EditorSwiftUI
import SwiftUI
import Testing

/// Checks that the prose of the kit uses the `proseFont` role of the
/// EditorKit theme in the environment.
///
/// ``DistinctRolesTheme`` has a prose font that is much larger than the body
/// text, so a view that reads the role is taller with that theme than with no
/// theme.
@Suite(.serialized, .hostedSerially) @MainActor struct ProseFontHostedTests {
  /// The height of the role title of a hosted message header.
  ///
  /// - Parameter view: The message header, with its environment.
  /// - Returns: The height of the role title, in points.
  /// - Throws: An issue when the role title has no frame.
  static func roleTitleHeight(of view: some View) throws -> CGFloat {
    let harness = HostedViewHarness(view)
    defer { harness.close() }
    harness.pump()
    return try #require(harness.frame(identifier: MessageHeader.roleIdentifier)).height
  }

  @Test func theMessageHeaderUsesTheProseFontOfTheEditorTheme() throws {
    let themed = try Self.roleTitleHeight(
      of: MessageHeader(role: .assistant).editorTheme(DistinctRolesTheme()))
    let unthemed = try Self.roleTitleHeight(of: MessageHeader(role: .assistant))

    #expect(themed > unthemed)
  }
}
