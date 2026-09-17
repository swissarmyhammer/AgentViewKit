import AgentViewKit
import FoundationModels

/// Changes a FoundationModels error into a thread error kind
/// (plan.md §3.3, §9 A2).
///
/// Each function is pure.
public enum SessionErrorMapping {
  /// The kind of a thread error for an error of a turn.
  ///
  /// - Parameter error: The error that the session threw.
  /// - Returns: The kind with the payload of a `LanguageModelError` case.
  ///   Another error gives ``AgentViewKit/ThreadError/Kind/unknown(message:)``
  ///   with the description of the error.
  public static func kind(for error: any Error) -> ThreadError.Kind {
    guard let modelError = error as? LanguageModelError else {
      return .unknown(message: String(describing: error))
    }
    return kind(for: modelError)
  }

  /// The kind of a thread error for a `LanguageModelError`.
  ///
  /// - Parameter error: The error of the model.
  /// - Returns: The kind with the payload of the case. A case that the kit
  ///   has no kind for gives
  ///   ``AgentViewKit/ThreadError/Kind/unknown(message:)`` with the debug
  ///   description of the error.
  static func kind(for error: LanguageModelError) -> ThreadError.Kind {
    switch error {
    case .contextSizeExceeded(let payload):
      .contextSizeExceeded(contextSize: payload.contextSize, tokenCount: payload.tokenCount)
    case .rateLimited(let payload):
      .rateLimited(resetAt: payload.resetDate)
    case .guardrailViolation(let payload):
      .guardrailViolation(explanation: payload.debugDescription)
    case .refusal(let payload):
      .refusal(explanation: payload.debugDescription)
    case .timeout:
      .timeout
    case .unsupportedCapability, .unsupportedTranscriptContent, .unsupportedGenerationGuide,
      .unsupportedLanguageOrLocale:
      .unknown(message: error.debugDescription)
    @unknown default:
      .unknown(message: error.debugDescription)
    }
  }
}
