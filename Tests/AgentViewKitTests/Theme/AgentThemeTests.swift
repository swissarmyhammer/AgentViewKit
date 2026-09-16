import AgentViewKit
import AgentViewKitTestSupport
import EditorTheme
import Foundation
import PackageFileSupport
import SwiftUI
import Testing

/// A view that writes the accent of the environment theme into its
/// accessibility value, so that a test can read the theme of a hosted view.
private struct ThemeProbeView: View {
  /// The accessibility identifier of the probe.
  static let identifier = "agent-theme-probe"

  @Environment(\.agentTheme) private var theme

  var body: some View {
    Text("probe")
      .accessibilityIdentifier(Self.identifier)
      .accessibilityValue(AgentThemeTests.probeValue(of: theme))
  }
}

@Suite(.serialized) @MainActor struct AgentThemeTests {
  /// The text that ``ThemeProbeView`` writes for `theme`.
  ///
  /// - Parameter theme: The theme that the probe reads.
  /// - Returns: The description of the accent of `theme`.
  static func probeValue(of theme: AgentTheme) -> String {
    String(describing: theme.accent)
  }

  /// A theme that is different from ``AgentTheme/default`` in each field that
  /// the probe reads.
  private static let custom: AgentTheme = {
    var theme = AgentTheme.default
    theme.accent = .purple
    theme.density = .compact
    return theme
  }()

  // MARK: - The JSON match

  @Test func defaultMatchesTheTokenFile() throws {
    let tokens = try DefaultTokens.load()
    let theme = AgentTheme.default

    #expect(theme.spacing == tokens.spacing)
    #expect(theme.radii == tokens.radii)
    #expect(theme.materialLevel == tokens.materialLevel)
    #expect(theme.symbolWeight == (try ThemeTokenNames.weight(named: tokens.symbolWeight)))
    #expect(theme.accent == (try ThemeTokenNames.color(named: tokens.accent)))
    #expect(theme.density == tokens.density)
    #expect(theme.proseFont == (try tokens.proseFont.font()))
    #expect(theme.codeFont == (try tokens.codeFont.font()))
    #expect(theme.statusColors.running == (try ThemeTokenNames.color(named: tokens.statusColors.running)))
    #expect(theme.statusColors.completed == (try ThemeTokenNames.color(named: tokens.statusColors.completed)))
    #expect(theme.statusColors.failed == (try ThemeTokenNames.color(named: tokens.statusColors.failed)))
    #expect(theme.statusColors.cancelled == (try ThemeTokenNames.color(named: tokens.statusColors.cancelled)))
    #expect(theme.statusColors.pending == (try ThemeTokenNames.color(named: tokens.statusColors.pending)))
  }

  @Test func spacingAndRadiiIncreaseInOrder() {
    let spacing = AgentTheme.default.spacing
    #expect(spacing.xs < spacing.s)
    #expect(spacing.s < spacing.m)
    #expect(spacing.m < spacing.l)
    let radii = AgentTheme.default.radii
    #expect(radii.s < radii.m)
    #expect(radii.m < radii.l)
  }

  // MARK: - The environment

  @Test func hostedViewReadsTheCustomTheme() throws {
    let harness = HostedViewHarness(ThemeProbeView().agentTheme(Self.custom))
    defer { harness.close() }
    harness.pump()

    let probe = try #require(harness.element(identifier: ThemeProbeView.identifier))
    #expect(probe.value == Self.probeValue(of: Self.custom))
    #expect(probe.value != Self.probeValue(of: .default))
  }

  @Test func hostedViewReadsTheDefaultThemeWithoutTheModifier() throws {
    let harness = HostedViewHarness(ThemeProbeView())
    defer { harness.close() }
    harness.pump()

    let probe = try #require(harness.element(identifier: ThemeProbeView.identifier))
    #expect(probe.value == Self.probeValue(of: .default))
  }

  @Test func environmentValueDefaultsToTheDefaultTheme() {
    #expect(EnvironmentValues().agentTheme == .default)
  }

  // MARK: - The EditorKit bridge

  @Test func bridgeMapsTheAccentToTheTokenTint() {
    #expect(AgentTheme.default.editorTheme.tokenTint == AgentTheme.default.accent)
    #expect(Self.custom.editorTheme.tokenTint == Self.custom.accent)
  }

  @Test func bridgeMapsTheCodeFontToEachCapture() {
    let editorTheme = AgentTheme.default.editorTheme
    for key in [StyleKey.keyword, .string, .comment, StyleKey("function.call")] {
      let attributes = editorTheme.attributes(for: key)
      #expect(attributes.font == AgentTheme.default.codeFont)
      #expect(attributes.foregroundColor == editorTheme.editorForeground)
      #expect(attributes.styleKey == key.rawValue)
    }
  }

  @Test func bridgeMapsTheSystemColors() {
    let editorTheme = AgentTheme.default.editorTheme
    #expect(editorTheme.editorBackground == AgentTheme.EditorSystemColors.background)
    #expect(editorTheme.editorForeground == AgentTheme.EditorSystemColors.foreground)
    #expect(editorTheme.selection == AgentTheme.EditorSystemColors.selection)
    #expect(editorTheme.gutterBackground == AgentTheme.EditorSystemColors.gutterBackground)
    #expect(editorTheme.statusBarBackground == AgentTheme.EditorSystemColors.barBackground)
    #expect(editorTheme.tabBarBackground == AgentTheme.EditorSystemColors.barBackground)
  }

  // MARK: - Density

  @Test func rowPaddingIncreasesWithDensity() {
    let paddings = AgentTheme.Density.allCases.map { density in
      var theme = AgentTheme.default
      theme.density = density
      return theme.rowPadding
    }
    #expect(AgentTheme.Density.allCases == [.compact, .balanced, .detailed])
    #expect(zip(paddings, paddings.dropFirst()).allSatisfy { $0 < $1 })
  }
}

// MARK: - The token file

/// The decoded form of `DefaultTokens.json`.
///
/// The file names each color, font, and weight. ``ThemeTokenNames`` changes a
/// name into its SwiftUI value.
private struct DefaultTokens: Decodable {
  /// A font in the file: a text style and a design.
  struct FontToken: Decodable {
    /// The name of the `Font.TextStyle`, such as `body`.
    let textStyle: String
    /// The name of the `Font.Design`, such as `monospaced`.
    let design: String

    /// The SwiftUI font of the token.
    ///
    /// - Returns: The system font with the style and the design.
    /// - Throws: ``ThemeTokenNames/LookupError/unknownName(_:)`` for a name
    ///   that is not known.
    func font() throws -> Font {
      try ThemeTokenNames.font(textStyle: textStyle, design: design)
    }
  }

  /// The status colors in the file, as names.
  struct StatusColorTokens: Decodable {
    let running: String
    let completed: String
    let failed: String
    let cancelled: String
    let pending: String
  }

  let spacing: AgentTheme.Spacing
  let radii: AgentTheme.Radii
  let materialLevel: AgentTheme.MaterialLevel
  let symbolWeight: String
  let accent: String
  let density: AgentTheme.Density
  let proseFont: FontToken
  let codeFont: FontToken
  let statusColors: StatusColorTokens

  /// The token file, relative to the package root.
  private static let relativePath = "Tests/AgentViewKitTests/Theme/DefaultTokens.json"

  /// Reads and decodes the token file.
  ///
  /// - Returns: The decoded tokens.
  static func load() throws -> DefaultTokens {
    let data = try Data(contentsOf: try PackageFiles.file(relativePath))
    return try JSONDecoder().decode(DefaultTokens.self, from: data)
  }
}
