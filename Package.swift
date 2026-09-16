// swift-tools-version: 6.2
//
// AgentViewKit: a SwiftUI agent UI component library (plan.md).
//
// plan.md §11 decision 1: one library target for the model and the views, and
// one adapter target for each source runtime.
//
//   - AgentViewKit                  the model and the views
//   - AgentViewKitFoundationModels  SessionThreadSource, imports FoundationModels
//   - AgentViewKitRouter            RouterThreadSource, imports FoundationModelsRouter
//                                   and FoundationModelsExtras
//   - AgentViewKitACP               ACPThreadSource, imports FoundationModelsACP and
//                                   FoundationModelsACPClient
//
// PackageStructureTests reads this file as text. Spell each library product
// and each dependency product in full, as `.library(name:` and
// `.product(name:package:)`, so that the tests can find them.

import PackageDescription

// MARK: - Isolation

/// The library targets default each declaration to `@MainActor` (SE-0466).
///
/// This is the EditorKit rule for UI targets. `AgentThread` is `@MainActor`
/// (plan.md §3.2), and each adapter target writes into it, so the adapter
/// targets use the same default.
let mainActorIsolated: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

// MARK: - Dependency products

/// The EditorKit products that the model and view target links.
let editorKitProducts: [Target.Dependency] = [
  .product(name: "EditorSwiftUI", package: "EditorKit"),
  .product(name: "EditorCore", package: "EditorKit"),
  .product(name: "EditorText", package: "EditorKit"),
  .product(name: "EditorTheme", package: "EditorKit"),
  .product(name: "EditorCommands", package: "EditorKit"),
  .product(name: "EditorCommandsUI", package: "EditorKit"),
  .product(name: "EditorComplete", package: "EditorKit"),
  .product(name: "EditorDecorations", package: "EditorKit"),
]

/// The EditorKit test support product that the model and view tests link.
let editorKitTestSupportProducts: [Target.Dependency] = [
  .product(name: "EditorCommandsTestSupport", package: "EditorKit")
]

/// The Markdown renderer (plan.md §4.2). Docs/decisions/dependencies.md
/// records the product name and the version.
let textualProducts: [Target.Dependency] = [
  .product(name: "Textual", package: "textual")
]

let package = Package(
  name: "AgentViewKit",
  platforms: [
    .macOS("27.0")
  ],
  products: [
    .library(name: "AgentViewKit", targets: ["AgentViewKit"]),
    .library(name: "AgentViewKitFoundationModels", targets: ["AgentViewKitFoundationModels"]),
    .library(name: "AgentViewKitRouter", targets: ["AgentViewKitRouter"]),
    .library(name: "AgentViewKitACP", targets: ["AgentViewKitACP"]),
  ],
  dependencies: [
    // The in-family packages use the SSH URL and `branch: "main"`, as each
    // sibling package does. EditorKit is pre-1.0 and has no tag (plan.md §4.1).
    .package(url: "git@github.com:swissarmyhammer/EditorKit.git", branch: "main"),
    .package(url: "git@github.com:swissarmyhammer/FoundationModelsACP.git", branch: "main"),
    .package(url: "git@github.com:swissarmyhammer/FoundationModelsACPClient.git", branch: "main"),
    .package(url: "git@github.com:swissarmyhammer/FoundationModelsRouter.git", branch: "main"),
    .package(url: "git@github.com:swissarmyhammer/FoundationModelsExtras.git", branch: "main"),
    // Textual is a 0.x package, so the pin is exact.
    .package(url: "https://github.com/gonzalezreal/textual", exact: "0.5.0"),
  ],
  targets: [
    // The model and the views. This target must not import a source runtime.
    // ImportBoundaryTests enforces this.
    .target(
      name: "AgentViewKit",
      dependencies: editorKitProducts + textualProducts,
      swiftSettings: mainActorIsolated
    ),
    .target(
      name: "AgentViewKitFoundationModels",
      dependencies: ["AgentViewKit"],
      swiftSettings: mainActorIsolated
    ),
    .target(
      name: "AgentViewKitRouter",
      dependencies: [
        "AgentViewKit",
        .product(name: "FoundationModelsRouter", package: "FoundationModelsRouter"),
        .product(name: "FoundationModelsExtras", package: "FoundationModelsExtras"),
      ],
      swiftSettings: mainActorIsolated
    ),
    // This target must not import FoundationModels, FoundationModelsRouter, or
    // FoundationModelsExtras. ImportBoundaryTests enforces this.
    .target(
      name: "AgentViewKitACP",
      dependencies: [
        "AgentViewKit",
        .product(name: "FoundationModelsACP", package: "FoundationModelsACP"),
        .product(name: "FoundationModelsACPClient", package: "FoundationModelsACPClient"),
      ],
      swiftSettings: mainActorIsolated
    ),
    // The hosted view harness and the recording fakes. This target is not a
    // product. Each test target that links a package target links it too.
    .target(
      name: "AgentViewKitTestSupport",
      dependencies: ["AgentViewKit"],
      swiftSettings: mainActorIsolated
    ),

    .testTarget(
      name: "AgentViewKitTests",
      dependencies: ["AgentViewKit", "AgentViewKitTestSupport"] + editorKitTestSupportProducts,
      // AgentThemeTests reads the token file from disk as data, so the build
      // excludes it.
      exclude: ["Theme/DefaultTokens.json"],
      swiftSettings: mainActorIsolated
    ),
    .testTarget(
      name: "AgentViewKitFoundationModelsTests",
      dependencies: ["AgentViewKitFoundationModels", "AgentViewKitTestSupport"],
      swiftSettings: mainActorIsolated
    ),
    .testTarget(
      name: "AgentViewKitRouterTests",
      dependencies: ["AgentViewKitRouter", "AgentViewKitTestSupport"],
      swiftSettings: mainActorIsolated
    ),
    .testTarget(
      name: "AgentViewKitACPTests",
      dependencies: ["AgentViewKitACP", "AgentViewKitTestSupport"],
      swiftSettings: mainActorIsolated
    ),
    // Reads the package files as text. It links no package target. The
    // fixtures are Swift files that the scanner reads, so the build excludes
    // them.
    .testTarget(
      name: "PackageStructureTests",
      exclude: ["Fixtures"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
