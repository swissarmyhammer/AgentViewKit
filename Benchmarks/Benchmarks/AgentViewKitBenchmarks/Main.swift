//
// AgentViewKitBenchmarks: the entry point of the benchmark executable.
//
// The benchmark package calls `benchmarks()` one time at start to find the
// scenarios. The registration only describes the scenarios. It builds no
// corpus and measures nothing.
//
// The package has no scenario now. The streaming scenarios went with the old
// kit session model (`README.md`, "The scenarios"). A later task adds an
// observation benchmark of the transcript view over `SessionModel`.
//
// `BenchmarkPolicy` holds the metrics and the thresholds. `README.md` holds
// the decisions and the baseline update steps.
//

import Benchmark

let benchmarks: @Sendable () -> Void = {}
