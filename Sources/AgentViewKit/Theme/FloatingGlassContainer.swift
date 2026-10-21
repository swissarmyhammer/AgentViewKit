import SwiftUI

/// The one `GlassEffectContainer` of a group of floating controls (D110 (c)).
///
/// The container puts its content in a `GlassEffectContainer`, so that the
/// floating glass of the controls blends (``SwiftUI/View/agentFloatingGlass()``).
/// In a container, it makes no second container: its content then shares
/// the outer container. Thus ``AgentThreadView`` puts the scroll-to-bottom
/// pill and the composer in one container, and a ``PromptInputView`` in the
/// thread does not nest a container. A ``PromptInputView`` alone makes its
/// own container.
///
/// This is the only view of the kit that makes a `GlassEffectContainer`.
struct FloatingGlassContainer<Content: View>: View {
  /// The spacing at which the glass shapes of the content blend.
  let spacing: CGFloat

  /// The floating controls.
  let content: Content

  @Environment(\.floatingGlassContainerCount) private var containerCount

  /// Makes the container of a group of floating controls.
  ///
  /// - Parameters:
  ///   - spacing: The spacing at which the glass shapes of the content blend.
  ///     A container in a container uses the spacing of the outer container.
  ///   - content: The floating controls.
  init(spacing: CGFloat, @ViewBuilder content: () -> Content) {
    self.spacing = spacing
    self.content = content()
  }

  var body: some View {
    if containerCount > 0 {
      content
    } else {
      GlassEffectContainer(spacing: spacing) {
        content
      }
      .environment(\.floatingGlassContainerCount, containerCount + 1)
    }
  }
}

extension EnvironmentValues {
  /// The number of glass containers of floating controls that a
  /// ``FloatingGlassContainer`` made above this view.
  ///
  /// The value is zero out of a container, and one in a container. A
  /// container in a container makes no second container, so the value does
  /// not go above one.
  @Entry var floatingGlassContainerCount = 0
}
