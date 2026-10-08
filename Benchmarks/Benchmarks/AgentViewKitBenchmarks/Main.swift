//
// AgentViewKitBenchmarks: the entry point of the benchmark executable.
//
// The benchmark package calls `benchmarks()` one time at start to find the
// scenarios. The registration only describes the scenarios. It opens no
// session and measures nothing.
//
//   - `SessionModelObservationBenchmarks`: 1,000 chunks into one agent
//     message of a `SessionModel`, with the transcript view hosted, at the
//     cadence zero and at the default cadence of the model.
//
// `BenchmarkPolicy` holds the metrics and the thresholds. `README.md` holds
// the decisions and the baseline update steps.
//

import Benchmark

let benchmarks: @Sendable () -> Void = {
  SessionModelObservationBenchmarks.register()
}
