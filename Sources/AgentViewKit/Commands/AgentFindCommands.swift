import AppKit

/// The rules of the find verbs of a thread (TestudoApp D207 (f)).
///
/// Find Next Hit, Find Previous Hit and Clear Search Hits
/// (``AgentCommandVerb/findNextHit``, ``AgentCommandVerb/findPreviousHit``,
/// ``AgentCommandVerb/clearSearchHits``) act only when the thread has hits
/// and no text input has the focus. In a text input, Command-G stays the find
/// of the editor (D133), and Esc stays the Esc of the text input (D137 (d)).
extension AgentCommandTarget {
  /// The reason when a text input stops `verb`, or `nil` when nothing stops
  /// it there.
  ///
  /// - Parameter verb: The verb.
  /// - Returns: The reason for a verb of ``AgentCommandGroup/find`` while a
  ///   text input has the focus, else `nil`.
  func textInputReason(of verb: AgentCommandVerb) -> String? {
    guard verb.group == .find, textInputHasFocus else { return nil }
    return String(localized: "The focus is in a text input.", bundle: .module)
  }

  /// Whether the search of the thread view has a hit.
  var hasSearchHits: Bool {
    transcriptSearch?.hits.isEmpty == false
  }

  /// Whether a text input of the window of the scope has the focus.
  var textInputHasFocus: Bool {
    TextInputFocus.isEditing(firstResponder())
  }
}
