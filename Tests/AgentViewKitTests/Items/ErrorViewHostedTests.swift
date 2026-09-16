import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import SwiftUI
import Testing

/// Hosted tests of ``ErrorView`` and ``ErrorActions``.
@Suite(.serialized) @MainActor struct ErrorViewHostedTests {
  /// The longest time that a test waits for an action closure, in seconds.
  static let callWaitSeconds: TimeInterval = 1

  /// The number of tokens that the context of the test model can hold.
  nonisolated static let contextSize = 4_096

  /// The number of tokens in the test request that is too large.
  nonisolated static let tokenCount = 5_000

  /// The JSON-RPC code of the test ACP error.
  nonisolated static let acpCode = -32_603

  /// The reset time of the test rate limit, in seconds after 1970.
  nonisolated static let resetSeconds: TimeInterval = 1_800_000_000

  /// Records the calls of each error action.
  final class ActionCalls {
    /// The identifiers of the errors that each action got, by action.
    var calls: [ErrorView.Action: [String]] = [:]

    /// Actions that record each call, with `nil` for each action in
    /// `omitted`.
    ///
    /// - Parameter omitted: The actions that the host does not give.
    /// - Returns: The actions.
    func actions(omitting omitted: Set<ErrorView.Action> = []) -> ErrorActions {
      func record(_ action: ErrorView.Action) -> ErrorActions.Handler? {
        guard !omitted.contains(action) else { return nil }
        return { (error: ThreadError) in
          self.calls[action, default: []].append(error.id)
        }
      }
      return ErrorActions(
        compact: record(.compact), retry: record(.retry), rephrase: record(.rephrase))
    }
  }

  /// One error kind with the parts that the view must show for it.
  nonisolated struct Case: Sendable, CustomTestStringConvertible {
    /// The error kind.
    let kind: ThreadError.Kind
    /// The expected accessibility identifier of the card.
    let identifier: String
    /// The expected title of the action button, or `nil` for no button.
    let buttonTitle: String?
    /// Texts that the detail must contain.
    let detailParts: [String]

    var testDescription: String { identifier }
  }

  /// Each error kind.
  nonisolated static let cases: [Case] = [
    Case(
      kind: .contextSizeExceeded(contextSize: contextSize, tokenCount: tokenCount),
      identifier: "error-contextSizeExceeded", buttonTitle: "Compact",
      detailParts: [contextSize.formatted(), tokenCount.formatted()]),
    Case(
      kind: .rateLimited(resetAt: Date(timeIntervalSince1970: resetSeconds)),
      identifier: "error-rateLimited", buttonTitle: "Retry",
      detailParts: [
        Date(timeIntervalSince1970: resetSeconds).formatted(date: .abbreviated, time: .shortened)
      ]),
    Case(
      kind: .rateLimited(resetAt: nil), identifier: "error-rateLimited", buttonTitle: "Retry",
      detailParts: []),
    Case(
      kind: .guardrailViolation(explanation: "The request names a weapon."),
      identifier: "error-guardrailViolation", buttonTitle: "Rephrase",
      detailParts: ["The request names a weapon."]),
    Case(
      kind: .guardrailViolation(explanation: nil), identifier: "error-guardrailViolation",
      buttonTitle: "Rephrase", detailParts: []),
    Case(
      kind: .refusal(explanation: "I cannot help with that."), identifier: "error-refusal",
      buttonTitle: "Rephrase", detailParts: ["I cannot help with that."]),
    Case(kind: .timeout, identifier: "error-timeout", buttonTitle: "Retry", detailParts: []),
    Case(
      kind: .acp(code: acpCode, message: "Internal error"), identifier: "error-acp",
      buttonTitle: nil, detailParts: [String(acpCode), "Internal error"]),
    Case(
      kind: .unknown(message: "The disk is full."), identifier: "error-unknown", buttonTitle: nil,
      detailParts: ["The disk is full."]),
  ]

  /// Mounts an error view with the actions.
  static func mount(
    _ error: ThreadError,
    actions: ErrorActions
  ) -> HostedViewHarness<some View> {
    let harness = HostedViewHarness(ErrorView(error: error).errorActions(actions))
    harness.pump()
    return harness
  }

  @Test(arguments: cases)
  func eachKindMountsItsIdentifierLabelAndButton(_ testCase: Case) {
    let error = ThreadError(id: "error-1", kind: testCase.kind)
    let harness = Self.mount(error, actions: ActionCalls().actions())
    defer { harness.close() }

    #expect(ErrorView.identifier(for: testCase.kind) == testCase.identifier)
    let card = harness.element(identifier: testCase.identifier)
    #expect(card != nil, "The card of \(testCase.identifier) is missing.")

    let content = ErrorView.content(for: testCase.kind)
    #expect(card?.label == "\(content.title), \(content.detail)")
    #expect(!content.detail.isEmpty)
    for part in testCase.detailParts {
      #expect(content.detail.contains(part), "The detail does not contain \(part).")
    }

    let buttons = ErrorView.Action.allCases.compactMap {
      harness.element(identifier: ErrorView.actionIdentifier(for: $0))
    }
    if let title = testCase.buttonTitle {
      #expect(buttons.count == 1)
      #expect(buttons.first?.label == title)
    } else {
      #expect(buttons.isEmpty)
    }
  }

  @Test func eachKindHasADistinctTitle() {
    let kinds = Set(Self.cases.map(\.identifier))
    let titles = Set(Self.cases.map { ErrorView.content(for: $0.kind).title })
    #expect(titles.count == kinds.count)
  }

  @Test func aNilCompactActionHidesTheCompactButton() {
    let error = ThreadError(
      id: "error-1",
      kind: .contextSizeExceeded(contextSize: Self.contextSize, tokenCount: Self.tokenCount))
    let harness = Self.mount(error, actions: ActionCalls().actions(omitting: [.compact]))
    defer { harness.close() }

    #expect(harness.element(identifier: "error-contextSizeExceeded") != nil)
    #expect(harness.element(identifier: ErrorView.actionIdentifier(for: .compact)) == nil)
  }

  @Test func theDefaultActionsShowNoButton() {
    let harness = HostedViewHarness(ErrorView(error: ThreadError(id: "error-1", kind: .timeout)))
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: "error-timeout") != nil)
    #expect(harness.element(identifier: ErrorView.actionIdentifier(for: .retry)) == nil)
  }

  @Test func tappingRetryCallsTheClosureOnce() async throws {
    let calls = ActionCalls()
    let harness = Self.mount(ThreadError(id: "error-7", kind: .timeout), actions: calls.actions())
    defer { harness.close() }

    try harness.press(identifier: ErrorView.actionIdentifier(for: .retry))
    await harness.pump(until: Self.callWaitSeconds) { calls.calls[.retry] != nil }

    #expect(calls.calls == [.retry: ["error-7"]])
  }

  @Test func aPatchOfTheKindChangesTheCard() {
    let error = ThreadError(id: "error-1", kind: .timeout)
    let harness = Self.mount(error, actions: ActionCalls().actions())
    defer { harness.close() }

    error.kind = .unknown(message: "The disk is full.")
    harness.pump()

    #expect(harness.element(identifier: "error-timeout") == nil)
    #expect(harness.element(identifier: "error-unknown") != nil)
  }

  @Test func anErrorItemRowShowsTheErrorView() {
    let thread = AgentThread()
    thread.apply(.insert(.error(ThreadError(id: "error-1", kind: .timeout)), after: nil))
    let harness = HostedViewHarness(AgentThreadView(thread: thread))
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: "error-timeout") != nil)
    #expect(harness.element(identifier: ItemRow.placeholderIdentifier(for: "error-1")) == nil)
  }
}
