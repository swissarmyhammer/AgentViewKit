import SwiftUI

/// The shared shape of the two surfaces of the kit (D110 (e)).
///
/// ``SwiftUI/View/agentContentSurface()`` and
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
    ConcentricRectangle(corners: .concentric(minimum: .fixed(theme.radii.l)), isUniform: true)
  }
}

/// The surface of content: a standard opaque background with a separator
/// stroke, and no glass (D110 (b)).
struct AgentContentSurface: ViewModifier {
  @Environment(\.agentTheme) private var theme

  func body(content: Content) -> some View {
    let shape = AgentSurface.shape(for: theme)
    content
      .background(.background.secondary, in: shape)
      .overlay(shape.stroke(.separator))
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
  /// with a `.separator` stroke, in the shape of ``AgentSurface/shape(for:)``.
  /// It has no glass. Use it for content: the transcript and its messages,
  /// tool call cards, lists and blocks of code. Use
  /// ``agentFloatingGlass()`` for a floating control.
  ///
  /// - Returns: The content on the surface.
  func agentContentSurface() -> some View {
    modifier(AgentContentSurface())
  }

  /// Puts this floating control on the Liquid Glass of the kit (D110 (c)).
  ///
  /// The glass is ``AgentTheme/MaterialLevel/glass`` of the theme in the
  /// environment, in the shape of ``AgentSurface/shape(for:)``.
  ///
  /// Use it only on a floating control, for example the composer bar or a
  /// floating action button. Use it only inside a `GlassEffectContainer`.
  /// Never put it on top of other glass. Never use it for content: use
  /// ``agentContentSurface()`` for content.
  ///
  /// - Returns: The control on the glass.
  func agentFloatingGlass() -> some View {
    modifier(AgentFloatingGlass())
  }
}
