import EditorTestSupport
import Foundation
import Testing

/// The source scan of the entry views of a message.
///
/// The entry views show the ACP content of a transcript entry with no copy
/// into a kit record. The hosted tests of the message views are in
/// `MessageViewsHostedTests` of the IntegrationTests package.
@Suite struct MessageViewsSourceScanTests {
  /// The kit sources of the entry views. They show the ACP content of a
  /// transcript entry with no copy into a kit record.
  static let entryViewSources = [
    "Sources/AgentViewKit/Items/TranscriptMessageView.swift",
    "Sources/AgentViewKit/Items/ThoughtEntryBlock.swift",
    "Sources/AgentViewKit/Items/CompactionEntryView.swift",
    "Sources/AgentViewKit/Content/EntryContentView.swift",
  ]

  @Test func theEntryViewsMakeNoKitCopyOfTheEntryContent() throws {
    let files = try Self.entryViewSources.map { try PackageFiles().file($0) }
    let copy = try Regex(#"\bMessage\(|\bReasoning\(|AgentViewKit\.ContentBlock"#)

    let copies = try SourceLines.matching(copy, in: files)

    #expect(copies.isEmpty, "An entry view copies the entry content into a kit record: \(copies)")
  }
}
