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
  static let diff = PreviewTranscriptItem.update(
    .toolCallUpdate(
      ToolCallUpdate(
        toolCallId: ToolCallId(rawValue: "edit"),
        content: .value([
          .diff(
            Diff(
              changes: [
                DiffChange(operation: .add(DiffPathChange(path: AbsolutePath(rawValue: "/project/" + diffPath))))
              ],
              patch: DiffPatch(format: .gitPatch, text: patch)))
        ]),
        kind: .value(.edit),
        status: .value(.completed),
        title: .value("Edit Sources/App.swift"))))

  /// A completed execute call with its output and its exit code.
  static let commandOutput = PreviewTranscriptItem.update(
    .toolCallUpdate(
      ToolCallUpdate(
        toolCallId: ToolCallId(rawValue: "run"),
        content: .value([
          .content(Content(content: .text(TextContent(text: "Building...\nBuild complete.\n"))))
        ]),
        kind: .value(.execute),
        rawInput: .value(.object(["command": .string("swift build")])),
        rawOutput: .value(.object(["exitCode": .number(0)])),
        status: .value(.completed),
        title: .value("swift build"))))

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
    /// ``TranscriptRowFixtures/thought``.
    case thought
    /// ``TranscriptRowFixtures/toolCall``.
    case toolCall
    /// ``TranscriptRowFixtures/diff``.
    case diff
    /// ``TranscriptRowFixtures/commandOutput``.
    case commandOutput
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
      case .thought: TranscriptRowFixtures.thought
      case .toolCall: TranscriptRowFixtures.toolCall
      case .diff: TranscriptRowFixtures.diff
      case .commandOutput: TranscriptRowFixtures.commandOutput
      case .terminal: TranscriptRowFixtures.terminal
      case .plan: TranscriptRowFixtures.plan
      case .notice: TranscriptRowFixtures.notice
      case .compaction: TranscriptRowFixtures.compaction
      case .sessionMessage: TranscriptRowFixtures.sessionMessage
      }
    }

    /// Whether the blocks of the row are expanded.
    var isExpanded: Bool {
      self == .diff || self == .commandOutput
    }
  }
}
