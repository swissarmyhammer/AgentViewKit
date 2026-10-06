import AgentViewKitTestSupport
import Observation
import Testing

/// Tests for ``ChangeFlag/observing(_:when:)``.
@Suite @MainActor struct ChangeFlagTests {
  /// An observable value and a gate that the observation does not read.
  ///
  /// The probe is main actor isolated, so the `@Sendable` condition can
  /// capture it, as the hosted tests capture a `SessionModel`.
  @MainActor @Observable final class Probe {
    /// The value that the observation reads.
    var value = 0

    /// The value that the condition reads when `value` changes.
    @ObservationIgnored var isOpen = false
  }

  /// Makes a flag over `probe.value` that is set only when the gate of `probe`
  /// is open at the change.
  ///
  /// - Parameter probe: The probe to observe.
  /// - Returns: A flag that is not set yet.
  static func flagWhenOpen(_ probe: Probe) -> ChangeFlag {
    ChangeFlag.observing {
      _ = probe.value
    } when: {
      MainActor.assumeIsolated { probe.isOpen }
    }
  }

  @Test func aChangeSetsTheFlagWithNoCondition() {
    let probe = Probe()
    let changed = ChangeFlag.observing { _ = probe.value }

    probe.value += 1

    #expect(changed.value)
  }

  @Test func aChangeSetsTheFlagWhenTheConditionIsTrueAtTheChange() {
    let probe = Probe()
    let changed = Self.flagWhenOpen(probe)

    probe.isOpen = true
    probe.value += 1

    #expect(changed.value)
  }

  @Test func aChangeLeavesTheFlagClearWhenTheConditionIsFalseAtTheChange() {
    let probe = Probe()
    probe.isOpen = true
    let changed = Self.flagWhenOpen(probe)

    probe.isOpen = false
    probe.value += 1

    #expect(!changed.value)
  }
}
