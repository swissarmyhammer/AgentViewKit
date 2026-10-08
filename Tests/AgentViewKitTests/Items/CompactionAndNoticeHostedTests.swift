#if DEBUG
  import AgentViewKit
  import AgentViewKitTestSupport
  import Foundation
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// The compaction rows and the notice banners of a `SessionModel`
  /// (plan.md §3.2 "Notices"; the owner decision of 2026-10-04 in
  /// Docs/decisions/acp-client-kit.md).
  @Suite(.serialized, .hostedSerially) @MainActor struct CompactionAndNoticeHostedTests {
    /// The longest time that a test waits for a change, in seconds.
    static let waitTimeout: TimeInterval = 5

    /// A size that shows each row and each banner of the tests.
    static let tallSize = CGSize(width: 480, height: 1_200)

    /// The `compactionId` of the compaction of the tests.
    static let compactionID = "tests-compaction"

    /// The text of the summary chunk of the compaction.
    static let summaryText = "Kept the plan and the open files."

    /// The reason of the failed compaction.
    static let failureReason = "The model context is too small."

    /// The title of the notice of the tests.
    static let noticeTitle = "Quota low"

    /// The description of the notice of the tests.
    static let noticeDescription = "Half of the monthly quota is used."

    /// The row key of the compaction of the tests.
    static var compactionKey: String {
      TranscriptEntry.ID.wire(.compaction(Unstable.CompactionId(rawValue: compactionID))).rowKey
    }

    /// A `compaction_update` value for the compaction of the tests.
    ///
    /// - Parameter fields: The other fields of the update, as JSON members.
    /// - Returns: The JSON text of the update.
    static func compactionUpdate(_ fields: String) -> String {
      #"{"sessionUpdate": "compaction_update", "compactionId": "\#(compactionID)", \#(fields)}"#
    }

    /// An `agent_message_chunk` value.
    ///
    /// - Parameter messageID: The `messageId` of the chunk.
    /// - Returns: The JSON text of the update.
    static func agentChunk(messageID: String) -> String {
      #"{"sessionUpdate": "agent_message_chunk", "messageId": "\#(messageID)", "content": {"type": "text", "text": "Done."}}"#
    }

    /// A `notice` value with the title and the description of the tests.
    ///
    /// - Parameter severity: The wire value of the severity.
    /// - Returns: The JSON text of the update.
    static func notice(severity: String) -> String {
      #"""
      {"sessionUpdate": "notice", "severity": "\#(severity)", "title": "\#(noticeTitle)",
       "description": "\#(noticeDescription)"}
      """#
    }

    /// Mounts the thread of `session`.
    ///
    /// - Parameter session: The scripted session.
    /// - Returns: The harness.
    static func mountThread(_ session: ScriptedSession) -> HostedViewHarness<some View> {
      HostedViewHarness(size: tallSize) {
        AgentThreadView(session: session.model)
          .transaction { $0.disablesAnimations = true }
      }
    }

    /// The label of the compaction row of the tests in `harness`.
    ///
    /// - Parameter harness: The harness that shows the thread.
    /// - Returns: The label, or `nil` when the row does not show.
    static func compactionLabel<Content: View>(in harness: HostedViewHarness<Content>) -> String? {
      harness.element(identifier: CompactionEntryView.identifier(for: compactionKey))?.label
    }

    // MARK: - Compaction

    @Test func aCompactionUpdateShowsOneRowAtItsPosition() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mountThread(session)
      defer { harness.close() }

      try await session.sendUpdate(Self.agentChunk(messageID: "before"))
      try await session.sendUpdate(Self.compactionUpdate(#""status": "in_progress""#))
      try await session.sendUpdate(Self.agentChunk(messageID: "after"))
      try await session.sendUpdate(Self.compactionUpdate(#""status": "completed""#))
      await harness.pump(until: Self.waitTimeout) {
        Self.compactionLabel(in: harness) == "Context compaction, Completed"
      }

      let keys = session.model.transcript.map(\.rowKey)
      #expect(keys.count == 3)
      #expect(keys.dropFirst().first == Self.compactionKey)
      #expect(SessionTranscriptViewHostedTests.rowKeys(in: harness) == keys)
      #expect(Self.compactionLabel(in: harness) == "Context compaction, Completed")
      #expect(harness.element(identifier: UnknownItemView.identifier) == nil)
    }

    @Test func aSummaryChunkBeforeAnyUpdateShowsNoStatusYetAndTheSummary() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mountThread(session)
      defer { harness.close() }

      try await session.sendUpdate(
        #"""
        {"sessionUpdate": "compaction_summary_chunk", "compactionId": "\#(Self.compactionID)",
         "content": {"type": "text", "text": "\#(Self.summaryText)"}}
        """#)
      await harness.pump(until: Self.waitTimeout) {
        harness.accessibilityElements().contains { $0.label?.contains(Self.summaryText) == true }
      }

      #expect(Self.compactionLabel(in: harness) == "Context compaction, No status yet")
      #expect(harness.accessibilityElements().contains { $0.label?.contains(Self.summaryText) == true })
    }

    @Test func aFailedCompactionShowsItsReason() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mountThread(session)
      defer { harness.close() }

      try await session.sendUpdate(
        Self.compactionUpdate(#""status": "failed", "error": "\#(Self.failureReason)""#))
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: CompactionEntryView.errorIdentifier) != nil
      }

      #expect(Self.compactionLabel(in: harness) == "Context compaction, Failed")
      #expect(harness.element(identifier: CompactionEntryView.errorIdentifier)?.label == Self.failureReason)
    }

    // MARK: - Notices

    @Test func aNoticeShowsABannerWithItsSeverityTitleAndDescription() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mountThread(session)
      defer { harness.close() }

      try await session.sendUpdate(Self.notice(severity: "warning"))
      await harness.pump(until: Self.waitTimeout) { !session.model.notices.isEmpty }
      let notice = try #require(session.model.notices.first)
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: SessionNoticeBanner.identifier(for: notice.id)) != nil
      }

      #expect(
        harness.element(identifier: SessionNoticeBanner.identifier(for: notice.id))?.label
          == "Warning, \(Self.noticeTitle), \(Self.noticeDescription)")
      #expect(session.model.transcript.isEmpty)
    }

    @Test func eachNoticeShowsItsOwnBanner() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mountThread(session)
      defer { harness.close() }

      try await session.sendUpdate(Self.notice(severity: "info"))
      try await session.sendUpdate(Self.notice(severity: "error"))
      await harness.pump(until: Self.waitTimeout) { session.model.notices.count == 2 }
      let ids = session.model.notices.map(\.id)
      await harness.pump(until: Self.waitTimeout) {
        ids.allSatisfy { harness.element(identifier: SessionNoticeBanner.identifier(for: $0)) != nil }
      }

      let labels = ids.map { harness.element(identifier: SessionNoticeBanner.identifier(for: $0))?.label }
      #expect(
        labels == [
          "Information, \(Self.noticeTitle), \(Self.noticeDescription)",
          "Error, \(Self.noticeTitle), \(Self.noticeDescription)",
        ])
    }

    @Test func theDismissButtonRemovesTheNoticeFromTheModel() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mountThread(session)
      defer { harness.close() }

      try await session.sendUpdate(Self.notice(severity: "info"))
      await harness.pump(until: Self.waitTimeout) { !session.model.notices.isEmpty }
      let notice = try #require(session.model.notices.first)
      let dismiss = SessionNoticeBanner.dismissIdentifier(for: notice.id)
      await harness.pump(until: Self.waitTimeout) { harness.element(identifier: dismiss) != nil }

      try harness.press(identifier: dismiss)
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: SessionNoticeBanner.identifier(for: notice.id)) == nil
      }

      #expect(session.model.notices.isEmpty)
      #expect(harness.element(identifier: SessionNoticeBanner.identifier(for: notice.id)) == nil)
    }
  }
#endif
