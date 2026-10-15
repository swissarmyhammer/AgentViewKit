import Observation

@testable import AgentViewKit

/// Records each value that a view gives to an ``ObservationReport``.
///
/// The class is `@Observable`, so that a test can wait for a report with
/// `ObservationWait.until` or `HostedViewHarness.render(when:)`, with no
/// clock. `SourcesViewHostedTests` and `WireContentBlockViewHostedTests` use
/// it.
@MainActor @Observable final class ReportRecorder<Value> {
  /// Each reported value, in report order.
  private(set) var values: [Value] = []

  /// The report that gives each value to this recorder.
  var report: ObservationReport<Value> {
    ObservationReport { self.values.append($0) }
  }
}
