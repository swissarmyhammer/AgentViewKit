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
/// The container also gives one glass namespace to its content
/// (``SwiftUI/EnvironmentValues/floatingGlassNamespace``). A glass with a
/// ``FloatingGlassID`` puts its id in this namespace
/// (``SwiftUI/View/agentFloatingGlass(id:)``). Thus a glass that shows or hides
/// next to another glass of the group morphs, and does not jump (D113
/// answer 2). A container in a container keeps the namespace of the outer
/// container, so that each glass of the group has its id in one namespace.
///
/// This is the only view of the kit that makes a `GlassEffectContainer`.
struct FloatingGlassContainer<Content: View>: View {
  /// The spacing at which the glass shapes of the content blend.
  let spacing: CGFloat

  /// The floating controls.
  let content: Content

  @Environment(\.floatingGlassContainerCount) private var containerCount

  /// The glass namespace that the container gives to its content.
  @Namespace private var namespace

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
      .environment(\.floatingGlassNamespace, namespace)
    }
  }
}

/// The identity of a floating glass in the glass namespace of its
/// ``FloatingGlassContainer`` (D113 answer 2).
///
/// Each glass that shows or hides next to another glass of the same container
/// has an id. The glass next to it has an id too. Then the change morphs, and
/// does not jump.
nonisolated enum FloatingGlassID: Hashable, Sendable {
  /// The field of the composer: the attachment chips and the editor
  /// (`PromptFieldSurface`).
  case composerField

  /// The menu of the editor, which shows and hides above the field of the
  /// composer (``PromptEditorMenuLayer``).
  case editorMenu
}

extension EnvironmentValues {
  /// The number of glass containers of floating controls that a
  /// ``FloatingGlassContainer`` made above this view.
  ///
  /// The value is zero out of a container, and one in a container. A
  /// container in a container makes no second container, so the value does
  /// not go above one.
  @Entry var floatingGlassContainerCount = 0

  /// The glass namespace of the ``FloatingGlassContainer`` above this view,
  /// or `nil` out of a container.
  ///
  /// A container in a container keeps the namespace of the outer container.
  @Entry var floatingGlassNamespace: Namespace.ID? = nil
}
