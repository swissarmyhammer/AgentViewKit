//
// BenchmarkPolicy: the metrics, the thresholds, and the run shape of each
// AgentViewKit benchmark.
//
// The policy is the policy of `../EditorKit/Benchmarks`:
//
//   - INSTRUCTIONS: the retired instructions of the process. The count
//     changes only when the code changes. This is the primary gate.
//   - WALL CLOCK: the elapsed time. It changes with the machine, so its
//     tolerance is larger. This is the secondary gate.
//   - THROUGHPUT: recorded, not gated. It is the wall clock in a different
//     unit.
//
// The gate must catch a 2x slowdown, which the benchmark package shows as
// +100 %. Each tolerance is a share of that 100 %, and each share is less
// than 1. Thus no tolerance can become larger than the regression that the
// gate must catch.
//

import Benchmark

/// The metrics, the thresholds, and the run shape of each benchmark.
enum BenchmarkPolicy {

  // MARK: - Thresholds

  /// The regression that the gate must catch, in percent. A 2x slowdown is
  /// +100 %.
  static let gatedRegressionPercent = 100.0

  /// The share of ``gatedRegressionPercent`` that the wall clock gate gives
  /// to machine variance.
  static let wallClockVarianceShare = 0.75

  /// The share of ``gatedRegressionPercent`` that the instruction gate gives
  /// to variance. The instruction count changes only when the code changes.
  static let instructionVarianceShare = 0.25

  /// The relative wall clock tolerance, in percent.
  static let wallClockTolerancePercent = gatedRegressionPercent * wallClockVarianceShare

  /// The relative tolerance of the instruction count, in percent.
  static let instructionTolerancePercent = gatedRegressionPercent * instructionVarianceShare

  /// The percentiles that the gate reads. The p99 and the p100 are not
  /// gated, because one scheduling stall moves them.
  static var gatedPercentiles: [BenchmarkResult.Percentile] { [.p50, .p90] }

  // MARK: - Run shape

  /// The iterations that run before the measurement starts.
  static let warmupIterations = 3

  /// The longest time of one benchmark, in seconds.
  static let maxDurationSeconds = 30

  /// The longest time of one benchmark.
  static let maxDuration: Duration = .seconds(maxDurationSeconds)

  /// The configuration of a benchmark.
  ///
  /// - Parameter iterations: The measured iterations.
  /// - Returns: The shared policy with the iteration count.
  static func configuration(iterations: Int) -> Benchmark.Configuration {
    Benchmark.Configuration(
      metrics: [.wallClock, .instructions, .throughput],
      warmupIterations: warmupIterations,
      maxDuration: maxDuration,
      maxIterations: iterations,
      thresholds: [
        .wallClock: relativeThresholds(percent: wallClockTolerancePercent),
        .instructions: relativeThresholds(percent: instructionTolerancePercent),
        .throughput: .none,
      ]
    )
  }

  /// A relative threshold set with `percent` at each gated percentile.
  ///
  /// - Parameter percent: The tolerance, in percent.
  /// - Returns: The threshold set.
  private static func relativeThresholds(percent: Double) -> BenchmarkThresholds {
    BenchmarkThresholds(
      relative: Dictionary(uniqueKeysWithValues: gatedPercentiles.map { ($0, percent) }))
  }
}
