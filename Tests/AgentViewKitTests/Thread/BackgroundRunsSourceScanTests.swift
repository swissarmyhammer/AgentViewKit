import EditorTestSupport
import Foundation
import Testing

/// The source scan of the background runs (plan.md §3.8 "Background runs").
///
/// The kit keeps no state for the order of the background runs. The hosted
/// tests of the thread view are in `BackgroundRunsHostedTests` of the
/// IntegrationTests package.
@Suite struct BackgroundRunsSourceScanTests {
  /// The names that a kit source must not declare: a kit copy of the turn,
  /// of the time of the last text, or of a wait for background work.
  static let turnStateNames = ["currentTurn", "lastText", "isWaiting", "waitingFor", "backgroundWork"]

  @Test func noKitSourceDeclaresATurnOrAWaitState() throws {
    let files = try swiftFiles(under: PackageFiles().file("Sources/AgentViewKit"))
    let names = Self.turnStateNames.joined(separator: "|")
    let declaration = try Regex(#"\b(let|var)\s+(\#(names))\w*\b"#)
    #expect(!files.isEmpty)

    let declarations = try SourceLines.matching(declaration, in: files)

    #expect(declarations.isEmpty, "A kit source keeps a turn or a wait state: \(declarations)")
  }
}
