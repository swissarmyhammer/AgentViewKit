#if DEBUG
  import AgentViewKit
  import AgentViewKitTestSupport
  import SwiftUI
  import Testing

  /// The value that the counted test view shows.
  @Observable
  final class CountedValue {
    /// The text to show.
    var text = "one"
  }

  /// A view that notes each evaluation of its body.
  struct CountedView: View {
    /// The counter key of the view.
    let key: String
    /// The value to show.
    let value: CountedValue

    var body: some View {
      BodyEvaluationCounter.note(key)
      return Text(value.text)
    }
  }

  @Suite(.hostedSerially) @MainActor struct BodyEvaluationCounterTests {
    @Test func noteIncrementsAndResetClears() {
      let key = "counter-unit-row-1"
      BodyEvaluationCounter.reset(key)

      BodyEvaluationCounter.note(key)
      BodyEvaluationCounter.note(key)

      #expect(BodyEvaluationCounter.count(key) == 2)
      BodyEvaluationCounter.reset(key)
      #expect(BodyEvaluationCounter.count(key) == 0)
    }

    @Test func resetWithAPrefixKeepsOtherKeys() {
      BodyEvaluationCounter.note("counter-prefix-a-1")
      BodyEvaluationCounter.note("counter-prefix-a-2")
      BodyEvaluationCounter.note("counter-prefix-b-1")

      BodyEvaluationCounter.reset(prefix: "counter-prefix-a-")

      #expect(BodyEvaluationCounter.count("counter-prefix-a-1") == 0)
      #expect(BodyEvaluationCounter.count("counter-prefix-a-2") == 0)
      #expect(BodyEvaluationCounter.count("counter-prefix-b-1") == 1)
      BodyEvaluationCounter.reset(prefix: "counter-prefix-")
    }

    @Test func countIncrementsWhenTheViewEvaluatesAgain() {
      let key = "counter-hosted-row-1"
      BodyEvaluationCounter.reset(key)
      let value = CountedValue()
      let harness = HostedViewHarness(CountedView(key: key, value: value))
      defer { harness.close() }
      harness.pump()
      let first = BodyEvaluationCounter.count(key)

      value.text = "two"
      harness.pump()

      #expect(first >= 1)
      #expect(BodyEvaluationCounter.count(key) > first)
      #expect(harness.accessibilityElements().contains { $0.label == "two" })
      BodyEvaluationCounter.reset(key)
    }
  }
#endif
