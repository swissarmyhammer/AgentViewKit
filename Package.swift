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
// PackageStructureTests reads this file as text. Spell each library product
// and each dependency product in full, as `.library(name:` and
// `.product(name:package:)`, so that the tests can find them.

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
/// `AgentViewKitStyleClosureTests` checks the closure of this list.
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

/// The agent product of the demo app. Only the demo-only target `DemoSupport`
/// links it: the ACP tab runs FoundationModelsACPAgent in the process of the
/// app with the live model, and the Gallery tab runs it over the recorded
/// sessions with the stub model. The kit target does not import it.
/// ImportBoundaryTests enforces this.
let demoAgentProducts: [Target.Dependency] = [
  .product(name: "FoundationModelsACPAgent", package: "FoundationModelsACPAgent")
]

/// The EditorKit products that a host imports to set the theme and the style of the kit (README
/// "The theme").
let readmeEditorKitProducts: [Target.Dependency] = [
  .product(name: "EditorSwiftUI", package: "EditorKit"),
  .product(name: "EditorTheme", package: "EditorKit"),
  .product(name: "EditorStyle", package: "EditorKit"),
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
  ],
  dependencies: [
    // The in-family packages use the SSH URL and `branch: "main"`, as each
    // sibling package does. EditorKit is pre-1.0 and has no tag (plan.md §4.1).
    .package(url: "git@github.com:swissarmyhammer/EditorKit.git", branch: "main"),
    .package(url: "git@github.com:swissarmyhammer/FoundationModelsACP.git", branch: "main"),
    .package(url: "git@github.com:swissarmyhammer/FoundationModelsACPClient.git", branch: "main"),
    // The agent of the ACP tab and of the Gallery tab of the demo app. Only
    // `DemoSupport` links it, so a host of the kit does not build it.
    .package(url: "git@github.com:swissarmyhammer/FoundationModelsACPAgent.git", branch: "main"),
    // Textual is a 0.x package, so the pin is exact.
    .package(url: "https://github.com/gonzalezreal/textual", exact: "0.5.0"),
    // The math engine is a 0.x package, so the pin is exact. Textual 0.5.0
    // also depends on it, with `from: "0.1.0"`.
    .package(url: "https://github.com/gonzalezreal/swiftui-math", exact: "0.1.0"),
  ],
  targets: [
    // The shared look of the view kits. It links only EditorKit: no ACP
    // product, no Textual and no math engine. ImportBoundaryTests holds its
    // imports, and AgentViewKitStyleClosureTests holds its dependency
    // closure. The string catalog holds its own English text.
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
    // ImportBoundaryTests enforces this.
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
    // The hosted view harness, the recording fakes, and the session model
    // over the scripted agent of `DemoSupport`. This target is not a product.
    // Each test target that links a package target links it too.
    .target(
      name: "AgentViewKitTestSupport",
      dependencies: ["AgentViewKit", "DemoSupport", "HostedWindowSupport"] + acpProducts,
      swiftSettings: mainActorIsolated
    ),
    // The Objective-C window of the hosted view harness. The window catches
    // the exception of a display cycle loop of AppKit, such as a constraint
    // update loop, so that a hosted test fails and does not stop the test
    // process. Swift cannot catch an Objective-C exception. This target is
    // not a product, and it links only AppKit.
    .target(name: "HostedWindowSupport"),
    // The scripted in-memory ACP agent, the agent starter of the demo app
    // (`DemoAgent`), and the launch options of the demo app. The ACP tests
    // link this target. The demo app (Examples/AgentViewKitDemo) compiles its
    // sources into the app. The target is not a product: the two library
    // products are the kit and its style (plan.md §11 decision 1). It links
    // FoundationModelsACPAgent for the agent of the ACP tab and of the
    // Gallery tab, which runs in the process of the app.
    .target(
      name: "DemoSupport",
      dependencies: ["AgentViewKit"] + acpProducts + demoAgentProducts,
      swiftSettings: mainActorIsolated
    ),
    // Finds and reads the package files for the tests, and reads the Markdown
    // tables of the decision records. This target is not a product and has no
    // dependency, so that PackageStructureTests can link it without the kit.
    .target(name: "PackageFileSupport"),

    .testTarget(
      name: "AgentViewKitTests",
      dependencies: [
        "AgentViewKit",
        "AgentViewKitStyle",
        "AgentViewKitTestSupport",
        // The scripted wire agent and the in-memory demo agent of the ACP
        // tests.
        "DemoSupport",
        // ProtocolVersionTests reads the ACP version decision from disk, and
        // the decision table tests read their tables with MarkdownTable.
        "PackageFileSupport",
        // HostedViewHarnessTests checks the window of the harness that
        // catches the exception of a display cycle loop.
        "HostedWindowSupport",
      ]
        + acpProducts + editorKitTestSupportProducts,
      // The snapshot tests read their reference PNG images from disk
      // (AVK-13), so the build excludes that folder.
      exclude: ["Snapshots/__Snapshots__"],
      swiftSettings: mainActorIsolated
    ),
    // The tests of the public API of the style library. No file imports it
    // with `@testable`, so each test reads only what a host of the product
    // reads. It links no ACP product and no target of the kit, and it hosts
    // its views with the window helpers of EditorKit.
    .testTarget(
      name: "AgentViewKitStyleTests",
      dependencies: ["AgentViewKitStyle"] + styleEditorKitProducts + styleTestSupportProducts,
      swiftSettings: mainActorIsolated
    ),
    // Reads the package files as text. It links PackageFileSupport, which has
    // no dependency, and the line scan of the EditorKit test support
    // (`SourceScanning`), which the scan for a SwiftUI `List` reads with. It
    // links no target of the kit. The fixtures are Swift files that the
    // scanner reads, so the build excludes them.
    .testTarget(
      name: "PackageStructureTests",
      dependencies: ["PackageFileSupport"] + styleTestSupportProducts,
      exclude: ["Fixtures"]
    ),
    // The compiled snippets of README.md (plan.md §1). Each `// readme:compile`
    // block of the README is a file in `Examples/ReadmeSnippets/Snippets/`,
    // that `Scripts/extract-readme-snippets.sh` writes. This target compiles
    // the files against the products that a host imports: the kit, the ACP
    // products, and the EditorKit theme products. Thus a snippet that does
    // not compile fails the build. `ReadmeSnippetTests` in
    // PackageStructureTests holds the README and the files equal. It is a
    // test target, and not in `Sources/`, so that no product links the
    // snippets. It has no default isolation, so that the snippets compile in
    // a host with the language default.
    .testTarget(
      name: "ReadmeSnippetsTests",
      dependencies: ["AgentViewKit"] + acpProducts + readmeEditorKitProducts,
      path: "Examples/ReadmeSnippets"
    ),
  ],
  swiftLanguageModes: [.v6]
)
