import SwiftUI

/// The design tokens of the kit (plan.md §5, §11 decision 11).
///
/// The views of the kit read these tokens. They do not use fixed values.
/// Apply a theme to a subtree with ``SwiftUI/View/agentTheme(_:)``. A view
/// that hosts EditorKit applies ``editorTheme`` with `.editorTheme(_:)`, so
/// that the code colors agree with the chrome.
///
/// `Tests/AgentViewKitTests/Theme/DefaultTokens.json` holds the values of
/// ``default``. Research R12 changes that file and ``default`` together.
nonisolated public struct AgentTheme: Equatable, Sendable {
  /// The spacing steps, in points, from the smallest to the largest.
  public struct Spacing: Equatable, Sendable, Codable {
    /// The extra small step.
    public var xs: CGFloat
    /// The small step.
    public var s: CGFloat
    /// The medium step.
    public var m: CGFloat
    /// The large step.
    public var l: CGFloat

    /// Makes a set of spacing steps.
    ///
    /// - Parameters:
    ///   - xs: The extra small step.
    ///   - s: The small step.
    ///   - m: The medium step.
    ///   - l: The large step.
    public init(xs: CGFloat, s: CGFloat, m: CGFloat, l: CGFloat) {
      self.xs = xs
      self.s = s
      self.m = m
      self.l = l
    }
  }

  /// The corner radii, in points, from the smallest to the largest.
  public struct Radii: Equatable, Sendable, Codable {
    /// The small radius.
    public var s: CGFloat
    /// The medium radius.
    public var m: CGFloat
    /// The large radius.
    public var l: CGFloat

    /// Makes a set of corner radii.
    ///
    /// - Parameters:
    ///   - s: The small radius.
    ///   - m: The medium radius.
    ///   - l: The large radius.
    public init(s: CGFloat, m: CGFloat, l: CGFloat) {
      self.s = s
      self.m = m
      self.l = l
    }
  }

  /// The strength of the Liquid Glass material on the chrome (plan.md §5).
  public enum MaterialLevel: String, Equatable, Sendable, Codable, CaseIterable {
    /// The standard glass.
    case regular
    /// A glass that shows more of the content below it.
    case thin
    /// A clear glass.
    case clear
  }

  /// How much detail and space each row shows.
  ///
  /// The cases have the order from the least space to the most space.
  public enum Density: String, Equatable, Sendable, Codable, CaseIterable {
    /// Rows with the least space.
    case compact
    /// Rows with the standard space.
    case balanced
    /// Rows with the most space and detail.
    case detailed
  }

  /// The colors that show the status of a tool call, a plan entry, or a run.
  public struct StatusColors: Equatable, Sendable {
    /// The color of work that runs now.
    public var running: Color
    /// The color of work that completed.
    public var completed: Color
    /// The color of work that failed.
    public var failed: Color
    /// The color of work that was cancelled.
    public var cancelled: Color
    /// The color of work that did not start.
    public var pending: Color

    /// Makes a set of status colors.
    ///
    /// - Parameters:
    ///   - running: The color of work that runs now.
    ///   - completed: The color of work that completed.
    ///   - failed: The color of work that failed.
    ///   - cancelled: The color of work that was cancelled.
    ///   - pending: The color of work that did not start.
    public init(running: Color, completed: Color, failed: Color, cancelled: Color, pending: Color) {
      self.running = running
      self.completed = completed
      self.failed = failed
      self.cancelled = cancelled
      self.pending = pending
    }
  }

  /// The spacing steps.
  public var spacing: Spacing
  /// The corner radii.
  public var radii: Radii
  /// The strength of the glass material on the chrome.
  public var materialLevel: MaterialLevel
  /// The weight of the SF Symbols.
  public var symbolWeight: Font.Weight
  /// The tint of the primary actions and of the status.
  public var accent: Color
  /// How much detail and space each row shows.
  public var density: Density
  /// The font of the prose. The default is SF Pro.
  public var proseFont: Font
  /// The font of code, tool input and output, and terminals. The default is
  /// SF Mono.
  public var codeFont: Font
  /// The status colors.
  public var statusColors: StatusColors

  /// Makes a theme.
  ///
  /// - Parameters:
  ///   - spacing: The spacing steps.
  ///   - radii: The corner radii.
  ///   - materialLevel: The strength of the glass material.
  ///   - symbolWeight: The weight of the SF Symbols.
  ///   - accent: The tint of the primary actions and of the status.
  ///   - density: How much detail and space each row shows.
  ///   - proseFont: The font of the prose.
  ///   - codeFont: The font of code.
  ///   - statusColors: The status colors.
  public init(
    spacing: Spacing,
    radii: Radii,
    materialLevel: MaterialLevel,
    symbolWeight: Font.Weight,
    accent: Color,
    density: Density,
    proseFont: Font,
    codeFont: Font,
    statusColors: StatusColors
  ) {
    self.spacing = spacing
    self.radii = radii
    self.materialLevel = materialLevel
    self.symbolWeight = symbolWeight
    self.accent = accent
    self.density = density
    self.proseFont = proseFont
    self.codeFont = codeFont
    self.statusColors = statusColors
  }

  /// The default tokens. `DefaultTokens.json` holds the same values.
  public static let `default` = AgentTheme(
    spacing: Spacing(
      xs: DefaultValues.spacingExtraSmall,
      s: DefaultValues.spacingSmall,
      m: DefaultValues.spacingMedium,
      l: DefaultValues.spacingLarge
    ),
    radii: Radii(
      s: DefaultValues.radiusSmall,
      m: DefaultValues.radiusMedium,
      l: DefaultValues.radiusLarge
    ),
    materialLevel: .regular,
    symbolWeight: .regular,
    accent: .accentColor,
    density: .balanced,
    proseFont: .system(.body, design: .default),
    codeFont: .system(.body, design: .monospaced),
    statusColors: StatusColors(
      running: .blue,
      completed: .green,
      failed: .red,
      cancelled: .gray,
      pending: .secondary
    )
  )

  /// The vertical padding of a row, in points.
  ///
  /// The value is a spacing step that ``density`` selects: ``Spacing/xs``
  /// for ``Density/compact``, ``Spacing/s`` for ``Density/balanced``, and
  /// ``Spacing/m`` for ``Density/detailed``. The padding increases with the
  /// density when the spacing steps increase.
  public var rowPadding: CGFloat {
    switch density {
    case .compact: spacing.xs
    case .balanced: spacing.s
    case .detailed: spacing.m
    }
  }

  /// The point values of ``default``. `DefaultTokens.json` holds the same
  /// values.
  private enum DefaultValues {
    /// The default extra small spacing step.
    static let spacingExtraSmall: CGFloat = 4
    /// The default small spacing step.
    static let spacingSmall: CGFloat = 8
    /// The default medium spacing step.
    static let spacingMedium: CGFloat = 12
    /// The default large spacing step.
    static let spacingLarge: CGFloat = 20
    /// The default small corner radius.
    static let radiusSmall: CGFloat = 4
    /// The default medium corner radius.
    static let radiusMedium: CGFloat = 8
    /// The default large corner radius.
    static let radiusLarge: CGFloat = 12
  }
}
