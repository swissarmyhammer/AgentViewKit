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

/// The SwiftPM manifest for the AgentViewKit review gallery.
///
/// `swift test --package-path ScreenshotTests` shows each key screen and each
/// snapshot view in a real window, captures it from the window server and
/// writes `~/Library/Caches/AgentViewKit/screenshot-check/index.html` for a
/// person to look at. No test reads the pixels of a capture. A run needs a
/// logged-in session with Screen Recording access, so this package runs locally
/// and never in CI: no workflow names it.
let package = Package(
  name: "ScreenshotTests",
  // The same floor as the root package.
  platforms: [
    .macOS("27.0")
  ],
  dependencies: [
    .package(path: ".."),
    // The tests import these products directly. The URL and the pin are the
    // ones of the root manifest, so SwiftPM resolves one copy of each package.
    .package(url: "git@github.com:swissarmyhammer/EditorKit.git", branch: "main"),
    .package(url: "git@github.com:swissarmyhammer/FoundationModelsACP.git", branch: "main"),
    .package(url: "git@github.com:swissarmyhammer/FoundationModelsACPClient.git", branch: "main"),
  ],
  targets: [
    // The key screens, the snapshot images and the gallery test.
    .testTarget(
      name: "ScreenshotTests",
      dependencies: [
        .product(name: "AgentViewKit", package: rootPackageName),
        .product(name: "AgentViewKitTestSupport", package: rootPackageName),
        .product(name: "AgentViewKitDemoSupport", package: rootPackageName),
        .product(name: "EditorSwiftUI", package: "EditorKit"),
        .product(name: "EditorStyle", package: "EditorKit"),
        .product(name: "EditorTestSupport", package: "EditorKit"),
        .product(name: "FoundationModelsACP", package: "FoundationModelsACP"),
        .product(name: "FoundationModelsACPClient", package: "FoundationModelsACPClient"),
      ],
      swiftSettings: mainActorIsolated
    )
  ],
  // The same language mode as the root manifest.
  swiftLanguageModes: [.v6]
)
