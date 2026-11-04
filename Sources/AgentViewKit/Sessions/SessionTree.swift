import EditorSwiftUI
import FoundationModelsACP
import FoundationModelsACPClient

/// Reads of the session tree for the views.
///
/// The model is parent and child all the way down: each function here works
/// the same at each level, and none of them knows a number of levels. The
/// tree queries (`path`, `session(withId:)`, `nearestOpenAncestor`,
/// `firstWaitingSession`) come from `FoundationModelsACPClient`; the views
/// read them directly and keep no copy.
extension SessionModel {
  /// The sessions that Jump to Session lists: the ancestors and the
  /// descendants of this session, the ancestors first.
  var jumpEntries: [SessionPathEntry] {
    ancestors + descendants
  }

  /// The session below this one that the user is asked to handle first: the
  /// first descendant that itself waits for the user.
  var waitingDescendant: SessionPathEntry? {
    children.lazy.compactMap(\.firstWaitingSession).first?.pathEntry
  }

  /// The session of the tree that waits for the user and that is not this
  /// session: a descendant first, then an ancestor, nearest first, then a
  /// sibling.
  ///
  /// The banner of the shown session uses it, so a question in any other part
  /// of the tree has a jump.
  var waitingElsewhere: SessionPathEntry? {
    if let below = waitingDescendant { return below }
    if let above = path.dropLast().reversed().first(where: \.ownNeedsAttention) { return above.pathEntry }
    let siblings = parent?.children.filter { $0 !== self } ?? []
    return siblings.lazy.compactMap(\.firstWaitingSession).first?.pathEntry
  }
}

/// The text of a path of titles, such as "Agent, Reviewer, and Linter".
enum SessionPathText {
  /// The separator of the spoken path.
  static let spokenSeparator = ", then "

  /// The spoken form of a path, one name after the other.
  ///
  /// - Parameter titles: The titles, from the root.
  /// - Returns: Text such as "Path: Agent, then Reviewer, then Linter".
  static func label(_ titles: [String]) -> String {
    let path = titles.joined(separator: spokenSeparator)
    return String(localized: "Path: \(path)", bundle: .module)
  }
}

/// The text of the work state of a session, for the dropdowns and the labels
/// of the breadcrumb.
enum SessionStateText {
  /// The name of a work state.
  ///
  /// - Parameter state: The work state of a session.
  /// - Returns: "In progress", "Waiting for you", "Idle", or "Unknown".
  static func text(for state: SessionWorkState) -> String {
    switch state {
    case .running: EditorStatus(EditorSymbol.Status.inProgress).label
    case .requiresAction: String(localized: "Waiting for you", bundle: .module)
    case .idle: String(localized: "Idle", bundle: .module)
    case .unknown: String(localized: "Unknown", bundle: .module)
    }
  }

  /// The text of one choice of a dropdown: the title, the state, and the
  /// count of the open questions when there are some.
  ///
  /// - Parameter entry: The path entry of the session.
  /// - Returns: Text such as "Reviewer, In progress, 1 open question".
  static func choiceLabel(for entry: SessionPathEntry) -> String {
    var parts = [entry.title, entry.status.text]
    if entry.pendingRequestCount > 0 {
      parts.append(PendingRequestCountBadge.openQuestionsLabel(count: entry.pendingRequestCount))
    }
    if entry.needsAttention { parts.append(String(localized: "needs your attention", bundle: .module)) }
    return parts.joined(separator: ", ")
  }
}
