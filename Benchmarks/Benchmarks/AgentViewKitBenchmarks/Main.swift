//
// AgentViewKitBenchmarks: the entry point of the benchmark executable.
//
// The benchmark package calls `benchmarks()` one time at start to find the
// scenarios. The registration only describes the scenarios. It builds no
// corpus and measures nothing.
//
//   - `StreamingBenchmarks`: one streamed chunk through Textual, with the
//     paragraph split on and off (research R1).
//   - `ObservationBenchmarks`: the observer invalidations of a
//     FoundationModels stream, and the tail source comparison (research R4).
//
// `BenchmarkPolicy` holds the metrics and the thresholds. `README.md` holds
// the decisions and the baseline update steps.
//

import Benchmark

let benchmarks: @Sendable () -> Void = {
  registerStreamingBenchmarks()
  registerObservationBenchmarks()
}
