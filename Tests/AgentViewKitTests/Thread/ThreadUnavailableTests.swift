import AgentViewKitTestSupport
import EditorCommands
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// Tests for the unavailable state of a thread (TestudoApp D208 (i)): the
/// message of `threadUnavailable(_:)` in place of the transcript, and the
/// read verbs that it stops.
///
/// The slot tests lay out a ``ThreadTranscriptSlot`` with probes in an
/// `NSHostingView` with no window. The verb tests read the availability of
/// a target with no view. No test shows a window or takes the focus.
@MainActor struct ThreadUnavailableTests {
  /// The message of the host for a session that the owner stopped sharing.
  static let message = "The owner stopped sharing this session."

  /// The reason of each read verb in the unavailable state.
  static let reason = "The session is not available."

  /// The verbs that read the transcript. The unavailable state stops them.
  nonisolated static let readVerbs: [AgentCommandVerb] = [
    .copyThread, .exportMarkdown, .findNextHit, .findPreviousHit, .clearSearchHits, .copyMessage,
    .copyCodeBlock,
  ]

  /// The navigation verbs that act on the list of the transcript. The
  /// unavailable state stops them, because no list shows.
  nonisolated static let listVerbs: [AgentCommandVerb] = [
    .jumpToNext, .jumpToPrevious, .scrollToBottom, .toggleExpandAll,
  ]

  /// The navigation verbs that act on the session tree. The unavailable
  /// state does not stop them.
  nonisolated static let sessionVerbs: [AgentCommandVerb] = [.goToParent, .openChild]

  /// Makes a fixture of a read-only thread of two turns, with the scroll
  /// anchors and the expanded items of a list. The first answer is in view,
  /// so a prompt is above it and a prompt is below it.
  ///
  /// - Returns: The fixture.
  static func makeListFixture() -> ReadOnlyThreadTests.Fixture {
    let model = ReadOnlyThreadTests.readOnlyModel(ReadOnlyThreadTests.newerUpdates)
    let fixture = ReadOnlyThreadTests.makeFixture(session: model)
    let anchors = ScrollAnchorManager()
    let firstAnswer = model.transcript.map(\.rowKey)[1]
    anchors.noteVisible(ids: [firstAnswer], distanceFromBottom: .greatestFiniteMagnitude)
    fixture.target.anchors = anchors
    fixture.target.expandedBlocks = ExpandedBlocksStore()
    return fixture
  }

  /// The records of the two probes of one slot test.
  struct Records {
    /// The record of the probe in the place of the transcript.
    let transcript = SlotProbeRecord()
    /// The record of the probe in the place of the unavailable message.
    let unavailable = SlotProbeRecord()
  }

  /// Lays out a transcript slot with a probe in each place.
  ///
  /// - Parameter message: The unavailable message, or `nil`.
  /// - Returns: The records of the probes.
  static func layOutSlot(message: String?) -> Records {
    let records = Records()
    StyleViewHost.layOut(
      ThreadTranscriptSlot(message: message) {
        SlotProbe(record: records.transcript)
      } unavailable: { text in
        SlotProbe(record: records.unavailable, text: text)
      }
      .frame(width: ThreadHeaderTests.width, height: ThreadHeaderTests.height))
    return records
  }

  // MARK: - Slot

  /// A production change that fails this test: the slot does not give the
  /// message to the unavailable view.
  @Test func theUnavailableStateShowsItsText() {
    let records = Self.layOutSlot(message: Self.message)

    #expect(records.unavailable.text == Self.message)
  }

  /// A production change that fails this test: the slot shows the
  /// transcript with a message.
  @Test func theUnavailableStateHidesTheTranscript() throws {
    let records = Self.layOutSlot(message: Self.message)
    // The slot showed the message, so the layout ran.
    try #require(records.unavailable.isShown)

    #expect(!records.transcript.isShown)
  }

  /// A production change that fails this test: the slot hides the
  /// transcript with no message.
  @Test func noMessageShowsTheTranscript() {
    let records = Self.layOutSlot(message: nil)

    #expect(records.transcript.isShown)
  }

  /// A production change that fails this test: the slot shows the
  /// unavailable view with no message.
  @Test func noMessageShowsNoUnavailableText() throws {
    let records = Self.layOutSlot(message: nil)
    // The slot showed the transcript, so the layout ran.
    try #require(records.transcript.isShown)

    #expect(!records.unavailable.isShown)
  }

  // MARK: - Pill

  /// A production change that fails this test: the thread shows the
  /// scroll-to-bottom pill over the message, where no list shows.
  @Test func theUnavailableStateShowsNoScrollToBottomPill() {
    #expect(!AgentThreadLayout.showsPill(unavailableMessage: Self.message))
  }

  /// A production change that fails this test: the thread hides the
  /// scroll-to-bottom pill of the transcript with no message.
  @Test func noMessageShowsTheScrollToBottomPill() {
    #expect(AgentThreadLayout.showsPill(unavailableMessage: nil))
  }

  // MARK: - Verbs

  /// A production change that fails this test: the target does not stop
  /// the verb in the unavailable state, or gives a different reason.
  @Test(arguments: readVerbs)
  func aReadVerbOfAnUnavailableThreadHasTheReason(_ verb: AgentCommandVerb) {
    let fixture = ReadOnlyThreadTests.makeFixture(session: ReadOnlyThreadTests.readOnlyModel())
    fixture.target.isSessionUnavailable = true
    let availability = fixture.target.availability(of: verb, payload: nil)

    #expect(availability == .unavailable(reason: Self.reason))
  }

  /// A production change that fails this test: the target stops Copy
  /// Thread with no unavailable state.
  @Test func copyThreadOfAThreadThatIsNotUnavailableIsAvailable() {
    let fixture = ReadOnlyThreadTests.makeFixture(session: ReadOnlyThreadTests.readOnlyModel())

    #expect(fixture.target.availability(of: .copyThread, payload: nil) == .available)
  }

  /// A production change that fails this test: the target does not stop
  /// the list verb in the unavailable state, or gives a different reason.
  @Test(arguments: listVerbs)
  func aListVerbOfAnUnavailableThreadHasTheReason(_ verb: AgentCommandVerb) {
    let fixture = Self.makeListFixture()
    fixture.target.isSessionUnavailable = true

    let availability = fixture.target.availability(of: verb, payload: nil)

    #expect(availability == .unavailable(reason: Self.reason))
  }

  /// A production change that fails this test: the target stops the list
  /// verb with no unavailable state.
  @Test(arguments: listVerbs)
  func aListVerbOfAThreadThatIsNotUnavailableIsAvailable(_ verb: AgentCommandVerb) {
    let fixture = Self.makeListFixture()

    #expect(fixture.target.availability(of: verb, payload: nil) == .available)
  }

  /// A production change that fails this test: the target stops a verb of
  /// the session tree in the unavailable state.
  @Test(arguments: sessionVerbs)
  func aSessionVerbOfAnUnavailableThreadIsAvailable(_ verb: AgentCommandVerb) async throws {
    let (session, fixture, _) = try await SessionCommandsTests.open(
      shown: SessionCommandsTests.first)
    defer { session.close() }
    fixture.target.isSessionUnavailable = true

    #expect(fixture.target.availability(of: verb, payload: nil) == .available)
  }
}
