import SwiftUI

/// The shared shape of the two surfaces and the content edge of the kit
/// (D110 (e)).
///
/// ``SwiftUI/View/agentContentSurface(radius:)``,
/// ``SwiftUI/View/agentContentEdge(radius:)`` (D113) and
/// ``SwiftUI/View/agentFloatingGlass()`` use this shape. Thus each surface
/// has the same corners, and one place changes them.
enum AgentSurface {
  /// The shape of a surface: a `ConcentricRectangle` with the `.concentric`
  /// corner style.
  ///
  /// A concentric corner follows the corner of the container shape that
  /// holds the surface. When no container gives a corner, the corner uses
  /// the large radius of `theme` (``AgentTheme/Radii/l``). The large radius
  /// is also the smallest corner that a container can give. The four corners
  /// are uniform, so that each surface in a list has the same corners.
  ///
  /// - Parameter theme: The tokens that give the large radius.
  /// - Returns: The shape.
  static func shape(for theme: AgentTheme) -> ConcentricRectangle {
    shape(radius: theme.radii.l)
  }

  /// A shape with concentric corners and a radius token as the smallest
  /// corner (D110 (e)).
  ///
  /// Use it for each rounded shape of the kit in place of a
  /// `RoundedRectangle` with a fixed corner radius. A concentric corner
  /// follows the corner of the container shape that holds the shape. When no
  /// container gives a corner, the corner uses `radius`. The corner is never
  /// smaller than `radius`. The four corners are uniform.
  ///
  /// The shape is not an `InsettableShape`, so it has no `strokeBorder`. Draw
  /// its border with `stroke`.
  ///
  /// - Parameter radius: The radius token, for example
  ///   ``AgentTheme/Radii/s``. It is the smallest corner and the corner when
  ///   no container gives one.
  /// - Returns: The shape.
  static func shape(radius: CGFloat) -> ConcentricRectangle {
    ConcentricRectangle(corners: .concentric(minimum: .fixed(radius)), isUniform: true)
  }
}

/// The surface of content: a standard opaque background with a separator
/// stroke, and no glass (D110 (b)).
struct AgentContentSurface: ViewModifier {
  /// The fill of the surface.
  let fill: AnyShapeStyle

  /// The radius token of the corners, for example ``AgentTheme/Radii/m``.
  /// When it is `nil`, the corners use the large radius of the theme.
  let radius: CGFloat?

  @Environment(\.agentTheme) private var theme

  /// The edge of the surface: the `.separator` stroke in the shape of the
  /// surface.
  private var edge: AgentContentEdge { AgentContentEdge(radius: radius) }

  func body(content: Content) -> some View {
    content
      .background(fill, in: shape(in: theme))
      .modifier(edge)
  }

  /// The shape of the surface: the shape of ``AgentContentEdge`` with the
  /// same ``radius``.
  ///
  /// - Parameter theme: The tokens that give the large radius.
  /// - Returns: The shape.
  func shape(in theme: AgentTheme) -> ConcentricRectangle {
    edge.shape(in: theme)
  }
}

/// The edge of content: a thin `.separator` stroke in the shape of
/// ``AgentSurface``, with no fill (D113, TestudoApp `features/style.md`).
///
/// A card or a panel in content has no fill. Only this stroke marks its edge.
struct AgentContentEdge: ViewModifier {
  /// The radius token of the corners, for example ``AgentTheme/Radii/m``.
  /// When it is `nil`, the corners use the large radius of the theme.
  let radius: CGFloat?

  @Environment(\.agentTheme) private var theme

  func body(content: Content) -> some View {
    content.overlay(shape(in: theme).stroke(.separator))
  }

  /// The shape of the edge: ``AgentSurface/shape(radius:)`` with
  /// ``radius``, or ``AgentSurface/shape(for:)`` when ``radius`` is `nil`.
  ///
  /// - Parameter theme: The tokens that give the large radius.
  /// - Returns: The shape.
  func shape(in theme: AgentTheme) -> ConcentricRectangle {
    guard let radius else { return AgentSurface.shape(for: theme) }
    return AgentSurface.shape(radius: radius)
  }
}

/// The surface of a floating control: `.regular` Liquid Glass (D110 (c),
/// D113).
///
/// The glass is always `.regular`. The Clear look and the Tinted look are
/// system settings, and the system applies them to `.regular` glass. Thus a
/// theme does not select the glass variant.
struct AgentFloatingGlass: ViewModifier {
  @Environment(\.agentTheme) private var theme

  func body(content: Content) -> some View {
    content.glassEffect(.regular, in: AgentSurface.shape(for: theme))
  }
}

extension View {
  /// Puts this content on the content surface of the kit (D110 (b)).
  ///
  /// The surface is a standard opaque background (`.background.secondary`)
  /// with a `.separator` stroke, in the shape of ``AgentSurface/shape(for:)``,
  /// or of ``AgentSurface/shape(radius:)`` when `radius` has a value. It has
  /// no glass. Use it for content: the transcript and its messages, tool call
  /// cards, lists and blocks of code. Use ``agentFloatingGlass()`` for a
  /// floating control.
  ///
  /// - Parameter radius: The radius token of the corners, for example
  ///   ``AgentTheme/Radii/m``. When it is `nil`, the corners use the large
  ///   radius of the theme.
  /// - Returns: The content on the surface.
  func agentContentSurface(radius: CGFloat? = nil) -> some View {
    agentContentSurface(.background.secondary, radius: radius)
  }

  /// Puts this content on the content surface of the kit, with a fill that
  /// is not the standard background (D110 (b)).
  ///
  /// Use it when the content has its own standard background, for example
  /// the background of the editor theme for a block of code. The surface has
  /// the `.separator` stroke and the shape of
  /// ``agentContentSurface(radius:)``. It has no glass.
  ///
  /// - Parameters:
  ///   - fill: The fill of the surface.
  ///   - radius: The radius token of the corners, for example
  ///     ``AgentTheme/Radii/m``. When it is `nil`, the corners use the large
  ///     radius of the theme.
  /// - Returns: The content on the surface.
  func agentContentSurface(_ fill: some ShapeStyle, radius: CGFloat? = nil) -> some View {
    modifier(AgentContentSurface(fill: AnyShapeStyle(fill), radius: radius))
  }

  /// Marks the edge of this content with a thin `.separator` stroke, and
  /// gives it no fill (D113).
  ///
  /// TestudoApp `features/style.md` ("How the steps apply") gives the rule: a
  /// card or a panel in content has no fill. A `.separator` stroke in a
  /// `ConcentricRectangle` marks its edge. The stroke has the shape of
  /// ``AgentSurface/shape(for:)``, or of ``AgentSurface/shape(radius:)`` when
  /// `radius` has a value. The content behind the card shows through it.
  ///
  /// If a group needs more than this edge, use a system container: a
  /// `GroupBox`, or a `Form` with the grouped style. Never add a custom fill.
  ///
  /// - Parameter radius: The radius token of the corners, for example
  ///   ``AgentTheme/Radii/m``. When it is `nil`, the corners use the large
  ///   radius of the theme.
  /// - Returns: The content with the edge.
  func agentContentEdge(radius: CGFloat? = nil) -> some View {
    modifier(AgentContentEdge(radius: radius))
  }

  /// Puts this floating control on the Liquid Glass of the kit (D110 (c)).
  ///
  /// The glass is always `.regular` glass, in the shape of
  /// ``AgentSurface/shape(for:)``. The system applies the Clear look and the
  /// Tinted look to `.regular` glass when the user selects them in System
  /// Settings. No value of the theme changes the glass, and the glass has no
  /// tint (D113).
  ///
  /// Use it only on a floating control, for example the composer bar or a
  /// floating action button. Use it only inside a `GlassEffectContainer`.
  /// Never put it on top of other glass. Never use it for content: use
  /// ``agentContentSurface(radius:)`` for content.
  ///
  /// - Returns: The control on the glass.
  func agentFloatingGlass() -> some View {
    modifier(AgentFloatingGlass())
  }
}
