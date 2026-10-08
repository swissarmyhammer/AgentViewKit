import FoundationModelsACP

/// The `session/update` values of a prompt with background runs, in send
/// order, for the view tests (plan.md §3.8 "Background runs").
///
/// The agent reports `running` and streams one answer in chunks. Then it
/// reports two background tool calls, sends one full agent message with a new
/// `messageId`, and reports `idle`. The agent state stays `running` from the
/// first update until the last update.
///
/// Each ``Step`` holds one update and the change that the session model
/// reports after it. A test sends each update with
/// ``ScriptedSession/send(update:)``, waits for the change, and then compares
/// the view with the model.
public enum BackgroundRunScript {
  /// A change that the session model reports after one update.
  public enum Change: Equatable, Sendable {
    /// The `agentState` is `running` (`true`), or it is not (`false`).
    case agentRunning(Bool)

    /// The agent message with the `messageId` has the text.
    case agentMessageText(messageID: String, text: String)

    /// The tool call with the title has the status.
    case toolCallStatus(title: String, status: ToolCallStatus)
  }

  /// One update of the script and the change that it makes.
  public struct Step: Sendable {
    /// The `session/update` value that the agent sends.
    public let update: SessionUpdate

    /// The change that the session model reports after the update.
    public let change: Change
  }

  /// The `messageId` of the streamed answer.
  public static let streamedMessageID = "background-streamed"

  /// The text chunks of the streamed answer, in send order.
  public static let streamedChunks = ["Starting ", "the checks."]

  /// The `messageId` of the full agent message after the tool calls.
  public static let fullMessageID = "background-full"

  /// The text of the full agent message after the tool calls.
  public static let fullMessageText = "Both checks passed."

  /// The title of the first background tool call.
  public static let buildTitle = "Build"

  /// The title of the second background tool call.
  public static let testTitle = "Test"

  /// The titles of the background tool calls, in the order of their first
  /// update.
  public static let toolTitles = [buildTitle, testTitle]

  /// The steps of the script, in send order.
  public static let steps: [Step] =
    [makeStateStep(isRunning: true)] + streamedSteps + toolCallSteps
    + [makeFullMessageStep(), makeStateStep(isRunning: false)]

  /// One step for each chunk of the streamed answer. After each chunk, the
  /// answer has the text of all the chunks up to it.
  private static var streamedSteps: [Step] {
    streamedChunks.indices.map { index in
      Step(
        update: makeChunkUpdate(messageID: streamedMessageID, text: streamedChunks[index]),
        change: .agentMessageText(messageID: streamedMessageID, text: streamedChunks[...index].joined()))
    }
  }

  /// The tool call updates: both calls start, then the build runs and
  /// completes, and then the test completes.
  private static var toolCallSteps: [Step] {
    [
      makeToolCallStep(title: buildTitle, status: .pending, isFirst: true),
      makeToolCallStep(title: testTitle, status: .pending, isFirst: true),
      makeToolCallStep(title: buildTitle, status: .inProgress, isFirst: false),
      makeToolCallStep(title: buildTitle, status: .completed, isFirst: false),
      makeToolCallStep(title: testTitle, status: .completed, isFirst: false),
    ]
  }

  /// Makes the step that changes the agent state.
  ///
  /// - Parameter isRunning: `true` for `running`, `false` for `idle`.
  /// - Returns: The step.
  private static func makeStateStep(isRunning: Bool) -> Step {
    let state: StateUpdate = isRunning ? .running(RunningStateUpdate()) : .idle(IdleStateUpdate())
    return Step(update: .stateUpdate(state), change: .agentRunning(isRunning))
  }

  /// Makes the step of the full agent message: one chunk with all the text
  /// and a new `messageId`.
  ///
  /// - Returns: The step.
  private static func makeFullMessageStep() -> Step {
    Step(
      update: makeChunkUpdate(messageID: fullMessageID, text: fullMessageText),
      change: .agentMessageText(messageID: fullMessageID, text: fullMessageText))
  }

  /// Makes one `agent_message_chunk` update with a text block. The script
  /// uses it for each of its chunks, and a view test uses it to stream an
  /// agent message of its own.
  ///
  /// - Parameters:
  ///   - messageID: The `messageId` of the agent message.
  ///   - text: The text of the chunk.
  /// - Returns: The update.
  public static func makeChunkUpdate(messageID: String, text: String) -> SessionUpdate {
    .agentMessageChunk(ContentChunk(content: .text(TextContent(text: text)), messageId: MessageId(rawValue: messageID)))
  }

  /// Makes the step of one `tool_call_update`. The title is also the
  /// `toolCallId`, so each title is one tool call.
  ///
  /// - Parameters:
  ///   - title: The title of the tool call.
  ///   - status: The new status of the tool call.
  ///   - isFirst: `true` for the first update of the tool call, which also
  ///     gives the title. A later update gives only the status.
  /// - Returns: The step.
  private static func makeToolCallStep(title: String, status: ToolCallStatus, isFirst: Bool) -> Step {
    let update = ToolCallUpdate(
      toolCallId: ToolCallId(rawValue: title),
      status: .value(status),
      title: isFirst ? .value(title) : .unchanged)
    return Step(update: .toolCallUpdate(update), change: .toolCallStatus(title: title, status: status))
  }
}
