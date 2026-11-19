import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import Testing
@testable import AgentViewKit

/// Tests for Find Next Hit, Find Previous Hit and Clear Search Hits, the Esc
/// of the search hits of a thread (D207 (f), D133, D137 (a)).
///
/// Each test uses a preview session model and a registry or a harness with
/// no window. A text input has the focus through the first responder seam
/// of the target, with a text view that is in no window.
@MainActor struct FindHitCommandsTests {
  /// The objects of one test.
  struct Fixture {
    /// The harness fixture of the thread scope.
    let commands: AgentCommandsTests.Fixture
    /// The session model of the scope.
    let session: SessionModel
    /// The search of the thread.
    let search: TranscriptSearch
    /// The count of the removals of the hits of the host.
    let removals: CallCounter
  }

  /// Makes a scope for a session of a user message and an agent message,
  /// with a search that shows hits in the entries of `entries`.
  ///
  /// - Parameters:
  ///   - entries: The positions of the entries with a hit, best first.
  ///   - configure: Changes to the target before the test.
  /// - Returns: The fixture.
  static func makeFixture(
    hitsIn entries: [Int], configure: (AgentCommandTarget) -> Void = { _ in }
  ) -> Fixture {
    let session = SessionModel.preview(transcript: [
      .user("Why does the parser fail?"), .agent("The parser fails."),
    ])
    let ids = session.transcript.compactMap(TranscriptSearchTests.wireID)
    let search = TranscriptSearchTests.search(
      showing: TranscriptSearchTests.hits(entries.map { ids[$0] }), in: session)
    let removals = CallCounter()
    search.hostRemoval = { removals.count += 1 }
    let commands = AgentCommandsTests.makeFixture(session: session) { target in
      target.transcriptSearch = search
      configure(target)
    }
    return Fixture(commands: commands, session: session, search: search, removals: removals)
  }

  /// Makes the first responder of the target an editable text view, as a
  /// text input with the focus.
  ///
  /// - Parameter target: The target.
  static func focusTextInput(of target: AgentCommandTarget) {
    let textView = NSTextView()
    target.firstResponder = { textView }
  }

  /// The reason of `verb` in `fixture`, or `nil` when the verb is available.
  ///
  /// - Parameters:
  ///   - verb: The verb.
  ///   - fixture: The fixture.
  /// - Returns: The reason.
  static func reason(of verb: AgentCommandVerb, in fixture: Fixture) -> String? {
    UnavailableReasonTests.reason(of: verb, in: fixture.commands)
  }

  /// A registry with the thread scope of `fixture`, as the mount of the
  /// scope registers it.
  ///
  /// - Parameters:
  ///   - fixture: The fixture.
  ///   - groupsOff: The groups that are off.
  /// - Returns: The registry.
  static func registry(
    of fixture: Fixture, groupsOff: Set<AgentCommandGroup> = []
  ) -> CommandRegistry {
    var registry = CommandRegistry()
    AgentCommandRegistration.register(
      fixture.commands.target, at: fixture.commands.path, into: &registry, groupsOff: groupsOff)
    return registry
  }

  // MARK: - Verbs

  @Test func findNextHitIsCommandGInTheFindGroup() {
    let verb = AgentCommandVerb.findNextHit

    #expect(verb.id == "agent.findNextHit")
    #expect(verb.title == "Find Next Hit")
    #expect(verb.group == .find)
    #expect(verb.presentation.key == "⌘G")
  }

  @Test func findPreviousHitIsShiftCommandGInTheFindGroup() {
    let verb = AgentCommandVerb.findPreviousHit

    #expect(verb.id == "agent.findPreviousHit")
    #expect(verb.title == "Find Previous Hit")
    #expect(verb.group == .find)
    #expect(verb.presentation.key == "⇧⌘G")
  }

  @Test func clearSearchHitsIsEscapeInTheFindGroup() {
    let verb = AgentCommandVerb.clearSearchHits

    #expect(verb.id == "agent.clearSearchHits")
    #expect(verb.title == "Clear Search Hits")
    #expect(verb.group == .find)
    #expect(verb.presentation.key == .escape)
  }

  @Test func theFindVerbsAreInTheFindGroupOfTheEditMenu() throws {
    let next = try #require(AgentCommandVerb.findNextHit.menu)
    let previous = try #require(AgentCommandVerb.findPreviousHit.menu)

    #expect(next.path == .edit && previous.path == .edit)
    #expect(next.group == previous.group)
    #expect(next.order < previous.order)
  }

  /// A production change that fails this test: Clear Search Hits is in
  /// another menu or group, or before the rows of the steps.
  @Test func clearSearchHitsIsAfterTheStepsInTheFindGroupOfTheEditMenu() throws {
    let previous = try #require(AgentCommandVerb.findPreviousHit.menu)
    let clear = try #require(AgentCommandVerb.clearSearchHits.menu)

    #expect(clear.path == .edit)
    #expect(clear.group == previous.group)
    #expect(previous.order < clear.order)
  }

  // MARK: - Visibility of Clear Search Hits

  /// Tells if the surfaces show Clear Search Hits at the path of the
  /// thread scope of `fixture`.
  ///
  /// - Parameter fixture: The fixture.
  /// - Returns: `true` when the row of the command is visible, `nil` when
  ///   the registry has no row of the command.
  static func showsClearSearchHits(in fixture: Fixture) -> Bool? {
    Self.registry(of: fixture)
      .row(of: AgentCommandVerb.clearSearchHits.id, at: fixture.commands.path)?.isVisible
  }

  /// A production change that fails this test: the Edit menu and the
  /// palette show a disabled Clear Search Hits row while the thread has no
  /// hits.
  @Test func clearSearchHitsWithNoHitsIsHidden() {
    let fixture = Self.makeFixture(hitsIn: [])

    #expect(Self.showsClearSearchHits(in: fixture) == false)
  }

  /// A production change that fails this test: the surfaces do not show
  /// Clear Search Hits while it can run.
  @Test func clearSearchHitsWithHitsIsShown() {
    let fixture = Self.makeFixture(hitsIn: [0])

    #expect(Self.showsClearSearchHits(in: fixture) == true)
  }

  /// A production change that fails this test: the surfaces show Clear
  /// Search Hits while a text input has the focus, where it cannot run.
  @Test func clearSearchHitsInATextInputIsHidden() {
    let fixture = Self.makeFixture(hitsIn: [0]) { Self.focusTextInput(of: $0) }

    #expect(Self.showsClearSearchHits(in: fixture) == false)
  }

  // MARK: - Availability

  /// A production change that fails this test: Find Next Hit runs with no
  /// hits.
  @Test func findNextHitWithNoHitsIsNotAvailable() {
    let fixture = Self.makeFixture(hitsIn: [])

    #expect(Self.reason(of: .findNextHit, in: fixture) == "The thread has no search hits.")
  }

  /// A production change that fails this test: Find Previous Hit runs
  /// with no hits.
  @Test func findPreviousHitWithNoHitsIsNotAvailable() {
    let fixture = Self.makeFixture(hitsIn: [])

    #expect(Self.reason(of: .findPreviousHit, in: fixture) == "The thread has no search hits.")
  }

  /// A production change that fails this test: ⌘G in a text input goes to
  /// the hits, and not to the find of the editor (D133).
  @Test func findNextHitInATextInputIsNotAvailable() {
    let fixture = Self.makeFixture(hitsIn: [0, 1]) { Self.focusTextInput(of: $0) }

    #expect(Self.reason(of: .findNextHit, in: fixture) == "The focus is in a text input.")
  }

  /// A production change that fails this test: ⇧⌘G in a text input goes to
  /// the hits.
  @Test func findPreviousHitInATextInputIsNotAvailable() {
    let fixture = Self.makeFixture(hitsIn: [0, 1]) { Self.focusTextInput(of: $0) }

    #expect(Self.reason(of: .findPreviousHit, in: fixture) == "The focus is in a text input.")
  }

  /// A production change that fails this test: a text view that does not
  /// edit, such as a selectable message, stops the command.
  @Test func findNextHitInATextThatDoesNotEditIsAvailable() {
    let fixture = Self.makeFixture(hitsIn: [0, 1]) { target in
      let label = NSTextView()
      label.isEditable = false
      target.firstResponder = { label }
    }

    #expect(Self.reason(of: .findNextHit, in: fixture) == nil)
  }

  /// A production change that fails this test: a text view that does not
  /// edit stops Find Previous Hit.
  @Test func findPreviousHitInATextThatDoesNotEditIsAvailable() {
    let fixture = Self.makeFixture(hitsIn: [0, 1]) { target in
      let label = NSTextView()
      label.isEditable = false
      target.firstResponder = { label }
    }

    #expect(Self.reason(of: .findPreviousHit, in: fixture) == nil)
  }

  /// A production change that fails this test: the command runs with no
  /// thread list in the scope.
  @Test func findNextHitWithNoThreadListIsNotAvailable() {
    let fixture = Self.makeFixture(hitsIn: [0]) { $0.transcriptSearch = nil }

    #expect(Self.reason(of: .findNextHit, in: fixture) == UnavailableReasonTests.listNotShown)
  }

  /// A production change that fails this test: Find Previous Hit runs with
  /// no thread list in the scope.
  @Test func findPreviousHitWithNoThreadListIsNotAvailable() {
    let fixture = Self.makeFixture(hitsIn: [0]) { $0.transcriptSearch = nil }

    #expect(Self.reason(of: .findPreviousHit, in: fixture) == UnavailableReasonTests.listNotShown)
  }

  // MARK: - Run

  /// A production change that fails this test: the command does not step
  /// the search.
  @Test func findNextHitMakesTheNextHitCurrent() {
    let fixture = Self.makeFixture(hitsIn: [0, 1])

    #expect(fixture.commands.system.perform(AgentCommandVerb.findNextHit.id))

    #expect(fixture.search.currentHit?.position == 1)
  }

  /// A production change that fails this test: Find Previous Hit steps
  /// forward.
  @Test func findPreviousHitMakesThePreviousHitCurrent() {
    let fixture = Self.makeFixture(hitsIn: [1, 0])

    #expect(fixture.commands.system.perform(AgentCommandVerb.findPreviousHit.id))

    #expect(fixture.search.currentHit?.position == 0)
  }

  // MARK: - Esc

  /// A production change that fails this test: Esc in the thread with hits
  /// stops the agent or does nothing, and the hits stay.
  @Test func escapeWithHitsResolvesToClearSearchHits() {
    let fixture = Self.makeFixture(hitsIn: [0])
    let registry = Self.registry(of: fixture)

    #expect(
      registry.resolveKey(KeyChord.escape.asSequence, mode: .cua, at: fixture.commands.path)
        == .command(AgentCommandVerb.clearSearchHits.id, scope: fixture.commands.path))
  }

  /// A production change that fails this test: Clear Search Hits does not
  /// give the removal to the host.
  @Test func escapeWithHitsRemovesTheHitsOfTheHost() {
    let fixture = Self.makeFixture(hitsIn: [0])
    let registry = Self.registry(of: fixture)

    _ = registry.performKey(KeyChord.escape.asSequence, mode: .cua, at: fixture.commands.path)

    #expect(fixture.removals.count == 1)
  }

  /// A production change that fails this test: Esc with no hits takes the
  /// key, so `nav.drillOut` of the window does not get it.
  @Test func escapeWithNoHitsIsNotTaken() {
    let fixture = Self.makeFixture(hitsIn: [])
    let registry = Self.registry(of: fixture)

    let resolution = registry.resolveKey(
      KeyChord.escape.asSequence, mode: .cua, at: fixture.commands.path)
    #expect(resolution == .unbound)
  }

  /// A production change that fails this test: Esc with no hits gives the
  /// removal to the host.
  @Test func escapeWithNoHitsDoesNotRemoveTheHits() {
    let fixture = Self.makeFixture(hitsIn: [])
    let registry = Self.registry(of: fixture)

    _ = registry.performKey(KeyChord.escape.asSequence, mode: .cua, at: fixture.commands.path)

    #expect(fixture.removals.count == 0)
  }

  /// A production change that fails this test: Esc in a text input removes
  /// the hits, and the text input does not keep its Esc (D137 (d)).
  @Test func escapeInATextInputDoesNotRemoveTheHits() {
    let fixture = Self.makeFixture(hitsIn: [0]) { Self.focusTextInput(of: $0) }
    let registry = Self.registry(of: fixture)

    let resolution = registry.resolveKey(
      KeyChord.escape.asSequence, mode: .cua, at: fixture.commands.path)
    #expect(resolution == .unbound)
  }

  /// A production change that fails this test: with hits, Esc stops the
  /// agent before it removes the hits.
  @Test func clearSearchHitsComesBeforeStop() {
    let fixture = Self.makeFixture(hitsIn: [0])
    let registry = Self.registry(of: fixture)

    let actions = registry.keymapStack(for: .cua, at: fixture.commands.path)
      .bindings(for: KeyChord.escape.asSequence).map(\.action)

    let verbs: [AgentCommandVerb] = [.clearSearchHits, .cancel]
    #expect(actions == verbs.map { .command($0.id) })
  }

  /// A production change that fails this test: with hits while the agent
  /// runs, the first Esc stops the agent, or the second Esc does not.
  ///
  /// The host of the test removes the hits as the binding of a host does,
  /// and the preview session folds the `running` state at once.
  @Test func theFirstEscapeClearsTheHitsAndTheSecondStops() throws {
    let starts = ReportRecorder<String>()
    let fixture = Self.makeFixture(hitsIn: [0]) { $0.requestStartReport = starts.report }
    fixture.search.hostRemoval = { [weak search = fixture.search, session = fixture.session] in
      search?.show(nil, in: session)
    }
    fixture.session.apply(.stateUpdate(.running(RunningStateUpdate())))
    let registry = Self.registry(of: fixture)
    let escape = KeyChord.escape.asSequence

    _ = registry.performKey(escape, mode: .cua, at: fixture.commands.path)
    try #require(fixture.search.hits.isEmpty && starts.values.isEmpty)
    _ = registry.performKey(escape, mode: .cua, at: fixture.commands.path)

    #expect(starts.values == [ScriptedSession.cancelMethod])
  }

  /// A production change that fails this test: the thread registers the
  /// EditorKit Cancel, so the Edit menu shows a "Cancel" row.
  @Test func theThreadRegistersNoEditCancel() {
    let fixture = Self.makeFixture(hitsIn: [0])
    let registry = Self.registry(of: fixture)

    #expect(registry.definition(for: .cancel, at: fixture.commands.path) == nil)
  }

  /// A production change that fails this test: a host that turns off the
  /// find group still gets the Esc of the hits.
  @Test func aFindGroupThatIsOffHasNoClearSearchHits() {
    let fixture = Self.makeFixture(hitsIn: [0])
    let registry = Self.registry(of: fixture, groupsOff: [.find])

    let definition = registry.definition(
      for: AgentCommandVerb.clearSearchHits.id, at: fixture.commands.path)
    #expect(definition == nil)
  }
}
