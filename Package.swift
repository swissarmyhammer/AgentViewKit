// swift-tools-version: 6.2
//
// AgentViewKit: a SwiftUI agent UI component library (plan.md).
//
// update.md §3, D4: one library product and one library target. The
// `AgentViewKit` target holds the model, the views, and the ACP adapter
// (`ACPThreadSource` in `Sources/AgentViewKit/ACP/`). It links
// FoundationModelsACP and FoundationModelsACPClient directly.
//
// The kit is an ACP client kit. It does not depend on FoundationModels,
// FoundationModelsRouter or FoundationModelsExtras. A FoundationModels agent
// and a Router agent reach the kit through FoundationModelsACPAgent and ACP
// (update.md §1).
//
// PackageStructureTests reads this file as text. Spell each library product
// and each dependency product in full, as `.library(name:` and
// `.product(name:package:)`, so that the tests can find them.

import PackageDescription

// MARK: - Isolation

/// The library targets default each declaration to `@MainActor` (SE-0466).
///
/// This is the EditorKit rule for UI targets. `AgentThread` is `@MainActor`
/// (plan.md §3.2), and the ACP adapter writes into it, so the targets that
/// are not UI use the same default.
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

/// The ACP products: the wire types and the client connection. The kit
/// target links them directly (update.md §3, D4).
let acpProducts: [Target.Dependency] = [
  .product(name: "FoundationModelsACP", package: "FoundationModelsACP"),
  .product(name: "FoundationModelsACPClient", package: "FoundationModelsACPClient"),
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
  ],
  dependencies: [
    // The in-family packages use the SSH URL and `branch: "main"`, as each
    // sibling package does. EditorKit is pre-1.0 and has no tag (plan.md §4.1).
    .package(url: "git@github.com:swissarmyhammer/EditorKit.git", branch: "main"),
    .package(url: "git@github.com:swissarmyhammer/FoundationModelsACP.git", branch: "main"),
    .package(url: "git@github.com:swissarmyhammer/FoundationModelsACPClient.git", branch: "main"),
    // Textual is a 0.x package, so the pin is exact.
    .package(url: "https://github.com/gonzalezreal/textual", exact: "0.5.0"),
    // The math engine is a 0.x package, so the pin is exact. Textual 0.5.0
    // also depends on it, with `from: "0.1.0"`.
    .package(url: "https://github.com/gonzalezreal/swiftui-math", exact: "0.1.0"),
  ],
  targets: [
    // The model, the views, and the ACP adapter. No target imports
    // FoundationModels, FoundationModelsRouter or FoundationModelsExtras.
    // ImportBoundaryTests enforces this.
    .target(
      name: "AgentViewKit",
      dependencies: editorKitProducts + acpProducts + textualProducts + mathEngineProducts,
      // The TextMate grammars of GrammarBundle, and their licenses.
      resources: [.copy("Resources/Grammars")],
      swiftSettings: mainActorIsolated
    ),
    // The hosted view harness, the recording fakes, and the session model
    // over the scripted agent of `DemoSupport`. This target is not a product.
    // Each test target that links a package target links it too.
    .target(
      name: "AgentViewKitTestSupport",
      dependencies: ["AgentViewKit", "DemoSupport"] + acpProducts,
      swiftSettings: mainActorIsolated
    ),
    // The scripted in-memory ACP agent, the ACP session model, and the launch
    // options of the demo app. The ACP tests link this target. The demo app
    // (Examples/AgentViewKitDemo) compiles its sources into the app. The
    // target is not a product, because the package has exactly one library
    // product (update.md §3, D4).
    .target(
      name: "DemoSupport",
      dependencies: ["AgentViewKit"] + acpProducts,
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
        "AgentViewKitTestSupport",
        // The scripted wire agent and the in-memory demo agent of the ACP
        // tests.
        "DemoSupport",
        // ProtocolVersionTests reads the ACP version decision from disk, and
        // the decision table tests read their tables with MarkdownTable.
        "PackageFileSupport",
      ]
        + acpProducts + editorKitTestSupportProducts,
      // AgentThemeTests reads the token file from disk as data, and
      // ThreadExporterTests reads the golden export file from disk, so the
      // build excludes them.
      exclude: ["Theme/DefaultTokens.json", "Items/Fixtures"],
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
    // The compiled snippets of README.md (plan.md §1). Each `// readme:compile`
    // block of the README is a file in `Examples/ReadmeSnippets/Snippets/`,
    // that `Scripts/extract-readme-snippets.sh` writes. This target compiles
    // the files against the products that a host imports, so a snippet that
    // does not compile fails the build. `ReadmeSnippetTests` in
    // PackageStructureTests holds the README and the files equal. It is a
    // test target, and not in `Sources/`, so that no product links the
    // snippets. It has no default isolation, so that the snippets compile in
    // a host with the language default.
    .testTarget(
      name: "ReadmeSnippetsTests",
      dependencies: ["AgentViewKit"] + acpProducts,
      path: "Examples/ReadmeSnippets"
    ),
  ],
  swiftLanguageModes: [.v6]
)
