import FoundationModelsACP
import FoundationModelsACPClient

/// Reads of the session tree for the views.
///
/// The model is parent and child all the way down: each function here works
/// the same at each level, and none of them knows a number of levels. The
/// functions read the model directly and keep no copy of it.
extension SessionModel {
  /// Finds a session in the tree of this session: this session itself, or a
  /// descendant of it at any level.
  ///
  /// - Parameter id: The id of the session.
  /// - Returns: The model, or `nil` when the tree has no such session.
  public func session(withId id: SessionId) -> SessionModel? {
    if sessionId == id { return self }
    for child in children {
      if let found = child.session(withId: id) { return found }
    }
    return nil
  }

  /// The sessions from the root to this session, with this session last.
  var pathModels: [SessionModel] {
    var path = [self]
    var current = self
    while let parent = current.parent {
      path.insert(parent, at: 0)
      current = parent
    }
    return path
  }

  /// This session, or its nearest ancestor that is not closed.
  ///
  /// A view that shows a child that the client removed shows its parent
  /// instead, and so on up, so a removed child never leaves the view empty.
  var nearestOpenSession: SessionModel {
    var current = self
    while current.isClosed, let parent = current.parent {
      current = parent
    }
    return current
  }

  /// The sessions that Jump to Session lists: the ancestors and the
  /// descendants of this session, the ancestors first.
  var jumpEntries: [SessionPathEntry] {
    ancestors + descendants
  }

  /// The descendant that the user is asked to handle first: the first
  /// descendant that itself waits for the user, or else the first descendant
  /// that needs attention through one of its own descendants.
  var waitingDescendant: SessionPathEntry? {
    let all = descendants
    return all.first { $0.waitsItself } ?? all.first(where: \.needsAttention)
  }

  /// The session of the tree that waits for the user and that is not this
  /// session: a descendant first, then an ancestor, nearest first, then a
  /// sibling.
  ///
  /// The banner of the shown session uses it, so a question in any other part
  /// of the tree has a jump.
  var waitingElsewhere: SessionPathEntry? {
    if let below = waitingDescendant { return below }
    if let above = ancestors.reversed().first(where: \.waitsItself) { return above }
    return siblings.first { $0.sessionId != sessionId && ($0.waitsItself || $0.needsAttention) }
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
    case .running: WorkStatusLabel.inProgress
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
  static func choiceLabel(for entry: SessionPathEntry, model: SessionModel? = nil) -> String {
    let state = model.map { SessionStatus.of($0).text } ?? text(for: entry.workState)
    var parts = [entry.title, state]
    if entry.pendingRequestCount > 0 {
      parts.append(PendingRequestCountBadge.openQuestionsLabel(count: entry.pendingRequestCount))
    }
    if entry.needsAttention { parts.append(String(localized: "needs your attention", bundle: .module)) }
    return parts.joined(separator: ", ")
  }
}

extension SessionPathEntry {
  /// Whether the session itself waits for the user: it has an open request,
  /// or its state is `requires_action`. The `needsAttention` flag also counts
  /// the descendants of the session.
  var waitsItself: Bool {
    pendingRequestCount > 0 || workState == .requiresAction
  }
}
