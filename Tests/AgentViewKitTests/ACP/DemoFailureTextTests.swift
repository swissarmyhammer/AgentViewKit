import Foundation
import Testing

@testable import AgentViewKitDemoSupport

/// The tests of ``DemoFailureText``: the text of a failed request of a demo
/// tab.
@Suite struct DemoFailureTextTests {
  /// An error with a localized description.
  struct DescribedError: LocalizedError {
    /// The text of the error.
    var errorDescription: String? { DemoFailureTextTests.describedText }
  }

  /// An error with no localized description.
  enum PlainError: Error {
    /// The one case of the error.
    case plainCase
  }

  /// The localized description of ``DescribedError``. The error reads it
  /// outside the main actor.
  nonisolated static let describedText = "The request failed."

  @Test func anErrorWithALocalizedDescriptionGivesThatDescription() {
    #expect(DemoFailureText.text(of: DescribedError()) == Self.describedText)
  }

  @Test func anErrorWithNoLocalizedDescriptionGivesItsDescription() {
    #expect(DemoFailureText.text(of: PlainError.plainCase) == String(describing: PlainError.plainCase))
  }
}
