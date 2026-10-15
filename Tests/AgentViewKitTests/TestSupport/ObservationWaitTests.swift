import AgentViewKitTestSupport
import Observation
import Testing

/// Tests for ``ObservationWait/until(_:)``.
@Suite @MainActor struct ObservationWaitTests {
  /// An observable value.
  @MainActor @Observable final class Probe {
    /// The value that the predicate reads.
    var value = 0
  }

  /// The value that the predicate of the change test waits for.
  static let target = 2

  @Test func theWaitReturnsAtOnceWhenThePredicateIsTrue() async {
    let probe = Probe()

    await ObservationWait.until { probe.value == 0 }

    #expect(probe.value == 0)
  }

  @Test func theWaitResumesAfterTheChangesThatMakeThePredicateTrue() async {
    let probe = Probe()
    // The task runs when the wait suspends: the first change resumes the
    // wait, and the wait reads the predicate again after the second change.
    let writer = Task { @MainActor in
      probe.value = 1
      probe.value = Self.target
    }

    await ObservationWait.until { probe.value == Self.target }

    #expect(probe.value == Self.target)
    await writer.value
  }
}
