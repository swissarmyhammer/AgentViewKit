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
// The custom count metrics (body evaluations, paragraphs parsed, observer
// invalidations, the tail updates of the snapshot source) do not change with
// the machine:
//
//   - A LARGE count uses the relative instruction tolerance.
//   - A SMALL count (a few changes for each chunk or stream) moves by one
//     when two observation changes fall into one main actor pass. A change
//     from 2 to 3 is +50 %, so a small count uses an absolute tolerance.
//   - A RECORDED count has no threshold. The tail updates of the two
//     comparison sources change with the machine (see `tailUpdates(gated:)`).
//

import Benchmark

/// A custom count metric and its thresholds.
struct CountMetric {
  /// The metric.
  let metric: BenchmarkMetric

  /// The thresholds of the metric.
  let thresholds: BenchmarkThresholds
}

/// The metrics, the thresholds, and the run shape of each benchmark.
enum BenchmarkPolicy {

  // MARK: - Thresholds

  /// The regression that the gate must catch, in percent. A 2x slowdown is
  /// +100 %.
  static let gatedRegressionPercent = 100.0

  /// The share of ``gatedRegressionPercent`` that the wall clock gate gives
  /// to machine variance.
  static let wallClockVarianceShare = 0.75

  /// The share of ``gatedRegressionPercent`` that the count gates give to
  /// variance. A count changes only when the code changes.
  static let countVarianceShare = 0.25

  /// The relative wall clock tolerance, in percent.
  static let wallClockTolerancePercent = gatedRegressionPercent * wallClockVarianceShare

  /// The relative tolerance of the instruction count and of the custom
  /// counts, in percent.
  static let countTolerancePercent = gatedRegressionPercent * countVarianceShare

  /// The percentiles that the gate reads. The p99 and the p100 are not
  /// gated, because one scheduling stall moves them.
  static var gatedPercentiles: [BenchmarkResult.Percentile] { [.p50, .p90] }

  /// The absolute tolerance of a small count.
  static let smallCountTolerance = 2

  // MARK: - Custom metrics

  /// The SwiftUI body evaluations of the probes for one chunk. The probes
  /// read the same observed values as the views of ``AgentViewKit``.
  static var bodyEvaluations: CountMetric {
    smallCount("Body evaluations per chunk")
  }

  /// The paragraphs that Textual parses for one chunk. The chunks are at the
  /// same places in each run, so the count does not move.
  static var paragraphsParsed: CountMetric {
    largeCount("Paragraphs parsed per chunk")
  }

  /// The invalidations of an observer of `thread.items` for one stream.
  static var itemsInvalidations: CountMetric {
    smallCount("Items invalidations per stream")
  }

  /// The invalidations of an observer of the streaming message for one
  /// stream.
  static var streamingInvalidations: CountMetric {
    smallCount("Streaming invalidations per stream")
  }

  /// The tail updates that a tail source gives for one stream.
  ///
  /// The snapshot source, the one that the kit uses, gives one update for
  /// each chunk, so its count does not change with the machine and the gate
  /// reads it. The two comparison sources of research R4
  /// (`SessionPropertyValues.history` and `session.transcript`) give one
  /// update for each observation tick of the SDK. That count describes the
  /// SDK and the machine, not the kit: the CI runner gave 3 times the count
  /// of the machine that recorded the baseline, and 3 times the work with
  /// it. So those scenarios record the count with `gated: false`, as the
  /// policy records throughput, and their configuration is not gated.
  ///
  /// - Parameter gated: Whether the gate reads the count.
  /// - Returns: The metric, with the relative count tolerance or none.
  static func tailUpdates(gated: Bool) -> CountMetric {
    gated
      ? largeCount("Tail updates per stream")
      : recordedCount("Tail updates per stream")
  }

  /// A count metric that the gate does not read.
  ///
  /// - Parameter name: The name of the metric.
  /// - Returns: The metric, with no threshold.
  private static func recordedCount(_ name: String) -> CountMetric {
    CountMetric(
      metric: .custom(name, polarity: .prefersSmaller, useScalingFactor: false),
      thresholds: .none)
  }

  /// A small count metric, with the absolute tolerance.
  ///
  /// - Parameter name: The name of the metric.
  /// - Returns: The metric and its thresholds.
  private static func smallCount(_ name: String) -> CountMetric {
    CountMetric(
      metric: .custom(name, polarity: .prefersSmaller, useScalingFactor: false),
      thresholds: BenchmarkThresholds(
        absolute: Dictionary(
          uniqueKeysWithValues: gatedPercentiles.map { ($0, smallCountTolerance) })))
  }

  /// A large count metric, with the relative count tolerance.
  ///
  /// - Parameter name: The name of the metric.
  /// - Returns: The metric and its thresholds.
  private static func largeCount(_ name: String) -> CountMetric {
    CountMetric(
      metric: .custom(name, polarity: .prefersSmaller, useScalingFactor: false),
      thresholds: relativeThresholds(percent: countTolerancePercent))
  }

  // MARK: - Run shape

  /// The iterations that run before the measurement starts.
  static let warmupIterations = 3

  /// The longest time of one benchmark, in seconds.
  static let maxDurationSeconds = 30

  /// The longest time of one benchmark.
  static let maxDuration: Duration = .seconds(maxDurationSeconds)

  /// The configuration of a benchmark.
  ///
  /// - Parameters:
  ///   - iterations: The measured iterations.
  ///   - countMetrics: The custom count metrics that the benchmark records.
  ///   - gated: Whether the gate reads the metrics. A scenario that measures
  ///     a reference path, not a path of the kit, records its metrics with
  ///     `gated: false`: each of its numbers changes with the machine, and a
  ///     change in the kit cannot move them (see ``tailUpdates(gated:)``).
  /// - Returns: The shared policy with the iteration count and the metrics.
  static func configuration(
    iterations: Int, countMetrics: [CountMetric], gated: Bool = true
  ) -> Benchmark.Configuration {
    let timeMetrics: [BenchmarkMetric] = [.wallClock, .instructions, .throughput]
    let timeThresholds: [BenchmarkMetric: BenchmarkThresholds] = [
      .wallClock: relativeThresholds(percent: wallClockTolerancePercent),
      .instructions: relativeThresholds(percent: countTolerancePercent),
      .throughput: .none,
    ]
    let countThresholds = Dictionary(
      uniqueKeysWithValues: countMetrics.map { ($0.metric, $0.thresholds) })
    let gatedThresholds = timeThresholds.merging(countThresholds) { time, _ in time }
    return Benchmark.Configuration(
      metrics: timeMetrics + countMetrics.map(\.metric),
      warmupIterations: warmupIterations,
      maxDuration: maxDuration,
      maxIterations: iterations,
      thresholds: gated ? gatedThresholds : gatedThresholds.mapValues { _ in .none }
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
