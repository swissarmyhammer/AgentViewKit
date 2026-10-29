import Foundation
import Testing

/// The source scan of the status views (plan.md §3.8 "Agent state and stop
/// reasons").
///
/// No source of the status views keeps a copy of the stream state of the
/// session model. The hosted tests of the state banners are in
/// `SessionStateBannersHostedTests` of the IntegrationTests package.
@Suite struct SessionStateBannersSourceScanTests {
  /// The names of the stream state of the session model. No source of the
  /// status views declares a property with one of these names.
  static let streamStateNames = ["agentState", "hasMissedUpdates", "isReplaying", "history", "isClosed"]

  // MARK: - No copy

  @Test func noStatusSourceDeclaresACopyOfTheStreamState() throws {
    let statusDirectory = URL(filePath: #filePath)
      .deletingLastPathComponent()
      .appending(path: "../../../Sources/AgentViewKit/Status")
      .standardizedFileURL
    let files = try FileManager.default.contentsOfDirectory(at: statusDirectory, includingPropertiesForKeys: nil)
      .filter { $0.pathExtension == "swift" }
    let names = Self.streamStateNames.joined(separator: "|")
    let declaration = try Regex(#"\b(let|var)\s+(\#(names))\b"#)
    #expect(!files.isEmpty)

    let copies = try SourceLines.matching(declaration, in: files)

    #expect(copies.isEmpty, "A status source keeps a copy of the stream state: \(copies)")
  }
}
