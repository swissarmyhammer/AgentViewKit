import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// A bar that tells the user the state of the agent (plan.md §3.8 "Agent
/// state and stop reasons", §9 A). The bar is a ``StatusBar``, so it is on
/// the content surface of the kit.
///
/// ``init(session:onShowError:)`` binds the bar to a `SessionModel`. The
/// body reads `SessionModel.agentState` directly, and the bar shows one
/// message for each value: `.running`, `.idle` with its stop reason,
/// `.requiresAction`, and a general message for a state that the kit does not
/// know (`.unknown`). A new value replaces the message. While the model has
/// no state, the view is empty. A stop reason that the ACP standard does not
/// name shows the text from ``extensionStopReasonMessages``, or a general
/// text with the raw value (plan.md §3.8 "Agent state and stop reasons").
/// The stop reason `error` shows the `message` of the `error` object of the
/// idle state, when the agent gives one. The `message(for:)` function that
/// takes a `StateUpdate` gives the text of each value.
///
/// The body also reads the pending requests of the model. While the state is
/// `.idle` and a permission request or an elicitation waits for the user,
/// the bar shows the `.requiresAction` text, because an agent can report
/// idle while its requests wait.
///
/// The bar has the identifier ``bannerIdentifier``. The text of the bar has
/// the ``Message/identifier`` of its message.
///
/// The bar shows a Show Error button when the host gives an `onShowError`
/// closure and the transcript has an error. That error is the last
/// `ErrorEntry` in `SessionModel.transcript`; the kit keeps no error list.
/// The host uses the closure to move the conversation to the `ErrorView` of
/// that error.
public struct StateBanner: View {
  /// The accessibility identifier of the bar.
  public static let bannerIdentifier = "state-banner"

  /// The accessibility identifier of the Show Error button.
  public static let showErrorIdentifier = "state-banner-show-error"

  /// The symbol of the Show Error button.
  static let showErrorSymbol = SharedSymbol.details

  /// The text that the bar shows for one state.
  public struct Message: Equatable, Sendable {
    /// The short title of the bar.
    public let title: String

    /// The explanation below the title.
    public let explanation: String

    /// The SF Symbol name of the bar.
    public let symbolName: String

    /// The accessibility identifier of the text of the bar. Each message has
    /// a different identifier.
    public let identifier: String

    /// Whether the message tells of a failure, such as an idle state with
    /// the stop reason `error`, or a failed connection.
    ///
    /// Each concept has one symbol in the kit, so a message whose symbol is
    /// the error symbol tells of a failure. The bar shows the symbol of a
    /// failure with the error color of the EditorKit theme.
    var isFailure: Bool {
      symbolName == SharedSymbol.error
    }

    /// The symbols of the messages of work that goes on: an agent that runs,
    /// and a history that the agent sends again.
    static let ongoingSymbols: Set<String> = [SharedSymbol.inProgress, SharedSymbol.replaying]

    /// Whether the message tells of work that goes on, such as an agent that
    /// runs or a replay of the history.
    ///
    /// Each concept has one symbol in the kit, so the symbol of the message
    /// tells the concept. The bar animates the symbol of such a message with
    /// a symbol effect, except under Reduce Motion.
    var isOngoing: Bool {
      Self.ongoingSymbols.contains(symbolName)
    }
  }

  /// The session model whose `agentState` the bar shows.
  let session: SessionModel

  /// The host closure that shows an error entry of the transcript, or `nil`.
  let onShowError: ((TranscriptEntry.ID) -> Void)?

  /// Makes the bar of the agent state of a session model.
  ///
  /// - Parameters:
  ///   - session: The session model whose `agentState` the bar shows.
  ///   - onShowError: The host closure that shows an error entry, or `nil`
  ///     for no Show Error button. It gets the identity of the last
  ///     `ErrorEntry` of the transcript.
  public init(session: SessionModel, onShowError: ((TranscriptEntry.ID) -> Void)? = nil) {
    self.session = session
    self.onShowError = onShowError
  }

  /// The text of the bar for an agent state of a session model.
  ///
  /// - Parameter state: The `agentState` of a session model.
  /// - Returns: The text. Each state has a text, and a state that the kit
  ///   does not know gives a general text with its wire value.
  public static func message(for state: StateUpdate) -> Message {
    switch state {
    case .running:
      runningMessage
    case .requiresAction:
      requiresActionMessage
    case .idle(let idle):
      message(forIdle: idle)
    case .unknown(let wireValue, _):
      Message(
        title: String(localized: "The agent reported an unknown state", bundle: .module),
        explanation: String(localized: "The agent sent the state \(wireValue).", bundle: .module),
        symbolName: SharedSymbol.unknown,
        identifier: "state-banner-state-unknown")
    }
  }

  /// The text of the bar for an agent state and the pending requests of its
  /// session.
  ///
  /// An agent can report idle while its requests wait for the user:
  /// FoundationModelsACPAgent never sends `requires_action`. Then the bar
  /// shows the text of `.requiresAction`, the text of a request that waits
  /// for the user. Each other case shows the text of ``message(for:)``, so
  /// the `.requiresAction` state of other agents keeps its text.
  ///
  /// - Parameters:
  ///   - state: The `agentState` of a session model.
  ///   - hasPendingRequests: Whether a permission request or an elicitation
  ///     of the session waits for the answer of the user.
  /// - Returns: The text.
  static func message(for state: StateUpdate, hasPendingRequests: Bool) -> Message {
    guard hasPendingRequests, case .idle = state else { return message(for: state) }
    return requiresActionMessage
  }

  /// The text of the bar for an idle agent.
  ///
  /// - Parameter idle: The idle state, with its optional stop reason and its
  ///   optional error object.
  /// - Returns: The text of the stop reason.
  private static func message(forIdle idle: IdleStateUpdate) -> Message {
    switch idle.stopReason {
    case nil:
      readyMessage
    case .endTurn:
      turnCompleteMessage
    case .cancelled:
      cancelledMessage
    case .maxTokens:
      maxTokensMessage
    case .maxTurnRequests:
      maxTurnRequestsMessage
    case .refusal:
      refusalMessage
    case .error:
      failedTurnMessage(error: idle.error)
    case .unknown(let wireValue):
      message(forUnknownStopReason: wireValue)
    }
  }

  public var body: some View {
    if let state = session.agentState {
      bar(
        Self.message(for: state, hasPendingRequests: AgentCommandTarget.hasPendingRequests(session)),
        showError: Self.makeShowErrorAction(in: session, onShowError))
    }
  }

  /// The bar of one message.
  ///
  /// - Parameters:
  ///   - message: The text of the bar.
  ///   - showError: The closure of the Show Error button, or `nil` for no
  ///     button.
  /// - Returns: The bar.
  private func bar(_ message: Message, showError: (() -> Void)?) -> some View {
    StatusBar(
      message: message,
      action: showError.map {
        StatusBar.Action(
          title: String(localized: "Show Error", bundle: .module),
          systemImage: Self.showErrorSymbol,
          identifier: Self.showErrorIdentifier, isEnabled: true, perform: $0)
      }
    )
    .accessibilityIdentifier(Self.bannerIdentifier)
  }

  /// Makes the closure of the Show Error button of a session model.
  ///
  /// - Parameters:
  ///   - session: The session model. The closure gives the last `ErrorEntry`
  ///     of its transcript.
  ///   - onShowError: The host closure, or `nil`.
  /// - Returns: The closure, or `nil` when the host gave no closure or the
  ///   transcript has no error entry.
  private static func makeShowErrorAction(
    in session: SessionModel, _ onShowError: ((TranscriptEntry.ID) -> Void)?
  ) -> (() -> Void)? {
    guard let onShowError, let lastError = session.transcript.last(where: \.isError) else { return nil }
    let id = lastError.id
    return { onShowError(id) }
  }
}

extension StateBanner {
  /// The text for an agent that runs. The agent can run with no prompt open,
  /// for example for background work or a compaction.
  private static let runningMessage = Message(
    title: String(localized: "The agent is working", bundle: .module),
    explanation: String(localized: "Wait for the result, or stop the work.", bundle: .module),
    symbolName: SharedSymbol.inProgress,
    identifier: "state-banner-running")

  /// The text for an idle agent that gave no stop reason.
  private static let readyMessage = Message(
    title: String(localized: "The agent is ready", bundle: .module),
    explanation: String(localized: "Send a message to the agent.", bundle: .module),
    symbolName: SharedSymbol.completed,
    identifier: "state-banner-ready")

  /// The text for an idle state with the stop reason `end_turn`.
  private static let turnCompleteMessage = Message(
    title: String(localized: "The response is complete", bundle: .module),
    explanation: String(
      localized: "The agent finished the response. Send a message to continue.", bundle: .module),
    symbolName: SharedSymbol.completed,
    identifier: "state-banner-end-turn")

  /// The text for an idle state with the stop reason `cancelled`.
  private static let cancelledMessage = Message(
    title: String(localized: "The response was cancelled", bundle: .module),
    explanation: String(
      localized: "The agent stopped the work because of the cancel request.", bundle: .module),
    symbolName: SharedSymbol.cancelled,
    identifier: "state-banner-cancelled")

  /// The text for an agent that waits for the user: the `.requiresAction`
  /// state, or an idle state while a request of the session waits for the
  /// answer of the user.
  private static let requiresActionMessage = Message(
    title: String(localized: "The agent needs your input", bundle: .module),
    explanation: String(
      localized: "Answer the request to let the agent continue.", bundle: .module),
    symbolName: SharedSymbol.userAction,
    identifier: "state-banner-requires-action")

  /// The text for an idle state with the stop reason `max_tokens`.
  private static let maxTokensMessage = Message(
    title: String(localized: "The response is incomplete", bundle: .module),
    explanation: String(
      localized: "The model used its maximum number of output tokens. Ask it to continue.",
      bundle: .module),
    symbolName: SharedSymbol.maxTokens,
    identifier: "state-banner-max-tokens")

  /// The text for an idle state with the stop reason `max_turn_requests`.
  private static let maxTurnRequestsMessage = Message(
    title: String(localized: "The response reached its request limit", bundle: .module),
    explanation: String(
      localized: "The response used its maximum number of model requests. Send a message to continue.",
      bundle: .module),
    symbolName: SharedSymbol.maxTurnRequests,
    identifier: "state-banner-max-turn-requests")

  /// The text for an idle state with the stop reason `refusal`.
  private static let refusalMessage = Message(
    title: String(localized: "The model refused to continue", bundle: .module),
    explanation: String(localized: "Change the request and send it again.", bundle: .module),
    symbolName: SharedSymbol.refusal,
    identifier: "state-banner-refusal")

  /// The accessibility identifier of the text for an idle state with the
  /// stop reason `error`.
  public static let failedTurnIdentifier = "state-banner-error"

  /// The text for an idle state with the stop reason `error` (ACP schema
  /// alpha.8).
  ///
  /// - Parameter error: The error object of the idle state, or `nil` when the
  ///   agent gave none.
  /// - Returns: The text. When the agent gave an error object, the
  ///   explanation shows its `message`.
  private static func failedTurnMessage(error: ACPError?) -> Message {
    Message(
      title: String(localized: "The response failed", bundle: .module),
      explanation: error.map {
        String(localized: "The agent reported this failure: \($0.message)", bundle: .module)
      }
        ?? String(
          localized: "The response stopped because of a failure in the agent. Send the request again.",
          bundle: .module),
      symbolName: SharedSymbol.error,
      identifier: failedTurnIdentifier)
  }
}

extension TranscriptEntry {
  /// Whether the entry is an `ErrorEntry`.
  fileprivate var isError: Bool {
    guard case .error = self else { return false }
    return true
  }
}

#Preview("Agent runs") {
  StateBanner(session: .preview(transcript: [.update(.stateUpdate(.running(RunningStateUpdate())))]))
}

#Preview("Token limit") {
  StateBanner(session: .preview(transcript: [.update(.stateUpdate(.idle(IdleStateUpdate(stopReason: .maxTokens))))]))
}
