import AgentViewKitTestSupport
import EditorSwiftUI
import EditorTheme
import SwiftUI
import Testing

@testable import AgentViewKit

/// Tests the factor that scales the fixed bounds of the kit with the theme font (^dcs0pbj).
@Suite @MainActor struct ThemeFontScaleTests {
  /// The size of the display face of ``DistinctRolesTheme``, the `largeTitle` system size, is
  /// twice the default size.
  private static let largeTitleScale: CGFloat = 2

  /// The height of a player, in points, at the default theme font.
  private static let playerHeight: CGFloat = 44

  /// A theme font smaller than the default.
  private static let smallFontScale: CGFloat = 0.5

  /// The default font environment.
  private var context: Font.Context { EnvironmentValues().fontResolutionContext }

  @Test(arguments: FontRole.allCases)
  func theDefaultThemeLeavesEachBoundAsItIs(role: FontRole) {
    #expect(ThemeFontScale.scale(of: role, in: defaultEditorTheme, context: context) == 1)
  }

  @Test func aLargerThemeFontScalesTheBoundsUp() {
    let scale = ThemeFontScale.scale(of: .display, in: DistinctRolesTheme(), context: context)
    #expect(scale == Self.largeTitleScale)
  }

  @Test func aLargerThemeFontScalesThePlayerUp() {
    let height = MediaPlayerPreview.frameHeight(Self.playerHeight, fontScale: Self.largeTitleScale)
    #expect(height == Self.playerHeight * Self.largeTitleScale)
  }

  /// The system draws the controls of a player, and they do not shrink with the theme font.
  @Test func aSmallerThemeFontKeepsThePlayerHeight() {
    let height = MediaPlayerPreview.frameHeight(Self.playerHeight, fontScale: Self.smallFontScale)
    #expect(height == Self.playerHeight)
  }
}
