import SwiftUI

/// The shared shape of the two surfaces of the kit (D110 (e)).
///
/// ``SwiftUI/View/agentContentSurface(radius:)`` and
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

  func body(content: Content) -> some View {
    let shape = shape(in: theme)
    content
      .background(fill, in: shape)
      .overlay(shape.stroke(.separator))
  }

  /// The shape of the surface: ``AgentSurface/shape(radius:)`` with
  /// ``radius``, or ``AgentSurface/shape(for:)`` when ``radius`` is `nil`.
  ///
  /// - Parameter theme: The tokens that give the large radius.
  /// - Returns: The shape.
  func shape(in theme: AgentTheme) -> ConcentricRectangle {
    guard let radius else { return AgentSurface.shape(for: theme) }
    return AgentSurface.shape(radius: radius)
  }
}

/// The surface of a floating control: the Liquid Glass of the material level
/// of the theme (D110 (c)).
struct AgentFloatingGlass: ViewModifier {
  @Environment(\.agentTheme) private var theme

  func body(content: Content) -> some View {
    content.glassEffect(theme.materialLevel.glass, in: AgentSurface.shape(for: theme))
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

  /// Puts this floating control on the Liquid Glass of the kit (D110 (c)).
  ///
  /// The glass is ``AgentTheme/MaterialLevel/glass`` of the theme in the
  /// environment, in the shape of ``AgentSurface/shape(for:)``.
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
