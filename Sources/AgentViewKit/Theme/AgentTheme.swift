import SwiftUI

/// The layout tokens of the kit (plan.md §5, §11 decision 11).
///
/// The views of the kit read these tokens. They do not use fixed values.
/// Apply a theme to a subtree with ``SwiftUI/View/agentTheme(_:)``.
///
/// The type holds no color and no font. The EditorKit `Theme` in the
/// environment (`\.editorTheme`) is the one theme of the kit: each color of
/// the kit views and each font come from it: the UI font (`uiFont`) for the
/// chrome, the display font (`displayFont`) for the prose and the text a
/// person types, and the code font (`codeFont`) for the code, one for each
/// EditorKit `FontRole`. A host sets it with `.editorTheme(_:)`, and
/// EditorKit gives `SystemTheme` when no host sets one. This type keeps only
/// the layout tokens that the EditorKit theme does not have: the spacing, the
/// radii, the symbol weight, and the density.
///
/// The type has no glass token. The floating glass is always `.regular`
/// (``SwiftUI/View/agentFloatingGlass()``, D113 answer 3). The Clear look and
/// the Tinted look are system settings, so a theme does not select the glass
/// variant.
///
/// `Docs/decisions/visual-audit.md` (research R12) records the values of
/// ``default``, and `Tests/AgentViewKitTests/Theme/DefaultTokens.json` holds
/// the same values. Change the two files and ``default`` together.
///
/// The type has no padding byte. A view value holds the theme, and until
/// SwiftUI can call `==` for a view type, it compares the bytes of the old and
/// the new value. A padding byte can differ between two equal values.
///
/// Swift puts each stored property, in the order of declaration, at the next
/// offset that is a multiple of its alignment. Thus the type has no padding
/// byte only when each property starts where the property before it ends.
/// `symbolWeight` is the last property with alignment 8, and `density`
/// (alignment 1) comes after it. A property with alignment 8 and
/// a size that is not a multiple of 8 (for example `CGFloat?`, size 9) must
/// come after all the other properties with alignment 8. When you add a
/// stored property, also add it to
/// `ViewValueLayoutTests.theThemeHasNoPaddingByte`. That test fails when the
/// type has a padding byte.
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

  /// The spacing steps.
  public var spacing: Spacing
  /// The corner radii.
  public var radii: Radii
  /// The weight of the SF Symbols.
  public var symbolWeight: Font.Weight
  /// How much detail and space each row shows.
  public var density: Density

  /// Makes a theme.
  ///
  /// - Parameters:
  ///   - spacing: The spacing steps.
  ///   - radii: The corner radii.
  ///   - symbolWeight: The weight of the SF Symbols.
  ///   - density: How much detail and space each row shows.
  public init(
    spacing: Spacing,
    radii: Radii,
    symbolWeight: Font.Weight,
    density: Density
  ) {
    self.spacing = spacing
    self.radii = radii
    self.symbolWeight = symbolWeight
    self.density = density
  }

  /// The default tokens. `Docs/decisions/visual-audit.md` and
  /// `DefaultTokens.json` hold the same values.
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
    symbolWeight: .regular,
    density: .balanced
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

  /// The point values of ``default``, from the R12 visual audit.
  /// `Docs/decisions/visual-audit.md` and `DefaultTokens.json` hold the same
  /// values.
  private enum DefaultValues {
    /// The default extra small spacing step.
    static let spacingExtraSmall: CGFloat = 4
    /// The default small spacing step.
    static let spacingSmall: CGFloat = 8
    /// The default medium spacing step.
    static let spacingMedium: CGFloat = 12
    /// The default large spacing step.
    static let spacingLarge: CGFloat = 16
    /// The default small corner radius.
    static let radiusSmall: CGFloat = 6
    /// The default medium corner radius.
    static let radiusMedium: CGFloat = 8
    /// The default large corner radius.
    static let radiusLarge: CGFloat = 10
  }
}
