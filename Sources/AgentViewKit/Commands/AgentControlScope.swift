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
/// editor, or else the EditorKit beacon of the scope, which then draws the
/// system focus ring over the control. `.scopeFocusRing(cornerRadius:)` gives
/// that ring the corners of the control (``AgentControlCorners``). A
/// `.focusEffectDisabled()` above the control turns the ring off. The leaf
/// landing also makes the accessibility hit test of the window over the
/// control answer the control, not a transcript row under the bar.
///
/// The beacon draws nothing else and takes no click, so the control keeps
/// its look and its own background: none. With no enclosing agent command
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

  /// The corners of the focus ring that the beacon of the scope draws.
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
      content
        .commandScope(segment: segment)
        .targetable(true)
        .scopeFocusRing(cornerRadius: corners.radius(in: editorStyle))
    } else {
      content
    }
  }
}

/// The corners of a bar control, which the focus ring of its scope
/// (``AgentControlScope``) follows.
enum AgentControlCorners: Equatable, Sendable {
  /// A capsule: the border shape of a glass button of a bar, a circle
  /// button, and the segmented permission-mode picker.
  case capsule

  /// The corners of a surface of the kit, such as the field of the composer
  /// around the editor.
  case surface(SurfaceCorners)

  /// The corner radius of these corners.
  ///
  /// The ring of a scope is the rounded rectangle that `RoundedRectangle`
  /// draws, which never rounds a corner past half a side. So the largest
  /// radius draws a capsule over a control of any size.
  ///
  /// - Parameter style: The shared style that gives the radius scale.
  /// - Returns: The largest radius for a capsule, or the radius of the
  ///   surface.
  func radius(in style: EditorStyle) -> CGFloat {
    switch self {
    case .capsule: .greatestFiniteMagnitude
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
  ///     scope follows. The default is a capsule, the shape of a glass
  ///     button of a bar.
  ///   - yieldsToHostScope: `true` to add no scope while a command scope of
  ///     the host, and not the agent command scope, encloses the control.
  /// - Returns: The control in its scope.
  func agentControlScope(
    _ identifier: String, corners: AgentControlCorners = .capsule, yieldsToHostScope: Bool = false
  ) -> some View {
    modifier(
      AgentControlScope(
        segment: AgentScopeKind.control(identifier), corners: corners, yieldsToHostScope: yieldsToHostScope))
  }
}
