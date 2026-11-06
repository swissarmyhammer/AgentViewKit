import EditorStyle
import EditorSwiftUI
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The crumbs of the sessions after the agent in the header: one crumb for
/// each session on the path from the root to the shown session, in an
/// EditorKit `EditorBreadcrumbBar`, and the menu of the children of the shown
/// session after it.
///
/// Each crumb opens a menu with the siblings at its level: the sessions with
/// the same parent. Each choice shows the title, the work state and the count
/// of the open questions. A crumb shows the warning mark when
/// `needsAttention` is true, so a question of a session deep in the tree
/// shows on each crumb above it, and VoiceOver speaks the mark as the value
/// of the crumb. A choice gives the id of the session to the host through
/// `select`; the view keeps no state of the choice.
///
/// When the host gives a title, the first crumb shows it in place of the
/// title of its session, such as the title of a tab (D142).
///
/// The bar owns the layout of the path: with less room it hides the oldest
/// ancestors in a leading "…" crumb, and a last crumb that still lacks room
/// wraps its title, so no title is cut. Each crumb is one accessibility
/// element and a jump target at `FocusSegment.editorBreadcrumb(id:)`, whose
/// id is the id of its session.
struct SessionBreadcrumb: View {
  /// The accessibility identifier of the crumb of a session: the identifier
  /// that the bar gives the crumb whose id is the id of the session.
  ///
  /// - Parameter id: The id of the session.
  /// - Returns: The identifier, `breadcrumb-<sessionId>`.
  static func crumbIdentifier(for id: SessionId) -> String {
    EditorBreadcrumbBar.accessibilityIdentifier(ofCrumb: id.rawValue)
  }

  /// The accessibility identifier of the bar of the crumbs, whose label
  /// speaks the whole path.
  static let barIdentifier = "session-breadcrumb"

  /// The accessibility identifier of the dropdown of the children of the
  /// shown session.
  static let childrenIdentifier = "session-crumb-children"

  /// The sessions from the root to the shown session.
  let path: [SessionModel]

  /// The title that the host gives to the first crumb, or `nil` for the
  /// title of its session.
  let rootTitle: String?

  /// The shown session: the last session of ``path``.
  private var shown: SessionModel? { path.last }

  /// Called with the id of the session that the user chooses.
  let select: (SessionId) -> Void

  @Environment(\.locale) private var locale

  var body: some View {
    separator
    EditorBreadcrumbBar(path.map(crumb))
      .accessibilityIdentifier(Self.barIdentifier)
    if let shown, shown.children.contains(where: { !$0.isClosed }) {
      separator
      childrenDropdown(of: shown)
    }
  }

  /// The separator before the bar and before the children menu: the
  /// disclosure symbol that the bar puts between two crumbs, decorative and
  /// hidden from accessibility.
  private var separator: some View {
    EditorSymbolImage(.action(.disclosure))
      .imageScale(.small)
      .accessibilityHidden(true)
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

  /// The crumb of a session: its title, the warning mark when it needs the
  /// user, and the menu of its siblings.
  ///
  /// - Parameter session: The session of the crumb.
  /// - Returns: The crumb, whose id is the id of the session.
  private func crumb(_ session: SessionModel) -> EditorBreadcrumb {
    EditorBreadcrumb(id: session.sessionId.rawValue, title: title(of: session), mark: Self.attentionMark(of: session)) {
      choiceRows(session.siblingsIncludingSelf, current: session.sessionId)
    }
  }

  /// The mark of the crumb of a session: the warning when the session, or a
  /// session below it, needs the user, which VoiceOver speaks as
  /// `SessionStateText.needsAttention`.
  ///
  /// - Parameter session: The session of the crumb.
  /// - Returns: The warning mark, or `nil` when the session needs nothing.
  static func attentionMark(of session: SessionModel) -> EditorBreadcrumbMark? {
    guard session.needsAttention else { return nil }
    return .symbol(.severity(.warning), label: SessionStateText.needsAttention)
  }

  /// The rows of a menu: a choice for each session entry, then the note of
  /// the entries that the menu does not list.
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

  /// One choice of a menu.
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

  /// The menu of the children of the shown session, after the bar: an
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
}
