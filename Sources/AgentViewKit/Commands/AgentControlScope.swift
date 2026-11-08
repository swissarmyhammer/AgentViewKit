import EditorCommands
import EditorCommandsUI
import EditorStyle
import SwiftUI

/// The focus scope of one control in a bar of a thread: Send, Stop, the
/// permission-mode picker, a sign-in button, a banner button, the composer
/// editor (KanbanViewKit D109 (e), "the jump is necessary").
///
/// The modifier adds the segment `agentControl:<identifier>` to the path of
/// the enclosing ``AgentCommandScope`` (``AgentScopeKind/control``). The scope
/// is a target of the EditorKit jump and navigation, as each EditorKit command
/// scope is: a jump session shows a label on the control, and the `nav.*`
/// commands of the host move to it. The scope gives no subject, and it adds
/// no context menu, so a command at its path acts on the thread.
///
/// The scope asks for the EditorKit leaf landing (`.targetable(true)`), and
/// EditorKit decides what a landed jump does. A landing on a button presses
/// it through its own accessibility press action, as a click does, so a
/// disabled button takes nothing, and a disabled control gets no jump label
/// and no nav stop. A landing on the segmented permission-mode picker only
/// focuses it: the arrow keys and Space then change its segment. A landing
/// on content that is no leaf control, such as the composer editor, focuses
/// the scope: a focusable view of the content, such as the text view of the
/// editor, or else the EditorKit beacon of the scope, and the scope then
/// draws its focus ring around the control, in the theme accent
/// (`\.themeAccent`), never in the `.tint` of a host (EditorKit ^d5f8cwa).
/// The ring has the corners of the control (``AgentControlCorners``): an
/// EditorKit button tells the scope the shape of its bezel, and
/// `.scopeFocusRing(cornerRadius:)` gives the ring the corners of a surface
/// of the kit. A `.focusEffectDisabled()` above the control turns the ring
/// off. The leaf landing also makes the accessibility hit test of the window
/// over the control answer the control, not a transcript row under the bar.
///
/// The beacon draws nothing and takes no click, and the scope draws nothing
/// but its focus ring, so the control keeps its look and its own background:
/// none. With no enclosing agent command
/// scope, the modifier does not change the view.
///
/// A control that `yieldsToHostScope` takes its scope only while the
/// nearest enclosing scope is the agent command scope itself. A host that
/// puts the control in a command scope of its own, such as a scope around
/// the composer, makes that scope the jump target of the control: a landing
/// on it goes into the control, and does not stop at an inner scope.
struct AgentControlScope: ViewModifier {
  /// The segment of the control, such as `agentControl:prompt-submit`.
  let segment: FocusSegment

  /// The corners of the focus ring that the scope draws.
  let corners: AgentControlCorners

  /// Whether a command scope of the host around the control takes the
  /// place of the scope of the control.
  let yieldsToHostScope: Bool

  @Environment(\.agentCommandSystem) private var system
  @Environment(\.agentCommandScopeSegment) private var agentSegment
  @Environment(\.commandScopePath) private var enclosingPath
  @Environment(\.editorStyle) private var editorStyle

  /// Whether the control takes its own scope: in an agent command scope, and
  /// not in a scope of the host when the control yields to it.
  private var isScoped: Bool {
    guard system != nil else { return false }
    return !yieldsToHostScope || enclosingPath?.segments.last == agentSegment
  }

  func body(content: Content) -> some View {
    if isScoped {
      withRingCorners(content.commandScope(segment: segment).targetable(true))
    } else {
      content
    }
  }

  /// `scope` with the request for the corners of its ring, when the corners
  /// ask for a radius.
  ///
  /// - Parameter scope: The control in its scope.
  /// - Returns: The scope, with `.scopeFocusRing(cornerRadius:)` for the
  ///   corners of a surface, or with no request for the shape of the
  ///   control.
  @ViewBuilder
  private func withRingCorners(_ scope: some View) -> some View {
    if let radius = corners.radius(in: editorStyle) {
      scope.scopeFocusRing(cornerRadius: radius)
    } else {
      scope
    }
  }
}

/// The corners of a bar control, which the focus ring of its scope
/// (``AgentControlScope``) follows.
enum AgentControlCorners: Equatable, Sendable {
  /// The shape that the control tells its scope: the bezel of an EditorKit
  /// button, such as the capsule of a floating glass action, the circle of a
  /// round button, or the continuous corners of a button of a bar. A control
  /// that tells no shape, such as the segmented permission-mode picker,
  /// takes a capsule, the EditorKit ring of a leaf control scope.
  case control

  /// The corners of a surface of the kit, such as the field of the composer
  /// around the editor.
  case surface(SurfaceCorners)

  /// The corner radius that the scope asks for.
  ///
  /// - Parameter style: The shared style that gives the radius scale.
  /// - Returns: The radius of the surface, or `nil` for the shape of the
  ///   control, so the scope asks for no corners.
  func radius(in style: EditorStyle) -> CGFloat? {
    switch self {
    case .control: nil
    case .surface(let corners): corners.radius(in: style)
    }
  }
}

extension View {
  /// Puts this control of a bar of a thread in its own focus scope, so that
  /// it is a target of the EditorKit jump and navigation.
  ///
  /// - Parameters:
  ///   - identifier: The accessibility identifier of the control, such as
  ///     `prompt-submit`. It is the id of the segment of the scope.
  ///   - corners: The corners of the control, which the focus ring of the
  ///     scope follows. The default is the shape that the control tells the
  ///     scope, such as the bezel of an EditorKit button.
  ///   - yieldsToHostScope: `true` to add no scope while a command scope of
  ///     the host, and not the agent command scope, encloses the control.
  /// - Returns: The control in its scope.
  func agentControlScope(
    _ identifier: String, corners: AgentControlCorners = .control, yieldsToHostScope: Bool = false
  ) -> some View {
    modifier(
      AgentControlScope(
        segment: AgentScopeKind.control(identifier), corners: corners, yieldsToHostScope: yieldsToHostScope))
  }
}
