import AppKit
import EditorCommands
import EditorCommandsUI

/// The rules of the find verbs of a thread and of the Esc that removes its
/// search hits (TestudoApp D207 (f)).
///
/// Find Next Hit and Find Previous Hit (``AgentCommandVerb/findNextHit``,
/// ``AgentCommandVerb/findPreviousHit``) and the Cancel of the hits act only
/// when the thread has hits and no text input has the focus. In a text
/// input, Command-G stays the find of the editor (D133), and Esc stays the
/// Esc of the text input (D137 (d)).
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

  /// Whether Esc removes the search hits now: the thread has hits, and no
  /// text input has the focus.
  var canRemoveSearchHits: Bool {
    hasSearchHits && !textInputHasFocus
  }

  /// The Cancel (`edit.cancel`, Esc) that removes the search hits of the
  /// thread of `target`.
  ///
  /// The command is available only while ``canRemoveSearchHits`` is `true`.
  /// Otherwise it does not take Esc, and Esc goes on to the next binding:
  /// Stop of the thread, then `nav.drillOut` of the window. The definition
  /// holds `target` weakly, as the definitions of the verbs do.
  ///
  /// - Parameter target: The target of the scope.
  /// - Returns: The definition.
  static func searchHitsCancel(for target: AgentCommandTarget) -> CommandDefinition {
    .cancel(
      isActive: { [weak target] in target?.canRemoveSearchHits ?? false },
      { [weak target] in target?.transcriptSearch?.removeHits() })
  }
}
