import FoundationModelsACP
import FoundationModelsACPClient

/// The preview items of the row height tests: one for each row kind.
enum TranscriptRowFixtures {
  /// A paragraph that wraps at each test width.
  static let paragraph = """
    The cache computes the height of each row from its data. It does this work on a \
    background task, so that a scroll does not wait for the layout of rows that are far from view.
    """

  /// A user message of two paragraphs.
  static let userMessage = PreviewTranscriptItem.user(paragraph + "\n\nA second paragraph.")

  /// An agent message of prose only.
  static let agentProse = PreviewTranscriptItem.agent(paragraph)

  /// An agent message of prose, a Swift code fence and prose.
  static let agentFenced = PreviewTranscriptItem.agent(
    "Intro text.\n\n```swift\nlet rows = heights.count\nprint(rows)\n```\n\n" + paragraph)

  /// A line of code that wraps at each test width.
  static let longCodeLine =
    "let summary = rows.filter { $0.isVisible }.map { row in row.title + \": \" + row.detail }.joined(separator: \", \")"

  /// The numbers of the short lines of the long code block and the long
  /// output: more than nine, so a line number gutter has two digits.
  static let longLineNumbers = 1...12

  /// Twelve lines of code, so the line number gutter has two digits, with
  /// one line that wraps.
  static let twelveCodeLines = longLineNumbers.map { "let value\($0) = \($0)" }.joined(separator: "\n") + "\n" + longCodeLine

  /// An agent message with a Swift fence of twelve lines and a line that
  /// wraps: a TextMate grammar and a gutter of two digits.
  static let agentFencedLong = PreviewTranscriptItem.agent(
    "The rows:\n\n```swift\n" + twelveCodeLines + "\n```\n\nThe end.")

  /// An agent message with a fence that names no language and a line that
  /// wraps: plain text with a gutter of one digit.
  static let agentFencedPlain = PreviewTranscriptItem.agent(
    "Run this:\n\n```\n" + longCodeLine + "\n```")

  /// An agent message with a JSON fence: a tree-sitter grammar.
  static let agentFencedJSON = PreviewTranscriptItem.agent(
    "The config:\n\n```json\n{\n  \"name\": \"parser\",\n  \"rows\": [1, 2, 3],\n  \"detail\": \""
      + paragraph + "\"\n}\n```")

  /// A thought.
  static let thought = PreviewTranscriptItem.thought(paragraph)

  /// A completed tool call that reads a file.
  static let toolCall = PreviewTranscriptItem.toolCall(
    title: "Read Sources/AgentViewKit/Thread/TranscriptRowHeights.swift", kind: .read, status: .completed)

  /// The relative path of the diff.
  static let diffPath = "Sources/App.swift"

  /// The git patch of the diff.
  static let patch = """
    diff --git a/Sources/App.swift b/Sources/App.swift
    --- a/Sources/App.swift
    +++ b/Sources/App.swift
    @@ -1,2 +1,2 @@
    -let name = "old"
    +let name = "new"
     let count = 2

    """

  /// A completed edit call with one diff.
  static let diff = edit(path: diffPath, patch: patch)

  /// The relative path of the long diff: a JSON file, so the diff has a
  /// tree-sitter grammar.
  static let longDiffPath = "Config/rows.json"

  /// The numbers of the value rows of the JSON object of the long diff.
  static let longPatchRows = 2...10

  /// The factor of the new value of a changed row of the long diff.
  nonisolated static let changedValueFactor = 10

  /// The rows of the long diff whose value changes. The context between
  /// two changes is short, so the diff view folds no context.
  nonisolated static let changedRows: Set<Int> = [4, 8]

  /// One context or changed row of the JSON object of the long diff.
  ///
  /// - Parameter row: The number of the row.
  /// - Returns: The lines of the patch for the row.
  nonisolated static func longPatchRow(_ row: Int) -> String {
    guard changedRows.contains(row) else { return "   \"row\(row)\": \(row),\n" }
    return "-  \"row\(row)\": \(row),\n+  \"row\(row)\": \(row * changedValueFactor),\n"
  }

  /// The git patch of the long diff: thirteen lines in each file, so the
  /// line number gutter has two digits, three changes, and one line that
  /// wraps.
  static let longPatch =
    "diff --git a/\(longDiffPath) b/\(longDiffPath)\n--- a/\(longDiffPath)\n+++ b/\(longDiffPath)\n"
    + "@@ -1,13 +1,13 @@\n {\n"
    + longPatchRows.map(longPatchRow).joined()
    + "-  \"detail\": \"old\",\n+  \"detail\": \"" + paragraph + "\",\n"
    + "   \"last\": 12\n }\n"

  /// A completed edit call with a diff of thirteen lines and a line that
  /// wraps.
  static let diffLong = edit(path: longDiffPath, patch: longPatch)

  /// A completed edit call with one diff of a file.
  ///
  /// - Parameters:
  ///   - path: The relative path of the file.
  ///   - patch: The git patch text.
  /// - Returns: The item.
  static func edit(path: String, patch: String) -> PreviewTranscriptItem {
    .update(
      .toolCallUpdate(
        ToolCallUpdate(
          toolCallId: ToolCallId(rawValue: "edit"),
          content: .value([
            .diff(
              Diff(
                changes: [
                  DiffChange(operation: .add(DiffPathChange(path: AbsolutePath(rawValue: "/project/" + path))))
                ],
                patch: DiffPatch(format: .gitPatch, text: patch)))
          ]),
          kind: .value(.edit),
          status: .value(.completed),
          title: .value("Edit " + path))))
  }

  /// A completed execute call with its output and its exit code.
  static let commandOutput = run(output: "Building...\nBuild complete.\n")

  /// A completed execute call with twelve lines of output and a line that
  /// wraps.
  static let commandOutputLong = run(
    output: longLineNumbers.map { "Compiling module \($0)" }.joined(separator: "\n") + "\n" + paragraph + "\n")

  /// A completed execute call of `swift build` with an output and the exit
  /// code zero.
  ///
  /// - Parameter output: The output text.
  /// - Returns: The item.
  static func run(output: String) -> PreviewTranscriptItem {
    .update(
      .toolCallUpdate(
        ToolCallUpdate(
          toolCallId: ToolCallId(rawValue: "run"),
          content: .value([
            .content(Content(content: .text(TextContent(text: output))))
          ]),
          kind: .value(.execute),
          rawInput: .value(.object(["command": .string("swift build")])),
          rawOutput: .value(.object(["exitCode": .number(0)])),
          status: .value(.completed),
          title: .value("swift build"))))
  }

  /// A terminal that ran a command.
  static let terminal = PreviewTranscriptItem.terminal(
    command: "swift test", output: "Test run started.\nTest run passed.", exitCode: 0)

  /// A plan of three steps.
  static let plan = PreviewTranscriptItem.plan([
    PlanEntry(content: "Read the rows", priority: .high, status: .completed),
    PlanEntry(content: paragraph, priority: .medium, status: .inProgress),
    PlanEntry(content: "Publish the heights", priority: .low, status: .pending),
  ])

  /// An error notice.
  static let notice = PreviewTranscriptItem.error(code: .internalError, message: paragraph)

  /// A completed compaction with a summary of one text block.
  static let compaction = PreviewTranscriptItem.update(
    .compactionUpdate(
      CompactionUpdate(
        compactionId: CompactionId(rawValue: "compaction"), status: .completed,
        summary: .value([.text(TextContent(text: paragraph))]))))

  /// A message from a child session, with one text block.
  static let sessionMessage = PreviewTranscriptItem.update(
    .sessionMessage(
      SessionMessage(
        messageId: MessageId(rawValue: "mail"), content: .value([.text(TextContent(text: paragraph))]),
        senderSessionId: .value(SessionId(rawValue: "child-1")))))

  /// Each row kind of the fixtures.
  enum Row: String, CaseIterable, Sendable {
    /// ``TranscriptRowFixtures/userMessage``.
    case userMessage
    /// ``TranscriptRowFixtures/agentProse``.
    case agentProse
    /// ``TranscriptRowFixtures/agentFenced``.
    case agentFenced
    /// ``TranscriptRowFixtures/agentFencedLong``.
    case agentFencedLong
    /// ``TranscriptRowFixtures/agentFencedPlain``.
    case agentFencedPlain
    /// ``TranscriptRowFixtures/agentFencedJSON``.
    case agentFencedJSON
    /// ``TranscriptRowFixtures/thought``.
    case thought
    /// ``TranscriptRowFixtures/toolCall``.
    case toolCall
    /// ``TranscriptRowFixtures/diff``.
    case diff
    /// ``TranscriptRowFixtures/diffLong``.
    case diffLong
    /// ``TranscriptRowFixtures/commandOutput``.
    case commandOutput
    /// ``TranscriptRowFixtures/commandOutputLong``.
    case commandOutputLong
    /// ``TranscriptRowFixtures/terminal``.
    case terminal
    /// ``TranscriptRowFixtures/plan``.
    case plan
    /// ``TranscriptRowFixtures/notice``.
    case notice
    /// ``TranscriptRowFixtures/compaction``.
    case compaction
    /// ``TranscriptRowFixtures/sessionMessage``.
    case sessionMessage

    /// The preview item of the row kind.
    var item: PreviewTranscriptItem {
      switch self {
      case .userMessage: TranscriptRowFixtures.userMessage
      case .agentProse: TranscriptRowFixtures.agentProse
      case .agentFenced: TranscriptRowFixtures.agentFenced
      case .agentFencedLong: TranscriptRowFixtures.agentFencedLong
      case .agentFencedPlain: TranscriptRowFixtures.agentFencedPlain
      case .agentFencedJSON: TranscriptRowFixtures.agentFencedJSON
      case .thought: TranscriptRowFixtures.thought
      case .toolCall: TranscriptRowFixtures.toolCall
      case .diff: TranscriptRowFixtures.diff
      case .diffLong: TranscriptRowFixtures.diffLong
      case .commandOutput: TranscriptRowFixtures.commandOutput
      case .commandOutputLong: TranscriptRowFixtures.commandOutputLong
      case .terminal: TranscriptRowFixtures.terminal
      case .plan: TranscriptRowFixtures.plan
      case .notice: TranscriptRowFixtures.notice
      case .compaction: TranscriptRowFixtures.compaction
      case .sessionMessage: TranscriptRowFixtures.sessionMessage
      }
    }

    /// The row kinds with a code block, a command output or a diff: the
    /// row kinds whose heights need the EditorKit measure of code
    /// (`EditorLayoutMeasure.measure(code:width:style:grammar:gutter:)`).
    nonisolated static let codeRows: [Row] = [
      .agentFenced, .agentFencedLong, .agentFencedPlain, .agentFencedJSON, .diff, .diffLong, .commandOutput,
      .commandOutputLong,
    ]

    /// Whether the blocks of the row are expanded.
    var isExpanded: Bool {
      [.diff, .diffLong, .commandOutput, .commandOutputLong].contains(self)
    }
  }
}
