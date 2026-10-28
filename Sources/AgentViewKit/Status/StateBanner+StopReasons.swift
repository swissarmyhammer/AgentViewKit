import EditorStyle
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
  /// ``message(forUnknownStopReason:)``. The `_error` value is a failure, and
  /// each other value is neutral.
  public static let extensionStopReasonMessages: [String: StatusBar.Message] = [
    "_truncated": StatusBar.Message(
      title: String(localized: "The response was cut off", bundle: .module),
      explanation: String(
        localized: "The output stopped at the token limit. Ask the model to continue.",
        bundle: .module),
      symbolName: SharedSymbol.truncated,
      identifier: "state-banner-stop-reason-truncated"),
    "_ended_in_reasoning": StatusBar.Message(
      title: String(localized: "The model stopped during its reasoning", bundle: .module),
      explanation: String(
        localized: "The model did not write an answer after its reasoning. Send the request again.",
        bundle: .module),
      symbolName: SharedSymbol.reasoning,
      identifier: "state-banner-stop-reason-ended-in-reasoning"),
    "_repeated": StatusBar.Message(
      title: String(localized: "The model repeated itself", bundle: .module),
      explanation: String(
        localized: "The model wrote the same text again and again. Change the request.",
        bundle: .module),
      symbolName: SharedSymbol.repeated,
      identifier: "state-banner-stop-reason-repeated"),
    "_reasoning_limit": StatusBar.Message(
      title: String(localized: "The reasoning was too long", bundle: .module),
      explanation: String(
        localized: "The model used all of its reasoning tokens. Send a smaller request.",
        bundle: .module),
      symbolName: SharedSymbol.reasoningLimit,
      identifier: "state-banner-stop-reason-reasoning-limit"),
    "_error": StatusBar.Message(
      title: String(localized: "The agent had an error", bundle: .module),
      explanation: String(
        localized: "The response stopped because of an error in the agent. Send the request again.",
        bundle: .module),
      symbolName: SharedSymbol.error,
      identifier: "state-banner-stop-reason-error", severity: .failure),
    "_no_output": StatusBar.Message(
      title: String(localized: "The model gave no answer", bundle: .module),
      explanation: String(
        localized: "The response ended, but the model wrote no text. Send the request again.",
        bundle: .module),
      symbolName: SharedSymbol.noOutput,
      identifier: "state-banner-stop-reason-no-output"),
    "_stalled": StatusBar.Message(
      title: String(localized: "The response stopped", bundle: .module),
      explanation: String(
        localized: "The model did not write text for too long. Send the request again.",
        bundle: .module),
      symbolName: SharedSymbol.stalled,
      identifier: "state-banner-stop-reason-stalled"),
  ]

  /// The text of the bar for a stop reason that the ACP standard does not
  /// name.
  ///
  /// - Parameter wireValue: The raw wire value of the stop reason.
  /// - Returns: The row of ``extensionStopReasonMessages`` for `wireValue`.
  ///   When the table has no row, a general text that shows `wireValue`, with
  ///   the identifier ``unknownStopReasonIdentifier``.
  public static func message(forUnknownStopReason wireValue: String) -> StatusBar.Message {
    extensionStopReasonMessages[wireValue]
      ?? StatusBar.Message(
        title: String(localized: "The response stopped for an unknown reason", bundle: .module),
        explanation: String(
          localized: "The agent sent the stop reason \(wireValue).", bundle: .module),
        symbolName: ItemStatus.unknown.systemImage,
        identifier: unknownStopReasonIdentifier)
  }
}
