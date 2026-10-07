import AgentViewKit
import Testing

/// Tests of the card content of ``ErrorView``. The hosted tests of the error
/// rows of a session are in `SessionEntryRowsHostedTests`.
@Suite struct ErrorViewContentTests {
  /// The JSON-RPC code of the test ACP error.
  static let acpCode = -32_603

  @Test func theContentShowsTheCodeAndTheMessage() {
    let content = ErrorView.content(code: Self.acpCode, message: "The disk is full.")

    #expect(content.title == "The agent sent an error")
    #expect(content.detail == "Error -32603: The disk is full.")
    #expect(content.symbolName == "exclamationmark.triangle.fill")
  }

  @Test func differentCodesGiveDifferentDetails() {
    let first = ErrorView.content(code: Self.acpCode, message: "failed")
    let second = ErrorView.content(code: Self.acpCode - 1, message: "failed")

    #expect(first.title == second.title)
    #expect(first.detail != second.detail)
  }
}
