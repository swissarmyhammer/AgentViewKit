import EditorCommandsUI
import Observation

@testable import AgentViewKit

/// Records each value that a view gives to an ``ObservationReport``.
///
/// The class is `@Observable`, so that a test can wait for a report with
/// `ObservationWait.until` or `HostedViewHarness.render(when:)`, with no
/// clock. A test can also give ``report`` to a closure of the kit, such as
/// the scroll closure of a `ScrollAnchorManager`, to record the values that
/// the closure gets.
@MainActor @Observable final class ReportRecorder<Value> {
  /// Each reported value, in report order.
  private(set) var values: [Value] = []

  /// The report that gives each value to this recorder.
  var report: ObservationReport<Value> {
    ObservationReport { self.values.append($0) }
  }
}
