// swift-tools-version: 6.2
//
// AgentViewKit: a SwiftUI agent UI component library (plan.md).
//
// plan.md §11 decision 1: two library products. The `AgentViewKit` target
// holds the views and the ACP helpers in `Sources/AgentViewKit/ACP/`. The
// views bind directly to the models of FoundationModelsACPClient. The target
// links FoundationModelsACP and FoundationModelsACPClient directly.
//
// AgentViewKit is the shared visual layer of the view kits (user decision,
// 2026-10-28). The `AgentViewKitStyle` target holds the shared look: the
// content tile, the selectable surface, the shared symbols, the file chips,
// the status bar and the diff renderer setup. It links only EditorKit, and
// no ACP product, so that SnapshotViewKit and KanbanViewKit link it with no
// ACP package in their closure. The `AgentViewKit` target links it and keeps
// no copy of it.
//
// The kit is an ACP client kit. It does not depend on FoundationModels,
// FoundationModelsRouter or FoundationModelsExtras. A FoundationModels agent
// and a Router agent reach the kit through FoundationModelsACPAgent and ACP
// (plan.md §1).
//
// Two more library products are test support only: `AgentViewKitTestSupport`
// and `AgentViewKitDemoSupport`. The nested `IntegrationTests/` package links
// them by path, because a test target of this package cannot be a dependency.
// No host of the kit links them (plan.md §11 decision 1). Each target name
// starts with `AgentViewKit`, because SwiftPM needs a target name to be unique
// in the whole package graph, and a host may link more than one view kit.
//
// The tiers of the tests (plan.md §11 decision 21). `swift test` here runs
// the unit tests only: no test of this package mounts a view in a window or a
// hosting view, or captures a window. The hosted tests are in a nested
// package, and run with `swift test --package-path IntegrationTests`. The
// review gallery is in another, and runs locally with
// `swift test --package-path ScreenshotTests`.

import PackageDescription

// MARK: - Isolation

/// The library targets default each declaration to `@MainActor` (SE-0466).
///
/// This is the EditorKit rule for UI targets. The client models of
/// FoundationModelsACPClient are `@MainActor`, so the targets that are not UI
/// use the same default.
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
  // The shared style of the kits: the radius scale and the layout tokens
  // (`\.editorStyle`), the concentric surface shape, the inline edge, the
  // floating glass and the status and priority symbols (KanbanViewKit
  // plan.md §5.1, decision 18).
  .product(name: "EditorStyle", package: "EditorKit"),
]

/// The EditorKit products that the style target links: the shared style and
/// the theme, the SwiftUI views and the diff parser of the diff renderer, and
/// the focus segment of a scope kind. None of them links an ACP product.
let styleEditorKitProducts: [Target.Dependency] = [
  .product(name: "EditorStyle", package: "EditorKit"),
  .product(name: "EditorTheme", package: "EditorKit"),
  .product(name: "EditorSwiftUI", package: "EditorKit"),
  .product(name: "EditorDiff", package: "EditorKit"),
  .product(name: "EditorCommands", package: "EditorKit"),
]

/// The ACP products: the wire types and the client connection. The kit
/// target links them directly (plan.md §11 decision 1).
let acpProducts: [Target.Dependency] = [
  .product(name: "FoundationModelsACP", package: "FoundationModelsACP"),
  .product(name: "FoundationModelsACPClient", package: "FoundationModelsACPClient"),
]

/// The agent product of the demo app. Only the demo-only target
/// `AgentViewKitDemoSupport` links it: the ACP tab runs
/// FoundationModelsACPAgent in the process of the app with the live model,
/// and the Gallery tab runs it over the recorded sessions with the stub model.
/// The kit target does not import it.
let demoAgentProducts: [Target.Dependency] = [
  .product(name: "FoundationModelsACPAgent", package: "FoundationModelsACPAgent")
]

/// The EditorKit test support products that the model and view tests link:
/// the recording command system, and the hosted window and accessibility
/// helpers, such as the accessibility hit test.
let editorKitTestSupportProducts: [Target.Dependency] = [
  .product(name: "EditorCommandsTestSupport", package: "EditorKit"),
  .product(name: "EditorTestSupport", package: "EditorKit"),
]

/// The EditorKit test support product that the style tests link: the hosted
/// window and accessibility helpers. The recording command system is not in
/// it, because no style view registers a command.
let styleTestSupportProducts: [Target.Dependency] = [
  .product(name: "EditorTestSupport", package: "EditorKit")
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
  // The language of the source strings of the string catalog of the kit.
  defaultLocalization: "en",
  platforms: [
    .macOS("27.0")
  ],
  products: [
    .library(name: "AgentViewKit", targets: ["AgentViewKit"]),
    .library(name: "AgentViewKitStyle", targets: ["AgentViewKitStyle"]),
    // Test support only, for the nested IntegrationTests package.
    .library(name: "AgentViewKitTestSupport", targets: ["AgentViewKitTestSupport"]),
    .library(name: "AgentViewKitDemoSupport", targets: ["AgentViewKitDemoSupport"]),
  ],
  dependencies: [
    // The in-family packages use the SSH URL and `branch: "main"`, as each
    // sibling package does. EditorKit is pre-1.0 and has no tag (plan.md §4.1).
    .package(url: "git@github.com:swissarmyhammer/EditorKit.git", branch: "main"),
    .package(url: "git@github.com:swissarmyhammer/FoundationModelsACP.git", branch: "main"),
    .package(url: "git@github.com:swissarmyhammer/FoundationModelsACPClient.git", branch: "main"),
    // The agent of the ACP tab and of the Gallery tab of the demo app. Only
    // `AgentViewKitDemoSupport` links it, so a host of the kit does not build
    // it.
    .package(url: "git@github.com:swissarmyhammer/FoundationModelsACPAgent.git", branch: "main"),
    // Textual is a 0.x package, so the pin is exact.
    .package(url: "https://github.com/gonzalezreal/textual", exact: "0.5.0"),
    // The math engine is a 0.x package, so the pin is exact. Textual 0.5.0
    // also depends on it, with `from: "0.1.0"`.
    .package(url: "https://github.com/gonzalezreal/swiftui-math", exact: "0.1.0"),
  ],
  targets: [
    // The shared look of the view kits. It links only EditorKit: no ACP
    // product, no Textual and no math engine. The string catalog holds its
    // own English text.
    .target(
      name: "AgentViewKitStyle",
      dependencies: styleEditorKitProducts,
      resources: [
        .process("Resources/Localizable.xcstrings")
      ],
      swiftSettings: mainActorIsolated
    ),
    // The views and the ACP helpers. No target imports
    // FoundationModels, FoundationModelsRouter or FoundationModelsExtras.
    .target(
      name: "AgentViewKit",
      dependencies: ["AgentViewKitStyle"] + editorKitProducts + acpProducts + textualProducts + mathEngineProducts,
      // The TextMate grammars of GrammarBundle, and their licenses. The string
      // catalog holds the English source text of each localized string of
      // the kit. Each `String(localized:)` call and each SwiftUI text key of
      // the kit names `bundle: .module`, so that a host app gets the text
      // from this catalog and not from its main bundle. Each entry has an
      // explicit English value in the `translated` state, because the build
      // does not compile an entry that has no value.
      resources: [
        .copy("Resources/Grammars"),
        .process("Resources/Localizable.xcstrings"),
      ],
      swiftSettings: mainActorIsolated
    ),
    // The agent-specific test helpers: the recording fakes, and the session
    // model over the scripted agent of `AgentViewKitDemoSupport`. The generic
    // helpers, such as the hosted view harness, are EditorKit's
    // `EditorTestSupport`.
    // Each test target that links a package target links it too. It is a
    // test support product, so that the nested packages and the unit tests
    // share one copy of each fixture; no host of the kit links it.
    .target(
      name: "AgentViewKitTestSupport",
      dependencies: ["AgentViewKit", "AgentViewKitDemoSupport"] + acpProducts + styleTestSupportProducts,
      swiftSettings: mainActorIsolated
    ),
    // The scripted in-memory ACP agent, the agent starter of the demo app
    // (`DemoAgent`), and the launch options of the demo app. The ACP tests
    // link this target. The demo app (Examples/AgentViewKitDemo) compiles its
    // sources into the app. It is a test support product for the
    // IntegrationTests package; the two library products of a host are the
    // kit and its style (plan.md §11 decision 1). It links
    // FoundationModelsACPAgent for the agent of the ACP tab and of the
    // Gallery tab, which runs in the process of the app.
    .target(
      name: "AgentViewKitDemoSupport",
      dependencies: ["AgentViewKit"] + acpProducts + demoAgentProducts,
      swiftSettings: mainActorIsolated
    ),
    .testTarget(
      name: "AgentViewKitTests",
      dependencies: [
        "AgentViewKit",
        "AgentViewKitStyle",
        "AgentViewKitTestSupport",
        // The scripted wire agent and the in-memory demo agent of the ACP
        // tests.
        "AgentViewKitDemoSupport",
      ]
        + acpProducts + editorKitTestSupportProducts,
      swiftSettings: mainActorIsolated
    ),
    // The unit tests of the public API of the style library. No file imports
    // it with `@testable`, so each test reads only what a host of the product
    // reads. It links no ACP product and no target of the kit. Its hosted
    // tests are in the IntegrationTests package.
    .testTarget(
      name: "AgentViewKitStyleTests",
      dependencies: ["AgentViewKitStyle"] + styleEditorKitProducts + styleTestSupportProducts,
      swiftSettings: mainActorIsolated
    ),
  ],
  swiftLanguageModes: [.v6]
)
