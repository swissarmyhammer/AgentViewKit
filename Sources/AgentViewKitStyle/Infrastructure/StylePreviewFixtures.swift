import EditorStyle
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

  /// The width of a narrow column, in points. A status bar or a row of chips
  /// in this column wraps.
  static let narrowWidth: CGFloat = 320

  /// Each status of work, in the order of the cases.
  static let itemStatuses = ItemStatus.allCases

  /// The titles of the sample chips of a flow layout.
  static let chipTitles = [
    "Package.swift", "Sources/Board/BoardColumn.swift", "README.md", "Tests/BoardTests/BoardColumnTests.swift",
  ]

  /// The line of the sample location that has one.
  static let locationLine = 42

  /// The sample locations of a tool call: a file with a line, and a file
  /// with none.
  static let locations = [
    ToolCallLocationChips.Location(
      path: "/Users/preview/Board/Sources/Board/BoardColumn.swift", line: locationLine,
      identifier: "preview-location-0"),
    ToolCallLocationChips.Location(
      path: "/Users/preview/Board/Package.swift", line: nil, identifier: "preview-location-1"),
  ]

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

  /// A patch whose hunk header EditorKit cannot read.
  static let unreadablePatch = """
    --- a/README.md
    +++ b/README.md
    @@ one two @@
    -old
    +new
    """

  /// A message of each severity, the neutral one of work that goes on.
  static let statusMessages = [
    StatusBar.Message(
      title: "Syncing the board", explanation: "The board loads its columns.",
      symbolName: ItemStatus.inProgress.systemImage, identifier: "preview-status-neutral", isOngoing: true),
    StatusBar.Message(
      title: "The board is read-only", explanation: "A second window edits the board.",
      symbolName: SharedSymbol.information, identifier: "preview-status-information", severity: .information),
    StatusBar.Message(
      title: "Some updates are missing", explanation: "Reload the board to see them.",
      symbolName: SharedSymbol.warning, identifier: "preview-status-warning", severity: .warning),
    failureStatusMessage,
  ]

  /// A failure message.
  static let failureStatusMessage = StatusBar.Message(
    title: "The board did not load", explanation: "The server did not answer. Reload the board.",
    symbolName: SharedSymbol.error, identifier: "preview-status-failure", severity: .failure)

  /// A message whose title and explanation are long, so that the bar wraps
  /// them in ``narrowWidth``.
  static let longStatusMessage = StatusBar.Message(
    title: "The board did not load because the server refused the credentials of this window",
    explanation: """
      The server answered 401 Unauthorized for each of the three columns of the board. Sign in again, \
      then reload the board.
      """,
    symbolName: SharedSymbol.error, identifier: "preview-status-long", severity: .failure)

  /// Makes the Reload button of a bar. A press does nothing.
  ///
  /// - Parameter isEnabled: Whether the button takes a press.
  /// - Returns: The button.
  static func statusAction(isEnabled: Bool) -> StatusBar.Action {
    StatusBar.Action(
      title: "Reload", systemImage: SharedSymbol.reload, identifier: "preview-status-action", isEnabled: isEnabled,
      hint: "Loads the board again.", perform: {})
  }
}
