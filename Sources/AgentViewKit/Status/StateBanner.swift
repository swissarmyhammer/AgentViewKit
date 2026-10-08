import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// A glass bar that tells the user the state of the agent (plan.md §3.8
/// "Agent state and stop reasons", §9 A).
///
/// ``init(session:onShowError:)`` binds the bar to a `SessionModel`. The
/// body reads `SessionModel.agentState` directly, and the bar shows one
/// message for each value: `.running`, `.idle` with its stop reason,
/// `.requiresAction`, and a general message for a state that the kit does not
/// know (`.unknown`). A new value replaces the message. While the model has
/// no state, the view is empty. A stop reason that the ACP standard does not
/// name shows the text from ``extensionStopReasonMessages``, or a general
/// text with the raw value (plan.md §3.8 "Agent state and stop reasons").
/// The `message(for:)` function that takes a `StateUpdate` gives the text of
/// each value.
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
      message(forStopReason: idle.stopReason)
    case .unknown(let wireValue, _):
      Message(
        title: String(localized: "The agent reported an unknown state"),
        explanation: String(localized: "The agent sent the state \(wireValue)."),
        symbolName: "questionmark.circle.fill",
        identifier: "state-banner-state-unknown")
    }
  }

  /// The text of the bar for an idle agent.
  ///
  /// - Parameter reason: The stop reason of the idle state, or `nil` when the
  ///   agent gave none.
  /// - Returns: The text of the stop reason.
  private static func message(forStopReason reason: FoundationModelsACP.StopReason?) -> Message {
    switch reason {
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
    case .unknown(let wireValue):
      message(forUnknownStopReason: wireValue)
    }
  }

  public var body: some View {
    if let state = session.agentState {
      bar(Self.message(for: state), showError: Self.makeShowErrorAction(in: session, onShowError))
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
          title: String(localized: "Show Error"), identifier: Self.showErrorIdentifier, isEnabled: true,
          perform: $0)
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
  /// The text for an agent that runs a turn.
  private static let runningMessage = Message(
    title: String(localized: "The agent is working"),
    explanation: String(localized: "The agent runs the turn. Wait for the answer, or stop the turn."),
    symbolName: "ellipsis.circle.fill",
    identifier: "state-banner-running")

  /// The text for an idle agent that gave no stop reason.
  private static let readyMessage = Message(
    title: String(localized: "The agent is ready"),
    explanation: String(localized: "Send a message to start a turn."),
    symbolName: "checkmark.circle",
    identifier: "state-banner-ready")

  /// The text for a turn that ended with `end_turn`.
  private static let turnCompleteMessage = Message(
    title: String(localized: "The turn is complete"),
    explanation: String(localized: "The agent finished the turn. Send a message to continue."),
    symbolName: "checkmark.circle.fill",
    identifier: "state-banner-end-turn")

  /// The text for a turn that ended with `cancelled`.
  private static let cancelledMessage = Message(
    title: String(localized: "The turn was cancelled"),
    explanation: String(localized: "The agent stopped the turn because of the cancel request."),
    symbolName: "stop.circle.fill",
    identifier: "state-banner-cancelled")

  /// The text for an agent that waits for the user.
  private static let requiresActionMessage = Message(
    title: String(localized: "The agent needs your input"),
    explanation: String(localized: "Answer the request to let the agent continue."),
    symbolName: "hand.raised.fill",
    identifier: "state-banner-requires-action")

  /// The text for a turn that ended with `max_tokens`.
  private static let maxTokensMessage = Message(
    title: String(localized: "The response is incomplete"),
    explanation: String(
      localized: "The model used its maximum number of output tokens. Ask it to continue."),
    symbolName: "text.badge.xmark",
    identifier: "state-banner-max-tokens")

  /// The text for a turn that ended with `max_turn_requests`.
  private static let maxTurnRequestsMessage = Message(
    title: String(localized: "The turn stopped"),
    explanation: String(
      localized: "The turn used its maximum number of model requests. Send a message to continue."),
    symbolName: "arrow.trianglehead.2.clockwise.rotate.90",
    identifier: "state-banner-max-turn-requests")

  /// The text for a turn that ended with `refusal`.
  private static let refusalMessage = Message(
    title: String(localized: "The model refused to continue"),
    explanation: String(localized: "Change the request and send it again."),
    symbolName: "exclamationmark.bubble.fill",
    identifier: "state-banner-refusal")
}

extension TranscriptEntry {
  /// Whether the entry is an `ErrorEntry`.
  fileprivate var isError: Bool {
    guard case .error = self else { return false }
    return true
  }
}
