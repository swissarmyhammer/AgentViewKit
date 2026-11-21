import AgentViewKitTestSupport
import EditorCommands
import EditorCommandsUI
import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// Tests for Find Next Hit and the Esc of the search hits in a mounted
/// thread view (TestudoApp D207 (f)).
///
/// The host gives the hits through a binding of an observable box, so that
/// a test reads the binding after the Esc. A frame of the agent is followed
/// by a wait for the model value that the frame is certain to change, and
/// then by one render pass. No test takes the focus or shows the window.
@Suite(.serialized, .hostedSerially) @MainActor struct TranscriptSearchStepHostedTests {
  /// The hits of the host.
  @Observable final class HostHits {
    /// The hits, or `nil` for no hits.
    var hits: TranscriptSearchHits?

    /// The binding of the hits that the thread view gets.
    var binding: Binding<TranscriptSearchHits?> {
      Binding(get: { self.hits }, set: { self.hits = $0 })
    }
  }

  /// Shows the thread view of a session with the hits of `host`.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - host: The hits of the host.
  ///   - system: The command system of the window.
  /// - Returns: The harness.
  static func mount(
    session: ScriptedSession, host: HostHits, system: CommandSystem
  ) -> HostedViewHarness<some View> {
    HostedViewHarness(size: AgentCommandScopeHostedTests.windowSize) {
      AgentThreadView(session: session.model)
        .transcriptSearchHits(host.binding)
        .environment(\.announcer, RecordingAnnouncer())
        .commandSystem(system)
        .transaction { $0.disablesAnimations = true }
    }
  }

  /// Sends a user message and an agent message, and gives the host one hit
  /// in each, the user message first.
  ///
  /// At the end, no view has the focus, so the find verbs can run.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - host: The hits of the host.
  ///   - harness: The harness that renders the view after each change.
  /// - Throws: The error of the transport, or an issue when the window does not
  ///   take the focus out of the composer.
  static func showHits(
    in session: ScriptedSession, host: HostHits, rendering harness: HostedViewHarness<some View>
  ) async throws {
    try await AgentCommandScopeHostedTests.send(
      [
        .init(
          kind: "user_message_chunk", messageID: "hit-first", text: "Why does the parser fail?"),
        .init(kind: "agent_message_chunk", messageID: "hit-second", text: "The parser fails."),
      ], to: session)
    let model = session.model
    await harness.renderAfter { model.transcript.count == 2 }
    let ids = model.transcript.compactMap { entry -> SessionEntry.ID? in
      if case .wire(let id) = entry.id { id } else { nil }
    }
    host.hits = TranscriptSearchHits(
      ids.map { TranscriptSearchHit(entryID: $0, terms: ["parser"]) })
    harness.render()
    // The harness gives the focus to its first key view, the text view of the
    // composer. The find verbs are off while a text input has the focus
    // (D133), so the test takes the focus out of the composer.
    try #require(harness.window.makeFirstResponder(nil))
    harness.render()
  }

  @Test func findNextHitRunsInAMountedThreadWithHits() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let host = HostHits()
    let harness = Self.mount(session: session, host: host, system: system)
    defer { harness.close() }
    try await Self.showHits(in: session, host: host, rendering: harness)

    let path = AgentCommandScopeHostedTests.path(of: session.model)
    #expect(system.registry.perform(AgentCommandVerb.findNextHit.id, at: path))
  }

  @Test func escapeInAMountedThreadWithHitsRemovesTheHitsOfTheHost() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let host = HostHits()
    let harness = Self.mount(session: session, host: host, system: system)
    defer { harness.close() }
    try await Self.showHits(in: session, host: host, rendering: harness)

    let path = AgentCommandScopeHostedTests.path(of: session.model)
    try #require(system.registry.performKey(KeyChord.escape.asSequence, mode: .cua, at: path))

    #expect(host.hits == nil)
  }
}
