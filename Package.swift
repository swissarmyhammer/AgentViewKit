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
  // The completion source protocol and its value types (plan.md §4.1).
  .product(name: "EditorExtensions", package: "EditorKit"),
  // The unified diff parser under the default diff renderer (plan.md §4.1,
  // decision 12). The view of the renderer is in `EditorSwiftUI`.
  .product(name: "EditorDiff", package: "EditorKit"),
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

/// The math engine (plan.md §11 decision 7). Docs/decisions/math-engine.md
/// records the choice and the version.
let mathEngineProducts: [Target.Dependency] = [
  .product(name: "SwiftUIMath", package: "swiftui-math")
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
    // The math engine is a 0.x package, so the pin is exact. Textual 0.5.0
    // also depends on it, with `from: "0.1.0"`.
    .package(url: "https://github.com/gonzalezreal/swiftui-math", exact: "0.1.0"),
  ],
  targets: [
    // The model and the views. This target must not import a source runtime.
    // ImportBoundaryTests enforces this.
    .target(
      name: "AgentViewKit",
      dependencies: editorKitProducts + textualProducts + mathEngineProducts,
      // The catalog document is the schema name agreement with the Router.
      // StructuredCatalogTests reads it from disk, so the build excludes it.
      exclude: ["Catalog/catalog.md"],
      // The TextMate grammars of GrammarBundle, and their licenses.
      resources: [.copy("Resources/Grammars")],
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
    // The scripted in-memory ACP agent, the ACP session model, the fake
    // language model, the FoundationModels session model, and the launch
    // options of the demo app. The ACP tests and the FoundationModels tests
    // link this target. The demo app (Examples/AgentViewKitDemo) compiles its
    // sources into the app. The target is not a product, because the package
    // has exactly four library products (plan.md §11 decision 1).
    .target(
      name: "DemoSupport",
      dependencies: [
        "AgentViewKit",
        "AgentViewKitACP",
        "AgentViewKitFoundationModels",
        .product(name: "FoundationModelsACP", package: "FoundationModelsACP"),
        .product(name: "FoundationModelsACPClient", package: "FoundationModelsACPClient"),
      ],
      swiftSettings: mainActorIsolated
    ),
    // Finds and reads the package files for the tests. This target is not a
    // product and has no dependency, so that PackageStructureTests can link it
    // without the kit.
    .target(name: "PackageFileSupport"),

    .testTarget(
      name: "AgentViewKitTests",
      dependencies: ["AgentViewKit", "AgentViewKitTestSupport", "PackageFileSupport"]
        + editorKitTestSupportProducts,
      // AgentThemeTests reads the token file from disk as data, and
      // ThreadExporterTests reads the golden export file from disk, so the
      // build excludes them.
      exclude: ["Theme/DefaultTokens.json", "Items/Fixtures"],
      swiftSettings: mainActorIsolated
    ),
    .testTarget(
      name: "AgentViewKitFoundationModelsTests",
      dependencies: [
        "AgentViewKitFoundationModels",
        "AgentViewKitTestSupport",
        // The fake language model and the FoundationModels session model of
        // the demo app.
        "DemoSupport",
      ],
      swiftSettings: mainActorIsolated
    ),
    .testTarget(
      name: "AgentViewKitRouterTests",
      dependencies: [
        "AgentViewKitRouter",
        "AgentViewKitTestSupport",
        // SubagentAdapterTests reads the subagent fixture from disk.
        "PackageFileSupport",
        .product(name: "FoundationModelsRouter", package: "FoundationModelsRouter"),
        .product(name: "FoundationModelsExtras", package: "FoundationModelsExtras"),
      ],
      swiftSettings: mainActorIsolated
    ),
    .testTarget(
      name: "AgentViewKitACPTests",
      dependencies: [
        "AgentViewKitACP",
        "AgentViewKitTestSupport",
        // The scripted wire agent and the in-memory demo agent.
        "DemoSupport",
        // ProtocolVersionTests reads the ACP version decision from disk.
        "PackageFileSupport",
        .product(name: "FoundationModelsACP", package: "FoundationModelsACP"),
        .product(name: "FoundationModelsACPClient", package: "FoundationModelsACPClient"),
      ],
      swiftSettings: mainActorIsolated
    ),
    // Reads the package files as text. It links only PackageFileSupport,
    // which has no dependency. The fixtures are Swift files that the scanner
    // reads, so the build excludes them.
    .testTarget(
      name: "PackageStructureTests",
      dependencies: ["PackageFileSupport"],
      exclude: ["Fixtures"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
