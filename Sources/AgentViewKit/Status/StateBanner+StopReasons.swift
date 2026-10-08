import Foundation

extension StateBanner {
  /// The accessibility identifier of the general bar for a stop reason that
  /// is not in ``extensionStopReasonMessages``.
  public static let unknownStopReasonIdentifier = "state-banner-stop-reason-unknown"

  /// The text of the bar for each extension stop reason that the kit knows
  /// (plan.md §3.8 "Agent state and stop reasons").
  ///
  /// The key is the raw wire value of the stop reason. The FoundationModels
  /// ACP agent sends these values (`PromptExecution`). An ACP extension value
  /// starts with `_`. The bar of an ACP stop reason that the ACP standard
  /// does not name (`StopReason.unknown`) reads this table through
  /// ``message(forUnknownStopReason:)``.
  public static let extensionStopReasonMessages: [String: Message] = [
    "_truncated": Message(
      title: String(localized: "The response was cut off"),
      explanation: String(
        localized: "The output stopped at the token limit. Ask the model to continue."),
      symbolName: "scissors",
      identifier: "state-banner-stop-reason-truncated"),
    "_ended_in_reasoning": Message(
      title: String(localized: "The model stopped during its reasoning"),
      explanation: String(
        localized: "The model did not write an answer after its reasoning. Send the request again."),
      symbolName: "brain",
      identifier: "state-banner-stop-reason-ended-in-reasoning"),
    "_repeated": Message(
      title: String(localized: "The model repeated itself"),
      explanation: String(
        localized: "The model wrote the same text again and again. Change the request."),
      symbolName: "repeat",
      identifier: "state-banner-stop-reason-repeated"),
    "_reasoning_limit": Message(
      title: String(localized: "The reasoning was too long"),
      explanation: String(
        localized: "The model used all of its reasoning tokens. Send a smaller request."),
      symbolName: "gauge.with.dots.needle.100percent",
      identifier: "state-banner-stop-reason-reasoning-limit"),
    "_error": Message(
      title: String(localized: "The agent had an error"),
      explanation: String(
        localized: "The turn stopped because of an error in the agent. Send the request again."),
      symbolName: "xmark.octagon.fill",
      identifier: "state-banner-stop-reason-error"),
    "_no_output": Message(
      title: String(localized: "The model gave no answer"),
      explanation: String(
        localized: "The turn ended, but the model wrote no text. Send the request again."),
      symbolName: "ellipsis.bubble",
      identifier: "state-banner-stop-reason-no-output"),
    "_stalled": Message(
      title: String(localized: "The response stopped"),
      explanation: String(
        localized: "The model did not write text for too long. Send the request again."),
      symbolName: "pause.circle.fill",
      identifier: "state-banner-stop-reason-stalled"),
  ]

  /// The text of the bar for a stop reason that the ACP standard does not
  /// name.
  ///
  /// - Parameter wireValue: The raw wire value of the stop reason.
  /// - Returns: The row of ``extensionStopReasonMessages`` for `wireValue`.
  ///   When the table has no row, a general text that shows `wireValue`, with
  ///   the identifier ``unknownStopReasonIdentifier``.
  public static func message(forUnknownStopReason wireValue: String) -> Message {
    extensionStopReasonMessages[wireValue]
      ?? Message(
        title: String(localized: "The turn stopped for an unknown reason"),
        explanation: String(localized: "The agent sent the stop reason \(wireValue)."),
        symbolName: "questionmark.circle.fill",
        identifier: unknownStopReasonIdentifier)
  }
}
