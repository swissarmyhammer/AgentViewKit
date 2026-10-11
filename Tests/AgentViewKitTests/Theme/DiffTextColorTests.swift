@testable import AgentViewKit
import EditorTheme
import SwiftUI
import Testing

/// Checks that the diff counts use the diff colors of the EditorKit theme,
/// as the diff bands do.
@Suite struct DiffTextColorTests {
  /// A theme with a different color for each role.
  static let theme = DistinctRolesTheme()

  /// The role colors of ``theme``.
  typealias Role = DistinctRolesTheme.Role

  /// The environment that the colors resolve in.
  static let environment = EnvironmentValues()

  @Test func theAddedCountIsTheAddedBandAtFullOpacity() {
    let count = Self.theme.diffAddedText(in: Self.environment).resolve(in: Self.environment)
    #expect(count == Role.added.resolve(in: Self.environment))
  }

  @Test func theRemovedCountIsTheRemovedBandAtFullOpacity() {
    let count = Self.theme.diffRemovedText(in: Self.environment).resolve(in: Self.environment)
    #expect(count == Role.removed.resolve(in: Self.environment))
  }
}
