import EditorStyle
import EditorSwiftUI
import Foundation

/// The sample data of the `#Preview`s of the style library.
///
/// The data is not agent data: a style view shows a file, a status or a
/// patch of any view kit.
enum StylePreviewFixtures {
  /// The header of the sample content tile.
  static let tileHeader = "swift build"

  /// The body of the sample content tile.
  static let tileBody = "Build of product 'Board' complete! (4.12s)"

  /// The name of a sample file.
  static let fileName = "BoardColumn.swift"

  /// The width of a narrow column, in points. A status bar in this column
  /// wraps.
  static let narrowWidth: CGFloat = 320

  /// The `toolCallId` of a sample tool call.
  static let toolCallID = "call-board-7"

  /// A git patch that changes one line of one file.
  static let patch = """
    diff --git a/Sources/Board/BoardColumn.swift b/Sources/Board/BoardColumn.swift
    --- a/Sources/Board/BoardColumn.swift
    +++ b/Sources/Board/BoardColumn.swift
    @@ -1,3 +1,3 @@
     struct BoardColumn {
    -  let title: String
    +  var title: String
     }
    """

  /// A message of each severity, the neutral one of work that goes on.
  static let statusMessages = [
    StatusBar.Message(
      title: "Syncing the board", explanation: "The board loads its columns.",
      symbolName: ItemStatus.inProgress.systemImage, identifier: "preview-status-neutral", isOngoing: true),
    StatusBar.Message(
      title: "The board is read-only", explanation: "A second window edits the board.",
      symbolName: EditorSymbol.severity(.information).systemImage, identifier: "preview-status-information",
      severity: .information),
    StatusBar.Message(
      title: "Some updates are missing", explanation: "Reload the board to see them.",
      symbolName: EditorSymbol.severity(.warning).systemImage, identifier: "preview-status-warning",
      severity: .warning),
    failureStatusMessage,
  ]

  /// A failure message.
  static let failureStatusMessage = StatusBar.Message(
    title: "The board did not load", explanation: "The server did not answer. Reload the board.",
    symbolName: EditorSymbol.severity(.error).systemImage, identifier: "preview-status-failure", severity: .failure)

  /// A message whose title and explanation are long, so that the bar wraps
  /// them in ``narrowWidth``.
  static let longStatusMessage = StatusBar.Message(
    title: "The board did not load because the server refused the credentials of this window",
    explanation: """
      The server answered 401 Unauthorized for each of the three columns of the board. Sign in again, \
      then reload the board.
      """,
    symbolName: EditorSymbol.severity(.error).systemImage, identifier: "preview-status-long", severity: .failure)

  /// A message with a short title and a long explanation, so that the
  /// explanation wraps below the title line in ``narrowWidth``.
  static let longExplanationStatusMessage = StatusBar.Message(
    title: "The board did not load",
    explanation: longStatusMessage.explanation,
    symbolName: EditorSymbol.severity(.error).systemImage, identifier: "preview-status-long-explanation",
    severity: .failure)

  /// A message with a title and no explanation.
  static let titleOnlyStatusMessage = StatusBar.Message(
    title: "The board is read-only", explanation: "",
    symbolName: EditorSymbol.severity(.information).systemImage, identifier: "preview-status-title-only",
    severity: .information)

  /// Makes the Reload button of a bar. A press does nothing.
  ///
  /// - Parameter isEnabled: Whether the button takes a press.
  /// - Returns: The button.
  static func statusAction(isEnabled: Bool) -> StatusBar.Action {
    StatusBar.Action(
      title: "Reload", systemImage: EditorSymbol.action(.reload).systemImage, identifier: "preview-status-action",
      isEnabled: isEnabled,
      hint: "Loads the board again.", perform: {})
  }
}
