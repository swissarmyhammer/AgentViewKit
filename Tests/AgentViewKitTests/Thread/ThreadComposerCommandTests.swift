import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import EditorTestSupport
import FoundationModelsACPClient
import Observation
import SwiftUI
import Testing

@testable import AgentViewKit

/// Tests for the commands of the composer of the host in a read-only thread
/// (TestudoApp D212 and D108): with
/// `threadComposer(placeholder:onSubmit:)`, the thread scope of a read-only
/// session registers Send Message, Focus Composer and Mention…, and Send
/// Message gives the draft to the closure of the host.
///
/// The registry tests register the commands with
/// ``AgentCommandRegistration``, as the mount of a scope does. The thread
/// tests lay out a thread view in an `NSHostingView` with no window, under a
/// command system of the test, and keep the hosting view while they read
/// the registry. The draft of the default composer is in
/// ``PromptDraftStore``, so the tests set it and read it with no window. No
/// test shows a window or takes the focus.
@MainActor @Suite struct ThreadComposerCommandTests {
  /// The prompt that the user sends.
  static let prompt = "Run the tests again."

  /// The verbs of the group `compose`, which the composer of the host runs.
  nonisolated static let composeVerbs: [AgentCommandVerb] = [.send, .focusComposer, .insertMention]

  /// The verbs that change the session with no composer. A read-only thread
  /// does not register them, also with the composer of the host.
  nonisolated static let sessionChangeVerbs: [AgentCommandVerb] = [
    .cancel, .approvePending, .rejectPending, .forkFromHere,
  ]

  /// The texts that the host closure got. While ``isHeld`` is `true`, the
  /// closure does not return until the test calls ``release()``.
  @MainActor @Observable final class HostRecord {
    /// Each text that the host closure got, in order.
    var texts: [String] = []

    /// Whether the closure waits for ``release()`` before it returns.
    @ObservationIgnored let isHeld: Bool

    /// The wait of a held closure, or `nil`.
    @ObservationIgnored private var hold: CheckedContinuation<Void, Never>?

    /// Makes a record.
    ///
    /// - Parameter isHeld: Whether the closure waits for ``release()``.
    init(isHeld: Bool = false) {
      self.isHeld = isHeld
    }

    /// The host closure, which keeps each text.
    ///
    /// - Parameter text: The text of the prompt.
    func take(_ text: String) async {
      texts.append(text)
      if isHeld {
        await withCheckedContinuation { hold = $0 }
      }
    }

    /// Lets a held closure return.
    func release() {
      hold?.resume()
      hold = nil
    }
  }

  /// A thread view of a read-only session under a command system of the
  /// test, laid out with no window.
  struct ThreadFixture {
    /// The session model of the thread.
    let session: SessionModel

    /// The command system of the thread.
    let system: CommandSystem

    /// The hosting view, which keeps the thread mounted.
    let hosting: NSView

    /// The path of the thread scope.
    var path: FocusPath {
      FocusPath.root(AgentCommandTarget.segment(for: session))
    }

    /// The draft of the default composer of the thread.
    var draft: PromptDraft {
      PromptDraftStore.shared.draft(for: session)
    }

    /// Lays out a thread view of a new read-only session.
    ///
    /// - Parameters:
    ///   - host: The record of the host closure, or `nil` for no composer of
    ///     the host.
    ///   - draft: The text of the draft before the thread shows.
    init(host: HostRecord?, draft: String = ThreadComposerCommandTests.prompt) {
      let session = ReadOnlyThreadTests.readOnlyModel()
      PromptDraftStore.shared.draft(for: session).text = AttributedString(draft)
      let system = CommandSystem()
      let thread = AgentThreadView(session: session)
      let view: AnyView =
        if let host {
          AnyView(
            thread.threadComposer(
              placeholder: ThreadComposerTests.placeholder, onSubmit: host.take))
        } else {
          AnyView(thread)
        }
      let hosting = NSHostingView(
        rootView: view.commandSystem(system)
          .frame(width: ThreadSlotChainTests.width, height: ThreadSlotChainTests.height))
      StyleViewHost.layOut(hosting)
      self.session = session
      self.system = system
      self.hosting = hosting
    }

    /// Tells if the registry has `verb` at the thread path.
    ///
    /// - Parameter verb: The verb.
    /// - Returns: `true` when the registry has a definition of the verb.
    func registers(_ verb: AgentCommandVerb) -> Bool {
      system.registry.definition(for: verb.id, at: path) != nil
    }

    /// The availability of Send Message at the thread path.
    var sendAvailability: Availability {
      system.registry.availability(of: AgentCommandVerb.send.id, at: path)
    }

    /// Runs Send Message through the registry at the thread path.
    ///
    /// - Returns: `true` when the command ran.
    func performSend() -> Bool {
      system.registry.perform(AgentCommandVerb.send.id, at: path)
    }
  }

  /// Registers the commands of a scope for a read-only session, with the
  /// fork action of the host, as the mount of a scope does.
  ///
  /// - Parameter hasHostComposer: Whether the host gives its composer.
  /// - Returns: The fixture.
  static func registryFixture(hasHostComposer: Bool) -> ReadOnlyThreadTests.Fixture {
    let session = ReadOnlyThreadTests.readOnlyModel()
    let target = AgentCommandTarget()
    target.session = session
    target.forkFromHere = AgentCommandsTests.forkAction
    target.hasHostComposer = hasHostComposer
    let path = FocusPath.root(AgentCommandTarget.segment(for: session))
    var registry = CommandRegistry()
    AgentCommandRegistration.register(target, at: path, into: &registry)
    return ReadOnlyThreadTests.Fixture(target: target, registry: registry, path: path)
  }

  // MARK: - Registry

  /// A production change that fails this test: the scope of a read-only
  /// session drops a verb of the group `compose` while the host gives its
  /// composer.
  @Test(arguments: composeVerbs)
  func aReadOnlyScopeWithTheHostComposerRegistersAComposeVerb(_ verb: AgentCommandVerb) {
    let fixture = Self.registryFixture(hasHostComposer: true)

    #expect(fixture.registry.definition(for: verb.id, at: fixture.path) != nil)
  }

  /// A production change that fails this test: the composer of the host
  /// also gives Stop, Approve, Reject or Fork to a read-only session.
  @Test(arguments: sessionChangeVerbs)
  func aReadOnlyScopeWithTheHostComposerDoesNotRegisterASessionChangeVerb(
    _ verb: AgentCommandVerb
  ) throws {
    let fixture = Self.registryFixture(hasHostComposer: true)
    // A read verb is in the registry, so the registration ran at this path.
    let copyThread = fixture.registry.definition(
      for: AgentCommandVerb.copyThread.id, at: fixture.path)
    try #require(copyThread != nil)

    #expect(fixture.registry.definition(for: verb.id, at: fixture.path) == nil)
  }

  /// A production change that fails this test: a Send with a text payload
  /// in a read-only scope goes to the read-only model, which refuses it.
  @Test func aSendWithATextPayloadIsNotAvailableInAReadOnlyScope() {
    let fixture = Self.registryFixture(hasHostComposer: true)

    let availability = fixture.target.availability(
      of: .send, payload: AgentCommandPayload.text(Self.prompt))

    #expect(availability == .unavailable(reason: AgentCommandTarget.readOnlySendReason))
  }

  // MARK: - Thread

  /// A production change that fails this test: the thread scope does not
  /// give the composer of the host to its target, so a read-only thread
  /// drops a verb of the group `compose`.
  @Test(arguments: composeVerbs)
  func aReadOnlyThreadWithTheHostComposerRegistersAComposeVerb(_ verb: AgentCommandVerb) {
    let fixture = ThreadFixture(host: HostRecord())

    #expect(fixture.registers(verb))
  }

  /// A production change that fails this test: a read-only thread with no
  /// composer of the host registers a verb of the group `compose`.
  @Test(arguments: composeVerbs)
  func aReadOnlyThreadWithNoHostComposerDoesNotRegisterAComposeVerb(_ verb: AgentCommandVerb)
    throws
  {
    let fixture = ThreadFixture(host: nil)
    // A read verb is in the registry, so the scope registered at this path.
    try #require(fixture.registers(.copyThread))

    #expect(!fixture.registers(verb))
  }

  /// A production change that fails this test: Send Message does not give
  /// the draft to the closure of the host, or gives it two times.
  @Test func sendMessageGivesTheDraftToTheHostOneTime() async throws {
    let host = HostRecord()
    let fixture = ThreadFixture(host: host)
    try #require(fixture.performSend())

    // The draft clears after the closure returns, so the submit ended.
    await ObservationWait.until { fixture.draft.text.characters.isEmpty }

    #expect(host.texts == [Self.prompt])
  }

  /// A production change that fails this test: after the host took the
  /// prompt, the draft keeps the text.
  @Test func sendMessageClearsTheDraftWhenTheHostReturns() async throws {
    let host = HostRecord()
    let fixture = ThreadFixture(host: host)
    try #require(fixture.performSend())
    await ObservationWait.until { host.texts.count == 1 }

    await ObservationWait.until { fixture.draft.text.characters.isEmpty }

    #expect(fixture.draft.text.characters.isEmpty)
  }

  /// A production change that fails this test: Send Message is available
  /// while the closure of the host runs, so a second submit can start.
  @Test func sendMessageIsNotAvailableWhileTheHostRuns() async throws {
    let host = HostRecord(isHeld: true)
    defer { host.release() }
    let fixture = ThreadFixture(host: host)
    try #require(fixture.performSend())
    await ObservationWait.until { host.texts.count == 1 }

    #expect(fixture.sendAvailability == .unavailable(reason: AgentCommandTarget.reason(for: .send)))
  }

  /// A production change that fails this test: Send Message is available,
  /// or is not registered, for a blank draft in a read-only thread with the
  /// composer of the host.
  @Test func sendMessageIsNotAvailableForABlankDraft() {
    let fixture = ThreadFixture(host: HostRecord(), draft: "  \n")

    #expect(fixture.sendAvailability == .unavailable(reason: AgentCommandTarget.reason(for: .send)))
  }
}
