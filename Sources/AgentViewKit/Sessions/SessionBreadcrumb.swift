import EditorStyle
import EditorSwiftUI
import EditorTheme
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// One part of the row of crumbs: a session, or the dropdown that holds the
/// middle crumbs that do not fit.
enum BreadcrumbSegment: Identifiable {
  /// The crumb of one session.
  case crumb(SessionModel)

  /// The sessions that the row collapsed into one "..." dropdown.
  case overflow([SessionModel])

  var id: String {
    switch self {
    case .crumb(let session): session.sessionId.rawValue
    case .overflow(let sessions): "overflow-" + (sessions.first?.sessionId.rawValue ?? "")
    }
  }

  /// The fewest sessions of a path that have a middle crumb to collapse: the
  /// first and the last crumb stay, so a path needs one more session.
  static let fewestToCollapse = 3

  /// The segments of a path of sessions.
  ///
  /// The width of the bar decides, not the number of sessions: the row first
  /// tries the full path, and then the collapsed one. The collapsed path keeps
  /// the first and the last crumb, and holds each crumb in between in one
  /// dropdown. A path with no crumb in between has nothing to collapse.
  ///
  /// - Parameters:
  ///   - path: The sessions from the root to the shown session.
  ///   - collapsed: Whether the middle crumbs collapse.
  /// - Returns: The segments, in order.
  static func segments(of path: [SessionModel], collapsed: Bool) -> [BreadcrumbSegment] {
    guard collapsed, path.count >= fewestToCollapse else { return path.map(BreadcrumbSegment.crumb) }
    return [.crumb(path[0]), .overflow(Array(path[1..<(path.count - 1)])), .crumb(path[path.count - 1])]
  }
}

/// The crumbs of the sessions after the agent in the header: one crumb for
/// each session on the path from the root to the shown session.
///
/// Each crumb is a dropdown (a menu) with the siblings at its level: the
/// sessions with the same parent. Each choice shows the title, the work
/// state and the count of the open questions. A crumb shows a mark when
/// `needsAttention` is true, so a question of a session deep in the tree
/// shows on each crumb above it. A choice gives the id of the session to the
/// host through `select`; the view keeps no state of the choice.
struct SessionBreadcrumb: View {
  /// The accessibility identifier of the crumb of a session.
  ///
  /// - Parameter id: The id of the session.
  /// - Returns: The identifier.
  static func crumbIdentifier(for id: SessionId) -> String { "session-crumb-" + id.rawValue }

  /// The accessibility identifier of the dropdown of the collapsed crumbs.
  static let overflowIdentifier = "session-crumb-overflow"

  /// The sessions from the root to the shown session.
  let path: [SessionModel]

  /// Whether the middle crumbs collapse.
  let collapsed: Bool

  /// Called with the id of the session that the user chooses.
  let select: (SessionId) -> Void

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme

  var body: some View {
    ForEach(BreadcrumbSegment.segments(of: path, collapsed: collapsed)) { segment in
      DecorativeSymbolImage(name: SharedSymbol.disclosure)
        .imageScale(.small)
      switch segment {
      case .crumb(let session): crumb(session)
      case .overflow(let sessions): overflow(sessions)
      }
    }
  }

  /// The label of a crumb: the title, and the mark when the session needs
  /// the user.
  private func crumbLabel(_ session: SessionModel) -> some View {
    HStack(spacing: editorStyle.spacing.xs) {
      Text(session.displayTitle)
        .font(editorTheme.font(for: .ui, style: .headline))
        .lineLimit(1)
      if session.needsAttention {
        DecorativeSymbolImage(name: SharedSymbol.warning)
          .imageScale(.small)
          .foregroundStyle(editorTheme.severityWarning)
      }
    }
  }

  /// The dropdown of the siblings of a session.
  private func crumb(_ session: SessionModel) -> some View {
    dropdown(
      choices: session.siblings, label: { crumbLabel(session) },
      accessibilityLabel: Self.accessibilityLabel(for: session),
      identifier: Self.crumbIdentifier(for: session.sessionId))
  }

  /// The "..." dropdown of the middle crumbs that do not fit.
  private func overflow(_ sessions: [SessionModel]) -> some View {
    dropdown(
      choices: sessions.map(\.pathEntry),
      label: { Text(verbatim: "…").font(editorTheme.font(for: .ui, style: .headline)) },
      accessibilityLabel: String(localized: "More of the path", bundle: .module),
      identifier: Self.overflowIdentifier)
  }

  /// One dropdown: a borderless menu with a choice for each session entry.
  ///
  /// - Parameters:
  ///   - choices: The sessions to choose from.
  ///   - label: The label of the menu.
  ///   - accessibilityLabel: The VoiceOver label of the menu.
  ///   - identifier: The accessibility identifier of the menu.
  private func dropdown<Label: View>(
    choices: [SessionPathEntry], @ViewBuilder label: () -> Label, accessibilityLabel: String, identifier: String
  ) -> some View {
    Menu {
      ForEach(choices) { entry in
        Button(SessionStateText.choiceLabel(for: entry)) { select(entry.sessionId) }
      }
    } label: {
      label()
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .fixedSize()
    .accessibilityLabel(accessibilityLabel)
    .accessibilityIdentifier(identifier)
  }

  /// The VoiceOver label of a crumb: the title, the state, and a note when
  /// the session needs the user.
  ///
  /// - Parameter session: The session of the crumb.
  /// - Returns: Text such as "Linter, Waiting for you, needs your attention".
  static func accessibilityLabel(for session: SessionModel) -> String {
    var parts = [session.displayTitle, SessionStateText.text(for: session.workState)]
    if session.needsAttention { parts.append(String(localized: "needs your attention", bundle: .module)) }
    return parts.joined(separator: ", ")
  }
}
