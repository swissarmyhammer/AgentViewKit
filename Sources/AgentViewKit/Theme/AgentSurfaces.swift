import SwiftUI

/// The shared shape of the floating glass and the content edge of the kit
/// (D110 (e)).
///
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
///
/// A glass with an ``id`` puts the id in the glass namespace of its
/// ``FloatingGlassContainer``, so that it morphs (D113 answer 2). The id goes
/// through ``AgentGlassID``.
struct AgentFloatingGlass: ViewModifier {
  /// The identity of the glass in the glass namespace of the container, or
  /// `nil` for a glass that does not morph.
  let id: FloatingGlassID?

  @Environment(\.agentTheme) private var theme

  func body(content: Content) -> some View {
    content
      .glassEffect(.regular, in: AgentSurface.shape(for: theme))
      .modifier(AgentGlassID(id: id))
  }
}

/// The identity of the glass in a view, in the glass namespace of its
/// ``FloatingGlassContainer`` (D113 answer 2).
///
/// The modifier applies `glassEffectID(_:in:)` to the view. The id applies to
/// each Liquid Glass effect in the view: the glass of
/// ``AgentFloatingGlass``, or the glass of a `.glass` button style. This is
/// the only place of the kit that applies `glassEffectID(_:in:)`.
///
/// Out of a container, there is no namespace, and the modifier does not
/// change the view. With no ``id``, the modifier does not change the view.
struct AgentGlassID: ViewModifier {
  /// The identity of the glass in the glass namespace of the container, or
  /// `nil` for a glass that does not morph.
  let id: FloatingGlassID?

  @Environment(\.floatingGlassNamespace) private var namespace

  func body(content: Content) -> some View {
    if let id, let namespace {
      content.glassEffectID(id, in: namespace)
    } else {
      content
    }
  }
}

extension View {
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
  /// ``agentContentEdge(radius:)`` for content.
  ///
  /// This glass has no id, so it does not morph. Use
  /// ``agentFloatingGlass(id:)`` for a glass that shows or hides next to
  /// another glass of the same container.
  ///
  /// - Returns: The control on the glass.
  func agentFloatingGlass() -> some View {
    modifier(AgentFloatingGlass(id: nil))
  }

  /// Puts this floating control on the Liquid Glass of the kit, with an id
  /// in the glass namespace of its container (D113 answer 2).
  ///
  /// The glass is the glass of ``agentFloatingGlass()``. Then the modifier
  /// applies `glassEffectID(_:in:)` with `id`, in the namespace of the
  /// ``FloatingGlassContainer`` above the control
  /// (``SwiftUI/EnvironmentValues/floatingGlassNamespace``). Out of a
  /// container, there is no namespace, and the glass has no id.
  ///
  /// When one glass shows or hides next to another glass of the same
  /// container, give both an id. Then the change morphs, and does not jump.
  ///
  /// Reduce Motion: the modifier adds no animation. The morph runs only in the
  /// animation of the state change that shows or hides the glass. The kit
  /// shows and hides its glass with no `withAnimation`, so no morph runs. A
  /// host that animates the change reads `accessibilityReduceMotion`, and
  /// gives `nil` as the animation while Reduce Motion is on (plan.md §6).
  ///
  /// - Parameter id: The identity of the glass in the namespace.
  /// - Returns: The control on the glass.
  func agentFloatingGlass(id: FloatingGlassID) -> some View {
    modifier(AgentFloatingGlass(id: id))
  }

  /// Puts the glass of this view in the glass namespace of its container,
  /// with an id (D113 answer 2).
  ///
  /// Use it on a glass button, a button with the `.glass` button style, that
  /// shows or hides next to another glass of the same container. For
  /// example, the scroll-to-bottom pill shows and hides above the composer.
  /// The id applies to the glass of the button style. The modifier makes no
  /// glass of its own.
  ///
  /// The modifier applies `glassEffectID(_:in:)` with `id`, in the namespace
  /// of the ``FloatingGlassContainer`` above the view
  /// (``SwiftUI/EnvironmentValues/floatingGlassNamespace``). Out of a
  /// container, there is no namespace, and the view has no id. For the
  /// floating glass of the kit, use ``agentFloatingGlass(id:)``.
  ///
  /// Reduce Motion: the modifier adds no animation, the same as
  /// ``agentFloatingGlass(id:)``.
  ///
  /// - Parameter id: The identity of the glass in the namespace.
  /// - Returns: The view with its glass in the namespace.
  func agentGlassID(_ id: FloatingGlassID) -> some View {
    modifier(AgentGlassID(id: id))
  }
}
