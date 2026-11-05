import EditorSwiftUI
import Foundation
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

/// The text of a path of titles, such as "Path: Agent, then Reviewer".
enum SessionPathText {
  /// The spoken form of a path, one name after the other: the spoken path
  /// pattern of the catalog (``ChainText/spokenPath(_:locale:)``) inside one
  /// catalog string.
  ///
  /// - Parameters:
  ///   - titles: The titles, from the root.
  ///   - locale: The locale of the text.
  /// - Returns: Text such as "Path: Agent, then Reviewer, then Linter".
  static func label(_ titles: [String], locale: Locale = .autoupdatingCurrent) -> String {
    let path = ChainText.spokenPath(titles, locale: locale)
    return String(
      localized: "Path: \(path)", bundle: .module, locale: locale,
      comment: "The VoiceOver label of the path of the shown session: the titles from the root, one after the other.")
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

  /// The note of a session that needs the user, the last part of a label.
  static var needsAttention: String { String(localized: "needs your attention", bundle: .module) }

  /// The text of one choice of a dropdown: the title, the state, the count
  /// of the open questions when there are some, and ``needsAttention`` when
  /// the session needs the user, as a list in
  /// `FormatStyle/spokenParts(locale:)`.
  ///
  /// - Parameters:
  ///   - entry: The path entry of the session.
  ///   - locale: The locale of the text.
  /// - Returns: Text such as "Reviewer, In progress, 1 open question".
  static func choiceLabel(for entry: SessionPathEntry, locale: Locale = .autoupdatingCurrent) -> String {
    let count = entry.pendingRequestCount
    let questions = count > 0 ? PendingRequestCountBadge.openQuestionsLabel(count: count) : nil
    let attention = entry.needsAttention ? needsAttention : nil
    let parts = [entry.title, entry.status.text] + [questions, attention].compactMap(\.self)
    return parts.formatted(.spokenParts(locale: locale))
  }
}
