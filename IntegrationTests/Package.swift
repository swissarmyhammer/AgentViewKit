// swift-tools-version: 6.2

import PackageDescription

/// The root package, as this manifest names it in each product dependency.
///
/// SwiftPM names a path dependency after its directory, not after the `name:`
/// of its manifest (`AgentViewKit`). The directory is the checkout of the
/// repository: `AgentViewKit` in a plain clone, and the name of the worktree
/// folder in a git worktree. So the name comes from the folder above this
/// package, and the manifest builds in both.
let rootPackageName = Context.packageDirectory.split(separator: "/").dropLast().last.map(String.init) ?? "AgentViewKit"

/// The isolation of the root targets (SE-0466): each declaration defaults to
/// `@MainActor`.
let mainActorIsolated: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

/// The products of the root package that the tests link: the kit, its style,
/// the agent-specific test helpers, and the scripted agents of the demo app.
let rootProducts: [Target.Dependency] = [
  .product(name: "AgentViewKit", package: rootPackageName),
  .product(name: "AgentViewKitStyle", package: rootPackageName),
  .product(name: "AgentViewKitTestSupport", package: rootPackageName),
  .product(name: "AgentViewKitDemoSupport", package: rootPackageName),
]

/// The EditorKit products that the hosted tests import: the views, the
/// commands, the style and the theme of the kit, and the hosted window helpers
/// of `EditorTestSupport`.
let editorKitProducts: [Target.Dependency] = [
  .product(name: "EditorSwiftUI", package: "EditorKit"),
  .product(name: "EditorTheme", package: "EditorKit"),
  .product(name: "EditorStyle", package: "EditorKit"),
  .product(name: "EditorDiff", package: "EditorKit"),
  .product(name: "EditorCommands", package: "EditorKit"),
  .product(name: "EditorCommandsUI", package: "EditorKit"),
  .product(name: "EditorComplete", package: "EditorKit"),
  .product(name: "EditorExtensions", package: "EditorKit"),
  .product(name: "EditorCommandsTestSupport", package: "EditorKit"),
  .product(name: "EditorTestSupport", package: "EditorKit"),
]

/// The ACP products: the wire types and the client connection.
let acpProducts: [Target.Dependency] = [
  .product(name: "FoundationModelsACP", package: "FoundationModelsACP"),
  .product(name: "FoundationModelsACPClient", package: "FoundationModelsACPClient"),
]

/// The SwiftPM manifest for the AgentViewKit integration tests.
///
/// This package holds the integration tests, and the root package holds no
/// integration target. The package boundary separates the two tiers, as in
/// EditorKit, TestudoApp and the FoundationModels packages:
///
/// - `swift test` at the repository root runs ONLY the unit tests: the models,
///   the commands, the wire and the scripted agents, with no window, no hosting
///   view and no capture. It is the per-card gate and the TDD loop.
/// - `swift test --package-path IntegrationTests` runs the integration tests:
///   each test that mounts a view in a window or a hosting view, with no
///   capture. Use `--filter` to run one test. It runs once per batch, at the
///   end.
/// - `swift test --package-path ScreenshotTests` runs the review gallery,
///   locally and never in CI.
///
/// The shared `swift-ci` workflow builds this package in its unit job on every
/// run, and runs it in its integration job. `.github/workflows/ci.yml` sets
/// `integration-package-path` for this.
///
/// Its `.build` is its own: `swift package clean --package-path
/// IntegrationTests` cleans it, a clean at the root does not.
let package = Package(
  name: "IntegrationTests",
  // The same floor as the root package.
  platforms: [
    .macOS("27.0")
  ],
  dependencies: [
    .package(path: ".."),
    // The tests import these products directly, as the unit tests do. The URL
    // and the pin are the ones of the root manifest, so SwiftPM resolves one
    // copy of each package.
    .package(url: "git@github.com:swissarmyhammer/EditorKit.git", branch: "main"),
    .package(url: "git@github.com:swissarmyhammer/FoundationModelsACP.git", branch: "main"),
    .package(url: "git@github.com:swissarmyhammer/FoundationModelsACPClient.git", branch: "main"),
    .package(url: "https://github.com/gonzalezreal/textual", exact: "0.5.0"),
  ],
  targets: [
    // The hosted tests: each one mounts a view in EditorKit's
    // `HostedViewHarness`. No file of `Style/` imports the style
    // library with `@testable`, so each of those tests reads only what a host
    // of the product reads.
    .testTarget(
      name: "IntegrationTests",
      dependencies: rootProducts + editorKitProducts + acpProducts + [
        .product(name: "Textual", package: "textual")
      ],
      swiftSettings: mainActorIsolated
    ),
  ],
  // The same language mode as the root manifest.
  swiftLanguageModes: [.v6]
)
