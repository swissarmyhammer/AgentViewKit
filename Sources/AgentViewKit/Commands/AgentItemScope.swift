import EditorCommands
import EditorCommandsUI
import EditorStyle
import FoundationModelsACPClient
import SwiftUI

/// The focus scope of one item of a thread: a message row or a permission
/// request card (AVK-1), or a tool call card (AVK-7c).
///
/// The modifier adds the segment of the item to the path of the enclosing
/// ``AgentCommandScope``, gives the live object of the item as the subject of
/// that segment, and attaches the EditorKit context menu of that path. The
/// context menu shows the agent commands whose
/// ``AgentCommandVerb/itemKind`` is the kind of the item, and the commands
/// that a host registers for the item. A command of the context menu runs at
/// the path of the item, and reads the item with `@FromTarget`, so it acts on
/// that item. A command that is not available at the item does not show in
/// the context menu (``ContextMenuUnavailablePolicy/agentItem``).
///
/// The item scope is a target of the EditorKit navigation and jump (AVK-7d),
/// as each EditorKit command scope is. The scope has the area of the item, so
/// the `nav.*` commands of the host move between the items, and a jump label
/// shows on the item. The item has no focusable view of its own, so the
/// EditorKit beacon of the scope takes the focus that a move or a jump puts
/// on the item. The item then shows that focus by its
/// ``AgentItemFocusLook`` (EditorKit style.md, "Selection and focus"). An
/// item with a surface of its own shows the focus as the stronger accent
/// fill in its own shape, and the scope draws no ring. An item with no
/// surface, such as a message, keeps the focus ring of the scope around it,
/// in the theme accent (`\.themeAccent`), never in the `.tint` of a host
/// (EditorKit ^d5f8cwa), in the corners that the look names. By default the
/// look is that ring in the corners of a card of the kit
/// (``SurfaceCorners/card``). A `.focusEffectDisabled()` above the item
/// turns the ring off. When
/// `isTargetable` is `false`, for example on a deck card that does not show
/// whole, `.targetable(false)` removes the item from the jump labels and from
/// the navigation snapshot, so no jump and no move lands on it. The modifier
/// applies the same modifiers for each value of `isTargetable`, so a change
/// of the value keeps the identity and the state of the item.
///
/// An item is no single control, so the scope asks for no leaf landing
/// (`.targetable(_:asksForLeafLanding:)` with `false`). A landing on the item
/// gives the focus to the beacon of the scope, and not to a focusable view of
/// its content, such as the text of a message. The ring of the scope is then
/// the thin band of an item, and not the band of a control (EditorKit
/// `ScopeFocusRingWeight`).
///
/// With no enclosing agent command scope, the modifier does not change the
/// view.
struct AgentItemScope<Subject: Sendable>: ViewModifier {
  /// The segment of the item, such as `agentMessage:<rowKey>`.
  let segment: FocusSegment

  /// The live object of the item, such as its `TranscriptEntry`.
  let subject: Subject

  /// Tells if a jump or a `nav.*` move can land on the item.
  let isTargetable: Bool

  /// How the item shows the focus of its scope.
  let focusLook: AgentItemFocusLook

  @Environment(\.agentCommandSystem) private var system

  func body(content: Content) -> some View {
    if let system {
      content
        .modifier(AgentItemFocusFill(look: focusLook))
        .commandContextMenu(system, unavailable: .agentItem)
        .commandScope(segment: segment, subject: subject)
        .targetable(isTargetable ? .targetable : .untargetable, asksForLeafLanding: false)
        .modifier(AgentItemFocusRing(look: focusLook))
    } else {
      content
    }
  }
}

/// How an item of a thread shows the focus of its scope (EditorKit style.md,
/// "Selection and focus").
///
/// An item that the kit draws with a surface of its own shows the focus as a
/// fill in its own shape, never as an outline, and its scope draws no ring.
/// An item with no surface keeps the focus ring of its scope.
enum AgentItemFocusLook: Equatable, Sendable {
  /// The item has no surface of its own, such as a message, a tool call or
  /// the inspector: the scope draws its focus ring around the item, in these
  /// corners.
  case ring(SurfaceCorners)

  /// The item has a surface of its own and no selection, such as a card with
  /// an edge or a chip with a fill: a never-selected selectable surface in
  /// these corners, inside the scope, shows the focus as the stronger accent
  /// fill, and the scope draws no ring.
  case fill(SurfaceCorners)

  /// The content of the item draws its own selectable surface
  /// (`.selectableSurface`) inside the scope, such as a file view that
  /// selects its file for the inspector. That surface shows the focus, so the
  /// scope adds no fill and no ring.
  case contentSurface
}

/// The fill of an ``AgentItemFocusLook/fill(_:)`` item: a selectable surface
/// that is never selected, so it shows only the focus of the scope. It
/// stands inside the scope, around the content of the item, so a base fill
/// of the content reads `\.isItemStateFillShown` and steps aside.
private struct AgentItemFocusFill: ViewModifier {
  /// How the item shows the focus of its scope.
  let look: AgentItemFocusLook

  func body(content: Content) -> some View {
    switch look {
    case .fill(let corners): content.selectableSurface(false, corners: corners)
    case .ring, .contentSurface: content
    }
  }
}

/// The focus ring of an ``AgentItemFocusLook/ring(_:)`` item: the corners of
/// the ring that the scope draws around an item with no surface.
private struct AgentItemFocusRing: ViewModifier {
  /// How the item shows the focus of its scope.
  let look: AgentItemFocusLook

  @Environment(\.editorStyle) private var editorStyle

  func body(content: Content) -> some View {
    switch look {
    case .ring(let corners): content.scopeFocusRing(cornerRadius: corners.radius(in: editorStyle))
    case .fill, .contentSurface: content
    }
  }
}

extension View {
  /// Puts this view in the focus scope of one item of a thread, with the
  /// context menu of that scope.
  ///
  /// - Parameters:
  ///   - segment: The segment of the item.
  ///   - subject: The live object of the item. A command reads it with
  ///     `@FromTarget(kind: segment.kind)`.
  ///   - isTargetable: `false` to keep each jump and each `nav.*` move off
  ///     the item, for example on a deck card that does not show whole.
  ///   - focusLook: How the item shows the focus of its scope. The default
  ///     is the focus ring of the scope in the corners of a card, for an item
  ///     with no surface of its own.
  /// - Returns: A view in the scope of the item.
  func agentItemScope(
    _ segment: FocusSegment, subject: some Sendable, isTargetable: Bool = true,
    focusLook: AgentItemFocusLook = .ring(.card)
  ) -> some View {
    modifier(
      AgentItemScope(segment: segment, subject: subject, isTargetable: isTargetable, focusLook: focusLook))
  }
}

extension ContextMenuUnavailablePolicy {
  /// The policy of the context menu of an item of a thread
  /// (``AgentItemScope``): a command that is not available at the item does
  /// not show in the context menu (AVK-9). The main menu still shows that
  /// command, disabled.
  static let agentItem: ContextMenuUnavailablePolicy = .hide
}

extension AgentCommandTarget {
  /// The Markdown of the message that a ``AgentCommandVerb/copyMessage``
  /// payload names: the content form of `ThreadExporter.markdown(for:)`, as
  /// the Copy button of ``MessageActions`` writes it.
  ///
  /// - Parameters:
  ///   - payload: The payload of the dispatch, or `nil`.
  ///   - session: The session model of the scope.
  /// - Returns: The Markdown, or `nil` when the payload names no message
  ///   entry of the transcript.
  func messageMarkdown(payload: CommandPayload?, in session: SessionModel) -> String? {
    let transcript = session.transcript
    guard let key = AgentCommandPayload.string(AgentCommandPayload.messageKey, in: payload),
      let position = transcript.position(ofRowKey: key)
    else { return nil }
    switch transcript[position] {
    case .userMessage(let entry): return ThreadExporter.markdown(for: entry.content)
    case .agentMessage(let entry): return ThreadExporter.markdown(for: entry.content)
    default: return nil
    }
  }
}

extension EnvironmentValues {
  /// The command system of the nearest ``AgentCommandScope``, or `nil`.
  ///
  /// This is the ambient system, or the private system of the scope when no
  /// ancestor installs one. ``AgentItemScope`` builds its context menu from
  /// it.
  @Entry var agentCommandSystem: CommandSystem? = nil
}
