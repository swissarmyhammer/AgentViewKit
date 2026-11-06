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
}

/// One selection command: a verb and the target of the scope of its file.
///
/// The command holds its target weakly, as ``AgentAttachmentCommand`` does,
/// and runs the select action of the target with the change of its verb.
nonisolated struct AgentFileSelectionCommand: EditorCommands.Command {
  /// The verb of the command.
  let verb: AgentFileSelectionVerb

  /// The target of the scope that registered the command.
  weak let target: AgentAttachmentTarget?

  var id: CommandID { verb.id }

  var title: String { verb.title }

  func availability(in context: CommandContext) -> Availability {
    MainActor.assumeIsolated {
      target?.select == nil ? .attachmentNotShown : .available
    }
  }

  /// Runs the select action of the target with the change of the verb.
  ///
  /// - Parameter context: The context of the invocation.
  /// - Returns: `true` when the target has a select action.
  func run(in context: CommandContext) -> Bool {
    MainActor.assumeIsolated {
      guard let select = target?.select else { return false }
      select(verb.change)
      return true
    }
  }

  /// The EditorKit definition of `verb` for `target`, with the title of the
  /// verb and no place in a menu.
  ///
  /// - Parameters:
  ///   - verb: The verb.
  ///   - target: The target of the scope.
  /// - Returns: The definition.
  static func definition(of verb: AgentFileSelectionVerb, for target: AgentAttachmentTarget) -> CommandDefinition {
    CommandDefinition(
      id: verb.id,
      title: .static(verb.title),
      make: { [weak target] _ in
        AgentFileSelectionCommand(verb: verb, target: target)
      })
  }
}
