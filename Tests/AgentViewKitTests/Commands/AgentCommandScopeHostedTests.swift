@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import SwiftUI
import Testing

/// Tests for the agent command scope in a window: the registration of a
/// mounted thread view, and the composer and the cards that run the
/// commands.
@Suite(.serialized, .hostedSerially) @MainActor struct AgentCommandScopeHostedTests {
  /// The text that the composer tests send.
  static let message = "Hello"

  /// The size of a window that shows a thread and a composer.
  static let windowSize = CGSize(width: 480, height: 480)

  /// The longest time that a test waits for a change, in seconds.
  static let waitTimeout: TimeInterval = 5

  /// The number of verbs of the kit.
  static let verbCount = 10

  /// The path of the scope of `thread` at the root of a window.
  ///
  /// - Parameter thread: The thread.
  /// - Returns: The path.
  static func path(of thread: AgentThread) -> FocusPath {
    .root(AgentCommandTarget.segment(for: thread))
  }

  /// Makes a thread with one user message.
  ///
  /// - Returns: The thread.
  static func messageThread() -> AgentThread {
    let thread = AgentThread()
    thread.apply(.insert(.userMessage(ThreadFixtures.message(id: "scope-message")), after: nil))
    return thread
  }

  @Test func aMountedThreadViewRegistersTheTenCommands() {
    let thread = Self.messageThread()
    let system = CommandSystem()
    let actions = NoopThreadActions()
    let harness = threadViewHarness(size: Self.windowSize, actions: actions) {
      AgentThreadView(thread: thread, actions: actions)
        .commandSystem(system)
    }
    defer { harness.close() }
    harness.pump()

    let path = Self.path(of: thread)
    let ids = Set(system.registry.definitions(at: path).map(\.id))
    #expect(ids.count == Self.verbCount)
    #expect(system.registry.tree.nodes.contains { $0.path == path })
    #expect(system.registry.perform(AgentCommandVerb.scrollToBottom.id, at: path))
    #expect(system.registry.perform(AgentCommandVerb.toggleExpandAll.id, at: path))
  }

  @Test func aThreadViewInAScopeForItsThreadAddsItsPartsToThatScope() {
    let thread = Self.messageThread()
    let system = CommandSystem()
    let actions = NoopThreadActions()
    let harness = threadViewHarness(size: Self.windowSize, actions: actions) {
      AgentThreadView(thread: thread, actions: actions)
        .agentCommandScope(thread: thread)
        .commandSystem(system)
    }
    defer { harness.close() }
    harness.pump()

    let scopes = system.registry.tree.nodes.filter {
      $0.path.segments.contains { $0.kind == AgentCommandTarget.segmentKind }
    }
    #expect(scopes.map(\.path) == [Self.path(of: thread)])
    #expect(system.registry.perform(AgentCommandVerb.scrollToBottom.id, at: Self.path(of: thread)))
  }

  @Test func sendSubmitsTheComposerInTheScope() async {
    let thread = AgentThread()
    let actions = NoopThreadActions()
    let system = CommandSystem()
    let model = PromptInputHostedTestModel()
    let harness = threadViewHarness(size: Self.windowSize, actions: actions, thread: thread) {
      VStack {
        AgentThreadView(thread: thread, actions: actions)
        PromptInputHost(model: model)
      }
      .agentCommandScope(thread: thread)
      .commandSystem(system)
    }
    defer { harness.close() }
    harness.pump()
    let path = Self.path(of: thread)

    #expect(!system.registry.perform(AgentCommandVerb.send.id, at: path))
    model.text = AttributedString(Self.message)
    harness.pump()
    #expect(system.registry.perform(AgentCommandVerb.send.id, at: path))
    await harness.pump(until: Self.waitTimeout) { !actions.calls.isEmpty }

    #expect(actions.calls == [.send(UserInput(text: Self.message))])
    #expect(model.plainText.isEmpty)
    #expect(model.submitCount == 1)
  }

  @Test func theSubmitButtonOfTheComposerRunsTheSendCommand() async throws {
    let thread = AgentThread()
    let actions = NoopThreadActions()
    let model = PromptInputHostedTestModel(text: Self.message)
    let harness = threadViewHarness(size: Self.windowSize, actions: actions, thread: thread) {
      PromptInputHost(model: model)
        .agentCommandScope(thread: thread)
    }
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: DefaultPromptAccessory.submitIdentifier)
    await harness.pump(until: Self.waitTimeout) { !actions.calls.isEmpty }

    #expect(actions.calls == [.send(UserInput(text: Self.message))])
    #expect(model.submitCount == 1)
  }

  @Test func focusComposerMovesTheFocusToTheEditor() throws {
    let thread = Self.messageThread()
    let system = CommandSystem()
    let model = PromptInputHostedTestModel()
    let actions = NoopThreadActions()
    let harness = threadViewHarness(size: Self.windowSize, actions: actions) {
      VStack {
        AgentThreadView(thread: thread, actions: actions)
        PromptInputHost(model: model)
      }
      .agentCommandScope(thread: thread)
      .commandSystem(system)
    }
    defer { harness.close() }
    harness.pump()
    let editor = try #require(harness.firstEditableTextView(of: NSTextView.self))
    harness.window.makeFirstResponder(nil)
    harness.pump()

    #expect(system.registry.perform(AgentCommandVerb.focusComposer.id, at: Self.path(of: thread)))
    harness.pump()

    #expect(harness.window.firstResponder === editor)
  }

  @Test func theAllowButtonOfACardRunsTheApproveCommand() async throws {
    let thread = AgentThread()
    let request = ThreadFixtures.permissionRequest()
    thread.apply(.addPermission(request))
    let actions = NoopThreadActions()
    let harness = threadViewHarness(size: Self.windowSize, actions: actions) {
      AgentThreadView(thread: thread, actions: actions)
    }
    defer { harness.close() }
    harness.pump()
    let allow = PermissionOptionID(PermissionOption.Kind.allowAlways.wireValue)

    try harness.press(identifier: PermissionView.optionIdentifier(for: allow))
    await harness.pump(until: Self.waitTimeout) { !actions.calls.isEmpty }

    #expect(actions.calls == [.respondToPermission(request, PermissionDecision(outcome: .selected(allow)))])
  }

  @Test func theScopeRemovesItsNodeWhenTheViewGoesAway() {
    let thread = Self.messageThread()
    let system = CommandSystem()
    let model = ScopeVisibilityModel()
    let actions = NoopThreadActions()
    let harness = threadViewHarness(size: Self.windowSize, actions: actions) {
      ScopeVisibilityHost(model: model, thread: thread, actions: actions)
        .commandSystem(system)
    }
    defer { harness.close() }
    harness.pump()
    let path = Self.path(of: thread)
    #expect(system.registry.tree.nodes.contains { $0.path == path })

    model.isShown = false
    harness.pump()

    #expect(!system.registry.tree.nodes.contains { $0.path == path })
  }
}

/// Tells if ``ScopeVisibilityHost`` shows its thread view.
@Observable final class ScopeVisibilityModel {
  /// `true` while the host shows the thread view.
  var isShown = true
}

/// A host that shows a thread view while its model tells it to.
struct ScopeVisibilityHost: View {
  /// The model that tells if the thread view shows.
  let model: ScopeVisibilityModel

  /// The thread of the view.
  let thread: AgentThread

  /// The actions that the thread view gives to its subtree.
  let actions: any AgentThreadActions

  var body: some View {
    if model.isShown {
      AgentThreadView(thread: thread, actions: actions)
    } else {
      Color.clear
    }
  }
}
