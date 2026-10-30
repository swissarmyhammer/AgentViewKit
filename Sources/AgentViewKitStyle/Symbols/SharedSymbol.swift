import Foundation
import SwiftUI

/// The shared symbol table of the view kits: each SF Symbol of a concept that
/// more than one view kit shows.
///
/// Each constant is one concept, and each concept has one symbol. A view
/// reads the name of a concept from here, so all views of that concept
/// change together, and two concepts do not show the same symbol. A kit adds
/// the symbols of its own concepts in an extension of this table, in one
/// file of its own: AgentViewKit writes its agent symbols in
/// `SharedSymbol+Agent.swift`. No other source file of the package writes a
/// symbol name, and the two table files write each name one time.
///
/// No symbol of the table is a clock symbol (`clock`, each `clock.*` symbol,
/// `timer`, `alarm`): a clock is a scheduled task (EditorKit `style.md`).
///
/// The symbols of the status of work and of a priority are not in this
/// table. They come from `ItemStatus` and `ItemPriority` of the EditorKit
/// `EditorStyle` target, so that the kits show the same symbol for the same
/// state.
public nonisolated enum SharedSymbol {
  // MARK: - Status

  /// The symbol of an error: a failed tool call, a failed turn, a failed
  /// message, command or connection, an error notice, an error card and a
  /// patch that a view cannot read.
  public static let error = "xmark.octagon.fill"

  /// The symbol of a warning: a warning notice, a lost tool result, missing
  /// updates, an attachment that the agent does not accept and a link that
  /// leaves the app.
  public static let warning = "exclamationmark.triangle.fill"

  /// The symbol of an information notice.
  public static let information = "info.circle.fill"

  // MARK: - Tool kinds

  /// The symbol of a tool that reads a file.
  public static let read = "text.document"

  /// The symbol of an edit: a tool that edits a file, and an Edit button.
  public static let edit = "pencil"

  /// The symbol of a deletion: a tool that deletes a file, and a Delete
  /// button.
  public static let delete = "trash"

  /// The symbol of a move: a tool that moves a file, a Move button, and the
  /// Move action of a selection.
  public static let move = "arrow.left.arrow.right"

  /// The symbol of a tool that searches.
  public static let search = "magnifyingglass"

  /// The symbol of a terminal or a shell command: the `execute` tool kind,
  /// a terminal, a command output row, a command in a permission request,
  /// the terminal link of a permission request and the Run button of a
  /// terminal sign-in.
  public static let terminal = "apple.terminal"

  /// The symbol of the reasoning of the model: a thinking tool, a thought,
  /// and a response that stopped during the reasoning.
  public static let reasoning = "brain"

  /// The symbol of a tool that fetches a web resource.
  public static let web = "globe"

  /// The symbol of a change of the session mode: a tool that changes the
  /// session mode, and the "switch to auto" button of a permission request.
  public static let switchMode = "switch.2"

  /// The symbol of a tool: a tool of an other kind, a tool call in a
  /// permission request and the menu of the tools.
  public static let tool = "wrench.and.screwdriver"

  // MARK: - File operations

  /// The symbol of a file that a change makes.
  public static let addedFile = "plus.square"

  /// The symbol of a file that a change removes.
  public static let deletedFile = "minus.square"

  /// The symbol of a file whose lines a change changes.
  public static let modifiedFile = "dot.square"

  /// The symbol of a file that a change moves to a new path.
  public static let renamedFile = "arrow.right.square"

  /// The symbol of a file that a change copies to a new path.
  public static let copiedFile = "plus.square.on.square"

  /// The symbol of a binary file: a changed file with no text lines to
  /// show.
  public static let binary = "01.square"

  /// The symbol of a file location, such as a location chip of a tool call.
  public static let document = "document"

  // MARK: - Buttons

  /// The symbol of a button that does a thing again: Refresh, Retry, the
  /// Reload button of a banner, the Reconnect button of the auth card and the
  /// Retry button of the URL consent card.
  public static let reload = "arrow.clockwise"

  /// The symbol of a button that closes a thing with no answer: the button
  /// that closes a notice and the Cancel button of an elicitation.
  public static let dismiss = "xmark"

  // MARK: - Content

  /// The symbol of a link: the mark of a link, such as the link of each row
  /// of the sources of an answer. A link has no accent text color, so this
  /// symbol marks it (card ^y2mrfxt).
  public static let link = "link"
}

#Preview("The shared symbols") {
  let names = [
    SharedSymbol.error, SharedSymbol.warning, SharedSymbol.information, SharedSymbol.read, SharedSymbol.edit,
    SharedSymbol.delete, SharedSymbol.move, SharedSymbol.search, SharedSymbol.terminal, SharedSymbol.reasoning,
    SharedSymbol.web, SharedSymbol.switchMode, SharedSymbol.tool, SharedSymbol.addedFile, SharedSymbol.deletedFile,
    SharedSymbol.modifiedFile, SharedSymbol.renamedFile, SharedSymbol.copiedFile, SharedSymbol.binary,
    SharedSymbol.document, SharedSymbol.reload, SharedSymbol.dismiss, SharedSymbol.link,
  ]
  Grid(alignment: .leading) {
    ForEach(names, id: \.self) { name in
      GridRow {
        StatusSymbolImage(name: name, color: .secondary)
        Text(verbatim: name)
      }
    }
  }
  .padding()
}
