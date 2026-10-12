import AgentViewKitTestSupport
import EditorSwiftUI
import EditorTheme
import SwiftUI
import Testing

/// Tests for ``ThemeHeightExpectations``.
@Suite(.serialized, .hostedSerially) @MainActor struct ThemeHeightExpectationsTests {
  /// The accessibility identifier of the text of each view of the tests.
  static let identifier = "theme-height-text"

  /// The text of each view of the tests.
  static let text = "Height"

  /// A text in the prose font of the EditorKit theme in the environment.
  struct ProseText: View {
    /// The EditorKit theme in the environment.
    @Environment(\.editorTheme) private var theme

    var body: some View {
      Text(ThemeHeightExpectationsTests.text)
        .font(theme.proseFont)
        .accessibilityIdentifier(ThemeHeightExpectationsTests.identifier)
    }
  }

  @Test func aViewThatReadsTheThemePasses() throws {
    try ThemeHeightExpectations.expectThemeIncreasesHeight(of: ProseText(), identifier: Self.identifier)
  }

  @Test func aViewThatIgnoresTheThemeFails() throws {
    let fixed = Text(Self.text).accessibilityIdentifier(Self.identifier)

    try withKnownIssue {
      try ThemeHeightExpectations.expectThemeIncreasesHeight(of: fixed, identifier: Self.identifier)
    } matching: { issue in
      issue.error == nil
    }
  }
}
