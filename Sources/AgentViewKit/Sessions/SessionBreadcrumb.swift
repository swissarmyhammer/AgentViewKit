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
///
/// When the host gives a title, the first crumb shows it in place of the
/// title of its session, such as the title of a tab (D142).
///
/// Each crumb can truncate, so the row never sets the least width of the
/// pane that holds the header: a long title, or a session id with no title,
/// shows in part.
struct SessionBreadcrumb: View {
  /// The accessibility identifier of the crumb of a session.
  ///
  /// - Parameter id: The id of the session.
  /// - Returns: The identifier.
  static func crumbIdentifier(for id: SessionId) -> String { "session-crumb-" + id.rawValue }

  /// The accessibility identifier of the dropdown of the collapsed crumbs.
  static let overflowIdentifier = "session-crumb-overflow"

  /// The accessibility identifier of the dropdown of the children of the
  /// shown session.
  static let childrenIdentifier = "session-crumb-children"

  /// The sessions from the root to the shown session.
  let path: [SessionModel]

  /// The title that the host gives to the first crumb, or `nil` for the
  /// title of its session.
  let rootTitle: String?

  /// Whether the middle crumbs collapse.
  let collapsed: Bool

  /// The shown session: the last session of ``path``.
  private var shown: SessionModel? { path.last }

  /// Called with the id of the session that the user chooses.
  let select: (SessionId) -> Void

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme
  @Environment(\.locale) private var locale

  var body: some View {
    ForEach(BreadcrumbSegment.segments(of: path, collapsed: collapsed)) { segment in
      EditorSymbolImage(.action(.disclosure))
        .imageScale(.small)
        .accessibilityHidden(true)
      switch segment {
      case .crumb(let session): crumb(session)
      case .overflow(let sessions): overflow(sessions)
      }
    }
    if let shown, shown.children.contains(where: { !$0.isClosed }) {
      EditorSymbolImage(.action(.disclosure))
        .imageScale(.small)
        .accessibilityHidden(true)
      childrenDropdown(of: shown)
    }
  }

  /// The label of a crumb: the title, and the mark when the session needs
  /// the user.
  private func crumbLabel(_ session: SessionModel) -> some View {
    titleLabel(title(of: session), needsAttention: session.needsAttention)
  }

  /// The title of the crumb of a session: the title of the host for the
  /// first crumb, and the title of the session for the others.
  private func title(of session: SessionModel) -> String {
    Self.title(of: session, in: path, rootTitle: rootTitle)
  }

  /// The title of the crumb of a session of a path.
  ///
  /// - Parameters:
  ///   - session: The session of the crumb.
  ///   - path: The sessions from the root to the shown session.
  ///   - rootTitle: The title that the host gives to the first crumb, or
  ///     `nil`.
  /// - Returns: The host title for the first crumb, when there is one, and
  ///   the display title of the session otherwise.
  static func title(of session: SessionModel, in path: [SessionModel], rootTitle: String?) -> String {
    guard let rootTitle, session.sessionId == path.first?.sessionId else { return session.displayTitle }
    return rootTitle
  }

  /// The label of a dropdown: a headline title, and the warning mark when
  /// something below needs the user.
  private func titleLabel(_ text: String, needsAttention: Bool) -> some View {
    HStack(spacing: editorStyle.spacing.xs) {
      Text(text)
        .font(editorTheme.font(for: .ui, style: .headline))
        .lineLimit(1)
        .truncationMode(.middle)
      if needsAttention {
        EditorSymbolImage(.severity(.warning))
          .imageScale(.small)
          .accessibilityHidden(true)
      }
    }
  }

  /// The dropdown of the siblings of a session.
  private func crumb(_ session: SessionModel) -> some View {
    dropdown(
      choices: session.siblingsIncludingSelf, current: session.sessionId, label: { crumbLabel(session) },
      accessibilityLabel: Self.accessibilityLabel(for: session, title: title(of: session), locale: locale),
      identifier: Self.crumbIdentifier(for: session.sessionId)
    )
    .modifier(crumbScope(session.sessionId))
  }

  /// The "..." dropdown of the middle crumbs that do not fit.
  private func overflow(_ sessions: [SessionModel]) -> some View {
    dropdown(
      choices: sessions.map(\.pathEntry), current: shown?.sessionId,
      label: { Text(verbatim: "…").font(editorTheme.font(for: .ui, style: .headline)) },
      accessibilityLabel: String(localized: "More of the path", bundle: .module),
      identifier: Self.overflowIdentifier)
  }

  /// One dropdown of a crumb: a borderless menu with a choice for each
  /// session entry, whose label is the title of the crumb, which truncates.
  ///
  /// - Parameters:
  ///   - choices: The sessions to choose from.
  ///   - current: The id of the shown session, or `nil`.
  ///   - label: The label of the menu.
  ///   - accessibilityLabel: The VoiceOver label of the menu.
  ///   - identifier: The accessibility identifier of the menu.
  private func dropdown<Label: View>(
    choices: [SessionPathEntry], current: SessionId?, @ViewBuilder label: () -> Label,
    accessibilityLabel: String, identifier: String
  ) -> some View {
    Menu {
      choiceRows(choices, current: current)
    } label: {
      label()
    }
    .accessibilityHint(String(localized: "Shows the sessions at this level.", bundle: .module))
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .fixedSize(horizontal: false, vertical: true)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityIdentifier(identifier)
  }

  /// The rows of a dropdown: a choice for each session entry, then the note
  /// of the entries that the menu does not list.
  ///
  /// - Parameters:
  ///   - choices: The sessions to choose from.
  ///   - current: The id of the shown session, or `nil`.
  ///   - more: The number of the entries that the menu does not list.
  @ViewBuilder
  private func choiceRows(_ choices: [SessionPathEntry], current: SessionId?, more: Int = 0) -> some View {
    ForEach(choices) { entry in
      choiceButton(entry, isCurrent: entry.sessionId == current)
    }
    if more > 0 {
      Text(String(localized: "\(more) more. Use Jump to Session to search.", bundle: .module))
    }
  }

  /// One choice of a dropdown.
  ///
  /// - Parameters:
  ///   - entry: The session of the choice.
  ///   - isCurrent: Whether the choice is the shown session.
  private func choiceButton(_ entry: SessionPathEntry, isCurrent: Bool) -> some View {
    let text = SessionStateText.choiceLabel(for: entry, locale: locale)
    let symbol = Self.mark(of: entry, isCurrent: isCurrent)
    return Button {
      select(entry.sessionId)
    } label: {
      Label(text, systemImage: symbol)
    }
    .accessibilityAddTraits(isCurrent ? .isSelected : [])
  }

  /// The menu of the children of the shown session, as a trailing crumb: an
  /// EditorKit `EditorMenuButton`, which hides its caption and keeps its
  /// symbol when squeezed. The symbol is the warning mark when a child needs
  /// the user.
  private func childrenDropdown(of session: SessionModel) -> some View {
    let entries = session.children.filter { !$0.isClosed }.map(\.pathEntry)
    let split = ChildrenMenu.split(entries)
    let attention = entries.contains(where: \.needsAttention)
    return EditorMenuButton(
      String(localized: "Children (\(entries.count))", bundle: .module),
      systemImage: attention ? EditorSymbol.severity(.warning).systemImage : AgentSymbol.childSession
    ) {
      choiceRows(split.listed, current: nil, more: split.more)
    }
    .accessibilityLabel(
      attention
        ? String(localized: "Children, \(entries.count), one needs your attention", bundle: .module)
        : String(localized: "Children, \(entries.count)", bundle: .module)
    )
    .accessibilityIdentifier(Self.childrenIdentifier)
  }

  /// The symbol of a choice: a checkmark for the shown session, a warning for
  /// a session that needs the user, and a plain circle for the others. The
  /// text of the choice tells the same, so the symbol is not the only sign.
  ///
  /// - Parameters:
  ///   - entry: The choice.
  ///   - isCurrent: Whether the choice is the shown session.
  /// - Returns: The SF Symbol name.
  static func mark(of entry: SessionPathEntry, isCurrent: Bool) -> String {
    if isCurrent { return "checkmark" }
    return entry.needsAttention ? EditorSymbol.severity(.warning).systemImage : "circle"
  }

  /// The scope of the crumb of a session, so the crumb takes the keyboard
  /// focus and is a target of the EditorKit jump and navigation.
  ///
  /// - Parameter id: The id of the session.
  /// - Returns: The scope modifier.
  private func crumbScope(_ id: SessionId) -> AgentControlScope {
    AgentControlScope(segment: AgentScopeKind.crumb(id), corners: .capsule, yieldsToHostScope: false)
  }

  /// The VoiceOver label of a crumb: the title, the state, and
  /// `SessionStateText.needsAttention` when the session needs the user, as a
  /// list in `FormatStyle/spokenParts(locale:)`.
  ///
  /// - Parameters:
  ///   - session: The session of the crumb.
  ///   - title: The title of the crumb. The default is the display title of
  ///     the session.
  ///   - locale: The locale of the label.
  /// - Returns: Text such as "Linter, Waiting for you, needs your attention".
  static func accessibilityLabel(
    for session: SessionModel, title: String? = nil, locale: Locale = .autoupdatingCurrent
  ) -> String {
    let attention = session.needsAttention ? SessionStateText.needsAttention : nil
    let parts = [title ?? session.displayTitle, session.status.text] + [attention].compactMap(\.self)
    return parts.formatted(.spokenParts(locale: locale))
  }
}
