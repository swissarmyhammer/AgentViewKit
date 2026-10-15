import AgentViewKit
import AgentViewKitTestSupport
import EditorSwiftUI
import EditorTheme
import Foundation
import PackageFileSupport
import SwiftUI
import Testing

/// A view that writes the density of the environment theme into its
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

@Suite(.serialized, .hostedSerially) @MainActor struct AgentThemeTests {
  /// The text that ``ThemeProbeView`` writes for `theme`.
  ///
  /// - Parameter theme: The theme that the probe reads.
  /// - Returns: The raw name of the density of `theme`.
  static func probeValue(of theme: AgentTheme) -> String {
    theme.density.rawValue
  }

  /// The labels of the stored fields of ``AgentTheme/default`` whose value
  /// matches `isMatch`.
  ///
  /// - Parameter isMatch: The check of one field value.
  /// - Returns: The field labels, in the order of the declaration.
  static func fieldLabels(where isMatch: (Any) -> Bool) -> [String] {
    Mirror(reflecting: AgentTheme.default).children
      .filter { isMatch($0.value) }
      .compactMap(\.label)
  }

  /// A theme that is different from ``AgentTheme/default`` in each field that
  /// the probe reads.
  private static let custom: AgentTheme = {
    var theme = AgentTheme.default
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
    #expect(theme.density == tokens.density)
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
    harness.render()

    let probe = try #require(harness.element(identifier: ThemeProbeView.identifier))
    #expect(probe.value == Self.probeValue(of: Self.custom))
    #expect(probe.value != Self.probeValue(of: .default))
  }

  @Test func hostedViewReadsTheDefaultThemeWithoutTheModifier() throws {
    let harness = HostedViewHarness(ThemeProbeView())
    defer { harness.close() }
    harness.render()

    let probe = try #require(harness.element(identifier: ThemeProbeView.identifier))
    #expect(probe.value == Self.probeValue(of: .default))
  }

  @Test func environmentValueDefaultsToTheDefaultTheme() {
    #expect(EnvironmentValues().agentTheme == .default)
  }

  // MARK: - The EditorKit theme

  @Test func theEditorThemeOfTheEnvironmentDefaultsToTheSystemTheme() {
    #expect(EnvironmentValues().editorTheme is SystemTheme)
  }

  @Test func theKitThemeHoldsNoColor() {
    #expect(Self.fieldLabels { $0 is Color } == [])
  }

  @Test func theKitThemeHoldsNoFont() {
    #expect(Self.fieldLabels { $0 is Font } == [])
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
/// The file names each weight. ``ThemeTokenNames`` changes a name into its
/// SwiftUI value. The file has no color and no font: each color and each
/// font of the kit come from the EditorKit theme.
private struct DefaultTokens: Decodable {
  let spacing: AgentTheme.Spacing
  let radii: AgentTheme.Radii
  let materialLevel: AgentTheme.MaterialLevel
  let symbolWeight: String
  let density: AgentTheme.Density

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
