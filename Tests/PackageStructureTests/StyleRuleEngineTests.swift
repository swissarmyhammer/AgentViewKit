import EditorTestSupport
import Foundation
import Testing

/// One source rule of EditorKit `style.md` that the package holds with an
/// engine of EditorKit's `EditorTestSupport`: the engine, the directories it
/// reads and the files it permits.
///
/// AgentViewKit keeps no scanner of its own for these rules. Each kit runs the
/// same engine over its own roots with its own allow list, so the rules read
/// the code the same way in every kit (EditorKit ^3q7j9nd).
struct StyleRuleScan: Sendable, CustomTestStringConvertible {
  /// The scan of one engine: the violations under the roots, as
  /// `"<path>:<line>: <text>"`, and each stale entry of the allow list.
  typealias Violations = @Sendable ([URL], PackageFiles, [String: String]) throws -> [String]

  /// The name of the rule, such as `font roles`. A scan of a `StyleRules`
  /// engine has the name of the engine.
  let name: String

  /// The directories that the scan reads, relative to the package root.
  let roots: [String]

  /// The files that may break the rule, relative to the package root, each
  /// with its reason.
  let allowList: [String: String]

  /// The fix that the report of a violation names.
  let advice: String

  /// The engine call.
  let violations: Violations

  var testDescription: String { name }

  /// The scan of a `StyleRules` engine.
  ///
  /// - Parameters:
  ///   - engine: The engine, such as `StyleRuleScanner.fontRoles`.
  ///   - roots: The directories that the scan reads.
  ///   - allowList: The files that may break the rule, each with its reason.
  ///   - advice: The fix that the report of a violation names.
  /// - Returns: The scan, with the name of the engine.
  static func engine(
    _ engine: StyleRuleScanner, roots: [String], allowList: [String: String] = [:], advice: String
  ) -> StyleRuleScan {
    StyleRuleScan(name: engine.name, roots: roots, allowList: allowList, advice: advice) { roots, package, allowList in
      try engine.violations(under: roots, of: package, allowing: allowList)
    }
  }

  /// The violations of the rule in this package.
  ///
  /// - Returns: The violations, then the stale entries of the allow list.
  /// - Throws: The error of a root that is not in the package, or of the
  ///   engine.
  func run() throws -> [String] {
    let package = PackageFiles()
    return try violations(roots.map(package.file), package, allowList)
  }
}

/// Holds the kit to the source rules of EditorKit `style.md` that an engine
/// of EditorKit's `EditorTestSupport` finds: one test for each engine, with
/// the roots and the allow list of this package (``scans``).
///
/// Each engine reads the code of each Swift file, so a form in a comment or in
/// a string literal does not count, and it reports each entry of the allow
/// list whose file no longer breaks the rule. EditorKit tests the forms of
/// each engine, so this suite holds only the configuration.
@Suite struct StyleRuleEngineTests {
  /// The oldest release of each OS that the package supports
  /// (`platforms` in `Package.swift`).
  static let releases = [SymbolNameScanner.Release(platform: "macOS", version: "27.0")]

  /// The directories of the code of the package and of its tests: the
  /// sources, the examples and the README snippets, the root tests and the
  /// tests of the integration package, which take the captures.
  static let allCodePaths = ["Sources", "Examples", "Tests", IntegrationPackage.testsPath]

  /// The files that may read the theme accent, set a tint or inject a theme,
  /// each with the reason (card ^y2mrfxt, D112 (d)).
  ///
  /// The accent is only for the selection and the focus, and the shared
  /// selection surface and the scope focus ring of EditorKit paint it
  /// themselves (`\.themeAccent`, EditorKit ^d5f8cwa). The accent fill of the
  /// citation chip is the one use of the kit (the user decision of
  /// 2026-10-24). The demo is the host app, and the host injects the theme
  /// at the root of each window: the kit sets no theme.
  static let themeInjectionFiles = [
    KitSourceFiles.kitFile("Citations/InlineCitation.swift"):
      "The capsule fill of a citation pill: the citation chip fill, the one accent outside the selection and the focus.",
    "Examples/AgentViewKitDemo/AgentViewKitDemo/AgentViewKitDemoApp.swift":
      "The demo app is the host: it injects the system theme at the root of its window.",
    "Examples/AgentViewKitDemo/AgentViewKitDemoFeature/GalleryLook.swift":
      "The Look popover of the demo host picks one of the EditorKit themes and injects it at the root of the window.",
  ]

  /// The files whose string literals in a symbol type are no symbol names,
  /// each with the reason.
  static let symbolNameFiles = [
    KitSourceFiles.kitFile("Items/ToolKindSymbol.swift"):
      """
      ToolStatusSymbol holds the wire value `_lost` and the label `Result lost` of a lost result, which \
      are no symbol names; each symbol of the file is a SharedSymbol constant.
      """
  ]

  /// The files that may paint a fill, each with the reason: a link, a small
  /// chip that is not a card, and terminal data (D113 answer 1). A selection
  /// draws through the shared selection surface of EditorKit
  /// (``SelectionFillTests``), so no selection is in the list (card ^dn1m56r).
  static let contentFillFiles = [
    KitSourceFiles.styleFile("Chips/ToolCallLocationChips.swift"): "The capsule fill of a tool call badge: a small chip.",
    KitSourceFiles.kitFile("Attachments/AttachmentChip.swift"): "The fill of an attachment chip: a small chip.",
    KitSourceFiles.kitFile("Sessions/PendingRequestCountBadge.swift"):
      "The capsule fill of the pending-request badge: a small chip.",
    KitSourceFiles.kitFile("Code/EditorBlockChrome.swift"):
      "The TerminalPalette background of terminal output: terminal data (AVK-8aa, choice B).",
    KitSourceFiles.kitFile("Citations/InlineCitation.swift"): "The fill of a citation chip: a link.",
  ]

  /// The scan of each rule, with the roots and the allow list of the
  /// package.
  ///
  /// The view rules read the kit, its style library, the demo support and the
  /// examples (``KitSourceFiles/viewPaths``, ``SystemStructureTests/scanPaths``).
  /// The test code is not a view of the kit, so no view rule reads it. The
  /// rule of the real capture reads the tests too (``allCodePaths``).
  static let scans: [StyleRuleScan] = [
    .engine(
      .textInputControls, roots: ["Sources", "Examples"],
      advice: "Use an EditorKit editor for each text input (style.md, Text input)."),
    .engine(
      .fontRoles, roots: KitSourceFiles.viewPaths,
      advice: "Use a font role of the EditorKit theme (editorTheme.font(for:style:), uiFont, displayFont, codeFont)."),
    .engine(
      .themeInjection, roots: SystemStructureTests.scanPaths, allowList: themeInjectionFiles,
      advice: """
        No action has a tint or a prominent button style, the accent marks only the selection, the focus and \
        the fill of the citation chip, and the kit sets no theme (D111 step 7, D112 (d), D113 answer 6, cards \
        ^k06v4gt and ^y2mrfxt).
        """),
    .engine(
      .fixedColors, roots: KitSourceFiles.viewPaths,
      advice: "Use a color of the EditorKit theme, and no system background (D111 step 1)."),
    .engine(
      .contentFills, roots: SystemStructureTests.scanPaths, allowList: contentFillFiles,
      advice: "Content has no fill (D113 answer 1). Use a .separator stroke."),
    .engine(
      .systemStructure, roots: SystemStructureTests.scanPaths,
      advice: "The system gives the look of the bars, the sidebar and the inspector (D111 steps 2 and 6)."),
    .engine(
      .glassPlacement, roots: SystemStructureTests.scanPaths,
      advice: "Use the floating glass of EditorStyle on a floating control (D110 (b), (c), D113 answer 2)."),
    .engine(
      .offscreenRenderers, roots: allCodePaths,
      advice: "A test captures the real window from the window server (style.md rule 9)."),
    StyleRuleScan(
      name: "symbol names", roots: KitSourceFiles.viewPaths, allowList: symbolNameFiles,
      advice: "Use an SF Symbol of macOS 27 by its current name (style.md, SF Symbols)."
    ) { roots, package, allowList in
      try SymbolNameScanner.violations(under: roots, of: package, allowing: allowList, releases: releases)
    },
    StyleRuleScan(
      name: "hosted serial", roots: [IntegrationPackage.testsPath], allowList: [:],
      advice: "Run each test that mounts a window under .hostedSerially."
    ) { roots, package, allowList in
      try HostedSerialScanner.violations(under: roots, of: package, allowing: allowList)
    },
    StyleRuleScan(
      name: "preview coverage", roots: ["Sources"], allowList: [:],
      advice: "Add a #Preview that shows each public view."
    ) { roots, package, allowList in
      try PreviewCoverageScanner.violations(under: roots, of: package, allowing: allowList)
    },
  ]

  @Test(arguments: scans)
  func noSourceBreaksTheRule(scan: StyleRuleScan) throws {
    let found = try scan.run()
    let report = found.map { "  \($0)" }.joined(separator: "\n")

    #expect(found.isEmpty, "\(scan.advice) Found:\n\(report)")
  }

  /// A new engine of EditorKit's `StyleRules` gets a scan here, with the
  /// roots of the package.
  @Test func eachEngineOfTheStyleRulesHasAScan() {
    let scanned = Set(Self.scans.map(\.name))

    #expect(Set(StyleRuleScanner.all.map(\.name)).isSubset(of: scanned))
  }

  /// A root that moved would give no files, and the scan would pass with no
  /// files. Thus each root must hold Swift files.
  @Test(arguments: Set(scans.flatMap(\.roots)).sorted())
  func eachRootHoldsSwiftFiles(path: String) throws {
    let files = swiftFiles(under: try PackageFiles().file(path))

    #expect(!files.isEmpty, "\(path)")
  }
}
