import EditorCommands
import EditorCommandsUI
import Foundation

/// The selection commands of a file view, Add to Selection and Extend
/// Selection, as EditorKit commands (card ^se9sxxe).
///
/// A file view (``InspectorSelectable``) binds its Command-click and its
/// Shift-click to these commands with EditorKit's `.commandClick`. EditorKit
/// takes a bound click in the window before any gesture sees it, and of two
/// bindings that catch one click the outer one wins, so a host row around the
/// file that binds the same clicks would take them from a tap gesture of the
/// file. The file view keeps the bound clicks of each binding around it from
/// its place (`.blocksCommandClicks()`), and its own bindings still catch
/// them, so the click changes the file selection and runs no command of the
/// row.
///
/// The scope of the file (``AgentAttachmentScope``) registers the commands at
/// its own path, with the select action of the view on its target, only when
/// the view selects its file. The commands have no place in a menu: the view
/// names each one as an accessibility action of its own.
nonisolated enum AgentFileSelectionVerb: String, CaseIterable, Sendable {
  /// Adds the file to the selection, or takes it out: a Command-click.
  case addFileToSelection

  /// Extends the selection to the file, in transcript order: a Shift-click.
  case extendFileSelection

  /// The command id of the verb, `agent.<verb>`.
  var id: CommandID {
    CommandID(AgentCommandVerb.idPrefix + rawValue)
  }

  /// The kind of the press that the verb makes.
  var change: AttachmentSelectionChange {
    switch self {
    case .addFileToSelection: .toggle
    case .extendFileSelection: .extend
    }
  }

  /// The title of the verb: the name of the accessibility action of its
  /// press.
  var title: String {
    change.actionName
  }

  /// The command action of the verb: it runs the select action of the
  /// target with the change of the verb, and it has no place in a menu. With
  /// no select action, the command is unavailable and its run declines.
  var action: AgentAttachmentCommand.Action {
    AgentAttachmentCommand.Action(
      id: id, title: title,
      availability: { target, _ in target.select == nil ? .attachmentNotShown : .available },
      run: { [change] target, _ in
        guard let select = target.select else { return false }
        select(change)
        return true
      })
  }
}
