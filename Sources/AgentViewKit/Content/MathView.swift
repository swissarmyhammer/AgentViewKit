import SwiftUI
// `Math.typographicBounds` is the one call that tells whether the engine
// parsed an expression. The engine marks it with the `Textual` SPI. The
// manifest pins the engine to an exact version, and
// Docs/decisions/math-engine.md records this use.
@_spi(Textual) import SwiftUIMath

/// Inline or block LaTeX, typeset with the math engine of the kit
/// (plan.md §9 B, §11 decision 7).
///
/// The engine is `swiftui-math`. It typesets with Core Text.
/// Docs/decisions/math-engine.md records the choice.
///
/// - The font size is the point size of the environment font, times
///   ``fontScale``. Thus the math follows Dynamic Type.
/// - When the engine cannot parse the source, the view shows the source in
///   a monospaced font. It never shows a blank.
/// - The accessibility element has the identifier `math-inline` or
///   `math-block`. Its label is the LaTeX source. The element of the source
///   fallback also has the source as its value.
/// - The view has no animation, so Reduce Motion changes nothing.
public struct MathView: View {
  /// The name of the math engine. It is the package identity of the engine
  /// and the `engine:` line of Docs/decisions/math-engine.md.
  public static let engineName = "swiftui-math"

  /// The accessibility identifier of inline math.
  public static let inlineIdentifier = "math-inline"

  /// The accessibility identifier of block math.
  public static let blockIdentifier = "math-block"

  /// The size of the math font, relative to the environment font. This is
  /// the default of the Textual math properties, so that the kit math and
  /// the Textual math have the same size.
  public nonisolated static let fontScale: CGFloat = 1.2

  /// The font size that ``canTypeset(_:display:)`` uses. A parse result does
  /// not change with the font size.
  nonisolated static let probeFontSize: CGFloat = 1

  /// The math font. This is the default of the Textual math properties.
  nonisolated static let fontName = Math.Font.Name.latinModern

  /// The LaTeX source, with no `$` delimiters.
  let latex: String

  /// Whether the math is a block (display style) or inline (text style).
  let display: Bool

  @Environment(\.font) private var font
  @Environment(\.fontResolutionContext) private var fontResolutionContext

  /// Makes the view of one LaTeX expression.
  ///
  /// - Parameters:
  ///   - latex: The LaTeX source, with no `$` delimiters.
  ///   - display: `true` for block math in display style, `false` for
  ///     inline math in text style.
  public init(latex: String, display: Bool) {
    self.latex = latex
    self.display = display
  }

  /// The accessibility identifier of math in a display style.
  ///
  /// - Parameter display: `true` for block math.
  /// - Returns: `math-block` or `math-inline`.
  public static func identifier(display: Bool) -> String {
    display ? blockIdentifier : inlineIdentifier
  }

  /// Whether the engine can typeset `latex`.
  ///
  /// - Parameters:
  ///   - latex: The LaTeX source, with no `$` delimiters.
  ///   - display: `true` for block math.
  /// - Returns: `false` when the engine cannot parse the source, or when the
  ///   source makes no glyph.
  public nonisolated static func canTypeset(_ latex: String, display: Bool) -> Bool {
    bounds(of: latex, display: display, fontSize: probeFontSize).width > 0
  }

  /// The typographic bounds of `latex` in the kit math font.
  ///
  /// - Parameters:
  ///   - latex: The LaTeX source, with no `$` delimiters.
  ///   - display: `true` for block math.
  ///   - fontSize: The point size of the math font.
  ///   - proposal: The size that the layout proposes.
  /// - Returns: The bounds. The bounds are zero when the engine cannot parse
  ///   the source.
  nonisolated static func bounds(
    of latex: String,
    display: Bool,
    fontSize: CGFloat,
    fitting proposal: ProposedViewSize = .unspecified
  ) -> Math.TypographicBounds {
    Math.typographicBounds(
      for: latex,
      fitting: proposal,
      font: Math.Font(name: fontName, size: fontSize),
      style: typesettingStyle(display: display)
    )
  }

  /// The engine style of a display style.
  ///
  /// - Parameter display: `true` for block math.
  /// - Returns: `.display` for block math, `.text` for inline math.
  nonisolated static func typesettingStyle(display: Bool) -> Math.TypesettingStyle {
    display ? .display : .text
  }

  public var body: some View {
    let baseSize = (font ?? .body).resolve(in: fontResolutionContext).pointSize
    if Self.canTypeset(latex, display: display) {
      Math(latex)
        .mathFont(Math.Font(name: Self.fontName, size: baseSize * Self.fontScale))
        .mathTypesettingStyle(Self.typesettingStyle(display: display))
        .mathRenderingMode(.monochrome)
        .mathAccessibility(latex: latex, display: display)
    } else {
      Text(verbatim: latex)
        .font(.system(size: baseSize, design: .monospaced))
        .fixedSize(horizontal: false, vertical: true)
        .mathAccessibility(latex: latex, display: display)
        .accessibilityValue(Text(verbatim: latex))
    }
  }
}

extension View {
  /// Makes this view the accessibility element of one math expression.
  ///
  /// The element has the identifier `math-inline` or `math-block`, the
  /// static text trait, and the LaTeX source as its label.
  ///
  /// - Parameters:
  ///   - latex: The LaTeX source, with no `$` delimiters.
  ///   - display: `true` for block math.
  /// - Returns: A view that is one accessibility element.
  func mathAccessibility(latex: String, display: Bool) -> some View {
    accessibilityElement(children: .ignore)
      .accessibilityAddTraits(.isStaticText)
      .accessibilityLabel(Text(verbatim: latex))
      .accessibilityIdentifier(MathView.identifier(display: display))
  }
}
