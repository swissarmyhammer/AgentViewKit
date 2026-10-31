@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import EditorTestSupport
import FoundationModelsACPClient
import SwiftUI
import Synchronization
import Testing

/// Tests for the live subjects of the agent scopes in a window (AVK-7b,
/// AVK-7c).
///
/// The thread scope gives its `SessionModel`, a message scope gives its
/// `TranscriptEntry`, a request scope gives its `PendingPermissionRequest`,
/// and a tool call scope gives its `ToolCallEntry`. A command of another
/// module reads the subject with `@FromTarget`. The test module is that other
/// module: its commands know only the scope kinds of ``AgentScopeKind``.
///
/// A change that the test makes on the main actor is followed by one render
/// pass. A frame of the agent is followed by a wait for the model value that
/// the frame is certain to change, and then by one render pass.
@Suite(.serialized, .hostedSerially) @MainActor struct AgentScopeSubjectHostedTests {
  /// The id of the probe command that the test registers.
  nonisolated static let probeID: CommandID = "host.probeSubject"

  /// The title of the tool call that the tool call tests send. It is also the
  /// `toolCallId` of the call.
  static let toolCallTitle = "Read README.md"

  /// Registers a probe command that reads the subject of `kind` at the
  /// thread path of `model`, and returns the log of the probe.
  ///
  /// - Parameters:
  ///   - kind: The scope kind of the subject.
  ///   - type: The type of the subject.
  ///   - model: The session model of the thread scope.
  ///   - system: The command system of the window.
  /// - Returns: The log that gets each subject that the probe reads.
  static func registerProbe<Subject: Sendable>(
    of kind: String, as type: Subject.Type, at model: SessionModel, in system: CommandSystem
  ) -> SubjectLog<Subject> {
    let log = SubjectLog<Subject>()
    let definition = CommandDefinition(id: probeID, title: .static("Probe Subject")) { _ in
      SubjectProbeCommand<Subject>(id: probeID, kind: kind, log: log)
    }
    system.registry.register(definition, at: AgentCommandScopeHostedTests.path(of: model))
    return log
  }

  /// The user message object of `entry`.
  ///
  /// - Parameter entry: A transcript entry.
  /// - Returns: The object, or `nil` when the entry is not a user message.
  static func userMessage(in entry: TranscriptEntry) -> UserMessageEntry? {
    if case .userMessage(let message) = entry { message } else { nil }
  }

  @Test func aHostCommandReadsTheMessageEntryOfAMessageScopeThroughFromTarget() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model
    let system = CommandSystem()
    let harness = AgentCommandScopeHostedTests.mount(session: session, system: system, outerScope: false)
    defer { harness.close() }
    try await AgentCommandScopeHostedTests.sendScopeMessage(to: session, rendering: harness)
    let log = Self.registerProbe(of: AgentScopeKind.message, as: TranscriptEntry.self, at: model, in: system)
    let entry = try #require(model.transcript.first)
    let path = AgentCommandScopeHostedTests.path(of: model)
      .appending(AgentScopeKind.message(rowKey: entry.rowKey))

    try #require(system.registry.perform(Self.probeID, at: path, clicked: path))

    let expected = try #require(Self.userMessage(in: entry))
    #expect(log.subjects.count == 1)
    #expect(log.subjects.first.flatMap(Self.userMessage(in:)) === expected)
  }

  /// Sends one tool call from the agent, waits until the transcript of the
  /// session holds it, and then renders `harness`.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - harness: The mount that renders the view after the wait: a
  ///     `HostedViewHarness`.
  /// - Returns: The tool call entry of the session model.
  /// - Throws: The error of the transport, or the error of `#require` when the
  ///   transcript has no tool call entry.
  static func sendScopeToolCall(
    to session: ScriptedSession, rendering harness: some RenderedMount
  ) async throws -> ToolCallEntry {
    try await session.sendToolCallUpdate(title: toolCallTitle, status: .inProgress)
    let model = session.model
    await harness.render { BackgroundRunsHostedTests.toolCall(id: toolCallTitle, in: model) != nil }
    return try #require(BackgroundRunsHostedTests.toolCall(id: toolCallTitle, in: model))
  }

  /// The tool call card of a mounted thread adds the scope
  /// `agentToolCall:<toolCallId>` below the thread scope (AVK-7c). The id is
  /// the ACP `toolCallId`, not the row key of the entry.
  @Test func aMountedToolCallCardAddsTheScopeNodeOfItsToolCallID() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model
    let system = CommandSystem()
    let harness = AgentCommandScopeHostedTests.mount(session: session, system: system, outerScope: false)
    defer { harness.close() }

    let entry = try await Self.sendScopeToolCall(to: session, rendering: harness)

    let path = AgentCommandScopeHostedTests.path(of: model).appending(AgentScopeKind.toolCall(entry.toolCallId.rawValue))
    #expect(system.registry.tree.nodes.contains { $0.path == path })
  }

  @Test func aHostCommandReadsTheToolCallEntryOfAToolCallScopeThroughFromTarget() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model
    let system = CommandSystem()
    let harness = AgentCommandScopeHostedTests.mount(session: session, system: system, outerScope: false)
    defer { harness.close() }
    let entry = try await Self.sendScopeToolCall(to: session, rendering: harness)
    let log = Self.registerProbe(of: AgentScopeKind.toolCall, as: ToolCallEntry.self, at: model, in: system)
    let path = AgentCommandScopeHostedTests.path(of: model)
      .appending(AgentScopeKind.toolCall(entry.toolCallId.rawValue))

    try #require(system.registry.perform(Self.probeID, at: path, clicked: path))

    #expect(log.subjects.count == 1)
    #expect(log.subjects.first === entry)
  }

  @Test func aHostCommandReadsTheSessionModelOfTheThreadScopeThroughFromTarget() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model
    let system = CommandSystem()
    let harness = AgentCommandScopeHostedTests.mount(session: session, system: system, outerScope: false)
    defer { harness.close() }
    harness.render()
    let log = Self.registerProbe(of: AgentScopeKind.thread, as: SessionModel.self, at: model, in: system)
    let path = AgentCommandScopeHostedTests.path(of: model)

    try #require(system.registry.perform(Self.probeID, at: path))

    #expect(log.subjects.count == 1)
    #expect(log.subjects.first === model)
  }

  @Test func aHostCommandReadsThePendingRequestOfARequestScopeThroughFromTarget() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model
    let system = CommandSystem()
    // The deck is beside the thread view, so the outer scope puts the cards
    // in the scope of the thread.
    let harness = AgentCommandScopeHostedTests.mount(session: session, system: system, outerScope: true)
    defer { harness.close() }
    let pending = try await session.sendPermissionRequest(
      id: AgentCommandScopeHostedTests.agentRequestID, rendering: harness)
    let log = Self.registerProbe(
      of: AgentScopeKind.request, as: PendingPermissionRequest.self, at: model, in: system)
    let path = AgentCommandScopeHostedTests.path(of: model).appending(AgentScopeKind.request(pending))

    try #require(system.registry.perform(Self.probeID, at: path, clicked: path))

    #expect(log.subjects.map(\.id) == [pending])
  }

  /// With no ambient command system, the scope uses its own system. The
  /// message scopes give their entries to that system too, so Copy Message
  /// in the context menu of a message copies that message.
  @Test func copyMessageInTheScopeOfAMessageWorksWithTheOwnSystemOfTheScope() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model
    try await NSPasteboard.withIsolatedAsync { pasteboard in
      let capture = CommandSystemCapture()
      let harness = HostedViewHarness(size: AgentCommandScopeHostedTests.windowSize) {
        VStack {
          AgentThreadView(session: model)
          CommandSystemCaptureView(capture: capture)
        }
        .agentCommandScope(session: model)
        .environment(\.pasteboard, pasteboard)
        .transaction { $0.disablesAnimations = true }
      }
      defer { harness.close() }
      try await AgentCommandScopeHostedTests.sendScopeMessage(to: session, rendering: harness)
      let system = try #require(capture.system)
      let entry = try #require(model.transcript.first)
      let path = AgentCommandScopeHostedTests.path(of: model)
        .appending(AgentScopeKind.message(rowKey: entry.rowKey))

      #expect(system.registry.perform(AgentCommandVerb.copyMessage.id, at: path, clicked: path))

      #expect(pasteboard.string(forType: .string) == AgentCommandScopeHostedTests.message)
    }
  }
}

/// A command of another module that reads the subject of one scope kind with
/// `@FromTarget`, and writes it to a log.
nonisolated struct SubjectProbeCommand<Subject: Sendable>: Command {
  let id: CommandID

  /// The log that gets the subject of each run.
  let log: SubjectLog<Subject>

  /// The subject of the scope kind, as the scope gives it.
  @FromTarget var subject: Subject?

  /// Makes a probe for the subject of `kind`.
  ///
  /// - Parameters:
  ///   - id: The command id.
  ///   - kind: The scope kind of the subject.
  ///   - log: The log that gets the subject of each run.
  init(id: CommandID, kind: String, log: SubjectLog<Subject>) {
    self.id = id
    self.log = log
    _subject = FromTarget(kind: kind)
  }

  var title: String { id.rawValue }

  func availability(in context: CommandContext) -> Availability {
    subject == nil ? .unavailable(reason: "No subject.") : .available
  }

  func run(in context: CommandContext) -> Bool {
    guard let subject else { return false }
    log.record(subject)
    return true
  }
}

/// The subjects that a ``SubjectProbeCommand`` reads, in order.
///
/// A command runs off the main actor in EditorKit, so the list uses a lock.
nonisolated final class SubjectLog<Subject: Sendable>: Sendable {
  /// The subjects, in order, behind a lock.
  private let storage = Mutex<[Subject]>([])

  /// The subjects, in order.
  var subjects: [Subject] { storage.withLock { $0 } }

  /// Records one subject.
  ///
  /// - Parameter subject: The subject that a run read.
  func record(_ subject: Subject) {
    storage.withLock { $0.append(subject) }
  }
}

/// The command system that a ``CommandSystemCaptureView`` reads from the
/// environment of an agent command scope.
@MainActor final class CommandSystemCapture {
  /// The system of the nearest agent command scope, or `nil` before the
  /// first render.
  var system: CommandSystem?
}

/// A zero-size view that records the command system of the nearest agent
/// command scope on each render.
struct CommandSystemCaptureView: NSViewRepresentable {
  /// The capture that gets the system.
  let capture: CommandSystemCapture

  func makeNSView(context: Context) -> NSView {
    capture.system = context.environment.agentCommandSystem
    return NSView(frame: .zero)
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    capture.system = context.environment.agentCommandSystem
  }
}
