// swift-tools-version: 6.2
//
// AgentViewKitBenchmarks: the observation benchmark of the transcript view
// over `SessionModel` (plan.md §8, §14 R4), in a separate SwiftPM package.
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
// The benchmarks render SwiftUI views in a window, and the plugin sandbox has
// no window server. Thus the commands use `--disable-sandbox`.
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
    // The ACP wire types and the client models. The URLs and the branch are
    // the same as in the root manifest, so the two packages resolve the same
    // revisions (`ResolvedPinsTests`).
    .package(url: "git@github.com:swissarmyhammer/FoundationModelsACP.git", branch: "main"),
    .package(url: "git@github.com:swissarmyhammer/FoundationModelsACPClient.git", branch: "main"),
  ],
  targets: [
    .executableTarget(
      name: "AgentViewKitBenchmarks",
      dependencies: [
        .product(name: "Benchmark", package: "benchmark"),
        .product(name: "AgentViewKit", package: "AgentViewKit"),
        // The observation benchmark opens a `SessionModel` over the scripted
        // agent of the root package (`ScriptedWireAgent.swift`,
        // `ScriptedSession.swift` and `BackgroundRunScript.swift`, through
        // links).
        .product(name: "FoundationModelsACP", package: "FoundationModelsACP"),
        .product(name: "FoundationModelsACPClient", package: "FoundationModelsACPClient"),
      ],
      path: "Benchmarks/AgentViewKitBenchmarks",
      plugins: [
        .plugin(name: "BenchmarkPlugin", package: "benchmark")
      ]
    )
  ],
  swiftLanguageModes: [.v6]
)
