@testable import AgentViewKit
import Testing

/// When the stream banner shows the note that the history can be partial.
@Suite struct PartialHistoryNoteTests {
  @Test func aRetainedHistoryWithEntriesAfterTheReplayShowsTheNote() {
    #expect(SessionStreamBanner.showsPartialHistoryNote(isHistoryRetained: true, isReplaying: false, hasEntries: true))
  }

  @Test func aRetainedHistoryWithNoEntryShowsNoNote() {
    #expect(
      !SessionStreamBanner.showsPartialHistoryNote(isHistoryRetained: true, isReplaying: false, hasEntries: false))
  }

  @Test func aReplayThatRunsShowsNoNote() {
    #expect(!SessionStreamBanner.showsPartialHistoryNote(isHistoryRetained: true, isReplaying: true, hasEntries: true))
  }

  @Test func aHistoryThatIsNotRetainedShowsNoNote() {
    #expect(
      !SessionStreamBanner.showsPartialHistoryNote(isHistoryRetained: false, isReplaying: false, hasEntries: true))
  }
}
