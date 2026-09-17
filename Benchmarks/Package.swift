// swift-tools-version: 6.2
//
// AgentViewKitBenchmarks: the streaming and observation benchmarks of
// plan.md §8 and research R1 and R4, in a separate SwiftPM package.
//
// This package is separate from the root package, as in
// `../EditorKit/Benchmarks`. It depends on AgentViewKit by path. Thus:
//
//   - The root package does not get the benchmark dependencies.
//   - `swift test` in the root package does not build the benchmarks.
//   - The root package tests that scan `Sources/` and `Tests/` do not read
//     these files.
//
// Run the benchmarks from the repository root:
//
//   swift package --package-path Benchmarks --disable-sandbox benchmark
//   Scripts/check-benchmarks.sh
//
// The streaming benchmarks render SwiftUI views in a window, and the plugin
// sandbox has no window server. Thus the commands use `--disable-sandbox`.
//
// `Benchmarks/README.md` has the decisions, the numbers, and the baseline
// update steps.

import PackageDescription

let package = Package(
  name: "AgentViewKitBenchmarks",
  platforms: [
    .macOS("27.0")
  ],
  dependencies: [
    // AgentViewKit, by path. The benchmarks measure the library products.
    .package(path: ".."),
    // The benchmark runner, the baseline store, and the `benchmark` command
    // plugin. The pin is exact and is the same as in EditorKit.
    .package(url: "https://github.com/ordo-one/benchmark.git", exact: "1.36.2"),
    // Textual, for the benchmark with no paragraph split. The pin is the
    // same as in the root manifest.
    .package(url: "https://github.com/gonzalezreal/textual", exact: "0.5.0"),
  ],
  targets: [
    .executableTarget(
      name: "AgentViewKitBenchmarks",
      dependencies: [
        .product(name: "Benchmark", package: "benchmark"),
        .product(name: "AgentViewKit", package: "AgentViewKit"),
        .product(name: "AgentViewKitFoundationModels", package: "AgentViewKit"),
        .product(name: "Textual", package: "textual"),
      ],
      // Two files in this directory are symbolic links:
      //
      //   - `FakeLanguageModel.swift` to
      //     `Tests/AgentViewKitFoundationModelsTests/FakeLanguageModel.swift`.
      //   - `ChangeCounter.swift` to
      //     `Sources/AgentViewKitTestSupport/ChangeCounter.swift`.
      //
      // A package can use only the products of another package, and a test
      // target or the test support target is not a product. Thus this target
      // compiles the same files, and the benchmarks use the same fake model
      // and the same change counter as the tests.
      path: "Benchmarks/AgentViewKitBenchmarks",
      plugins: [
        .plugin(name: "BenchmarkPlugin", package: "benchmark")
      ]
    )
  ],
  swiftLanguageModes: [.v6]
)
