import AgentViewKit
import AgentViewKitFoundationModels
import Foundation
import FoundationModels
import Testing

@Suite struct SessionErrorMappingTests {
  /// The debug description of each sample error.
  static let debugText = "The model stopped."

  /// The reset time of the rate limit sample.
  static let resetDate = Date(timeIntervalSince1970: 60)

  /// An error that is not a `LanguageModelError`.
  struct OtherError: Error, CustomStringConvertible {
    var description: String { "Other failure" }
  }

  @Test func contextSizeExceededKeepsBothCounts() {
    let error = LanguageModelError.contextSizeExceeded(
      .init(contextSize: 10, tokenCount: 20, debugDescription: Self.debugText))

    #expect(SessionErrorMapping.kind(for: error) == .contextSizeExceeded(contextSize: 10, tokenCount: 20))
  }

  @Test func rateLimitedKeepsTheResetDate() {
    let error = LanguageModelError.rateLimited(
      .init(resetDate: Self.resetDate, debugDescription: Self.debugText))

    #expect(SessionErrorMapping.kind(for: error) == .rateLimited(resetAt: Self.resetDate))
  }

  @Test func guardrailViolationKeepsTheDescription() {
    let error = LanguageModelError.guardrailViolation(.init(debugDescription: Self.debugText))

    #expect(SessionErrorMapping.kind(for: error) == .guardrailViolation(explanation: Self.debugText))
  }

  @Test func refusalKeepsTheDescription() {
    let error = LanguageModelError.refusal(
      .init(explanation: "No.", debugDescription: Self.debugText))

    #expect(SessionErrorMapping.kind(for: error) == .refusal(explanation: Self.debugText))
  }

  @Test func timeoutIsATimeout() {
    let error = LanguageModelError.timeout(.init(debugDescription: Self.debugText))

    #expect(SessionErrorMapping.kind(for: error) == .timeout)
  }

  @Test func anUnsupportedCaseIsUnknownWithTheDebugDescription() {
    let errors: [LanguageModelError] = [
      .unsupportedCapability(.init(capability: .vision, debugDescription: Self.debugText)),
      .unsupportedTranscriptContent(.init(unsupportedContent: [], debugDescription: Self.debugText)),
      .unsupportedGenerationGuide(.init(schemaName: nil, debugDescription: Self.debugText)),
      .unsupportedLanguageOrLocale(
        .init(languageCode: Locale.LanguageCode("xx"), debugDescription: Self.debugText)),
    ]

    for error in errors {
      #expect(SessionErrorMapping.kind(for: error) == .unknown(message: error.debugDescription))
    }
  }

  @Test func anotherErrorIsUnknownWithItsDescription() {
    #expect(SessionErrorMapping.kind(for: OtherError()) == .unknown(message: "Other failure"))
  }
}
