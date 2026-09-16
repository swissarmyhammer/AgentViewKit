import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import Foundation
import SwiftUI
import Testing

@Suite(.serialized) @MainActor struct PromptQueueViewHostedTests {
  /// The text that the tests type.
  static let message = "Hello"

  /// The size of a window that shows the queue and the composer.
  static let size = CGSize(width: 480, height: 360)

  /// The longest time that a test waits for a change, in seconds.
  static let waitTimeout: TimeInterval = 5

  /// Makes a thread that runs a turn.
  ///
  /// - Returns: The thread.
  static func runningThread() -> AgentThread {
    let thread = AgentThread()
    thread.apply(.setState(.running))
    return thread
  }

  // MARK: - Queue view

  @Test func theViewIsHiddenWhileTheQueueIsEmpty() {
    let harness = threadViewHarness(size: Self.size, actions: NoopThreadActions()) {
      PromptQueueView(queue: PromptQueue())
    }
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: PromptQueueView.identifier) == nil)
    #expect(harness.element(identifier: PromptQueueView.countIdentifier) == nil)
  }

  @Test func theViewShowsARowForEachItemAndTheCountBadge() {
    let queue = PromptQueueTests.queue("a", "b")
    let harness = threadViewHarness(size: Self.size, actions: NoopThreadActions()) {
      PromptQueueView(queue: queue)
    }
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: PromptQueueView.countIdentifier)?.label == "2 queued")
    for item in queue.items {
      #expect(harness.element(identifier: PromptQueueView.editIdentifier(item.id))?.value == item.input.text)
      #expect(harness.element(identifier: PromptQueueView.sendNowIdentifier(item.id)) != nil)
      #expect(harness.element(identifier: PromptQueueView.removeIdentifier(item.id)) != nil)
    }
  }

  @Test func theRemoveButtonDropsTheItemAndTheBadgeFollows() throws {
    let queue = PromptQueueTests.queue("a", "b")
    let actions = NoopThreadActions()
    let harness = threadViewHarness(size: Self.size, actions: actions) {
      PromptQueueView(queue: queue)
    }
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: PromptQueueView.removeIdentifier(queue.items[0].id))

    #expect(queue.items.map(\.input.text) == ["b"])
    #expect(harness.element(identifier: PromptQueueView.countIdentifier)?.label == "1 queued")
    #expect(actions.calls.isEmpty)
  }

  @Test func removingTheLastItemHidesTheView() throws {
    let queue = PromptQueueTests.queue("a")
    let harness = threadViewHarness(size: Self.size, actions: NoopThreadActions()) {
      PromptQueueView(queue: queue)
    }
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: PromptQueueView.removeIdentifier(queue.items[0].id))

    #expect(queue.isEmpty)
    #expect(harness.element(identifier: PromptQueueView.identifier) == nil)
  }

  @Test func theSendNowButtonSendsTheItemAtOnceAndRemovesIt() async throws {
    let queue = PromptQueueTests.queue("a", "b")
    let actions = NoopThreadActions()
    let harness = threadViewHarness(size: Self.size, actions: actions, thread: Self.runningThread()) {
      PromptQueueView(queue: queue)
    }
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: PromptQueueView.sendNowIdentifier(queue.items[1].id))
    await harness.pump(until: Self.waitTimeout) { !actions.calls.isEmpty }

    #expect(actions.calls == [.send(UserInput(text: "b"))])
    #expect(queue.items.map(\.input.text) == ["a"])
  }

  @Test func anInlineEditChangesTheTextOfTheItem() throws {
    let queue = PromptQueueTests.queue("a")
    let harness = threadViewHarness(size: Self.size, actions: NoopThreadActions()) {
      PromptQueueView(queue: queue)
    }
    defer { harness.close() }
    harness.pump()

    try #require(harness.focusFirstEditableTextView())
    harness.type("!")

    #expect(queue.count == 1)
    #expect(queue.items[0].input.text.hasSuffix("!"))
  }

  // MARK: - Composer keys

  @Test func returnWhileRunningAddsToTheQueueAndShowsTheBadge() throws {
    let queue = PromptQueue()
    let actions = NoopThreadActions()
    let model = PromptInputHostedTestModel()
    let harness = threadViewHarness(size: Self.size, actions: actions, thread: Self.runningThread()) {
      VStack {
        PromptInputHost(model: model)
        PromptQueueView(queue: queue)
      }
      .promptQueue(queue)
    }
    defer { harness.close() }
    harness.pump()

    try #require(harness.focusFirstEditableTextView())
    harness.type(Self.message)
    try harness.sendKey(.return)

    #expect(actions.calls.isEmpty)
    #expect(queue.items.map(\.input) == [UserInput(text: Self.message)])
    #expect(model.plainText.isEmpty)
    #expect(model.submitCount == 1)
    #expect(harness.element(identifier: PromptQueueView.countIdentifier)?.label == "1 queued")
  }

  @Test func whenTheTurnEndsTheFirstQueuedItemIsSentAndRemoved() async {
    let queue = PromptQueueTests.queue("a", "b")
    let thread = Self.runningThread()
    let actions = NoopThreadActions()
    let model = PromptInputHostedTestModel()
    let harness = threadViewHarness(size: Self.size, actions: actions, thread: thread) {
      PromptInputHost(model: model)
        .promptQueue(queue)
    }
    defer { harness.close() }
    harness.pump()

    thread.apply(.setState(.idle(.endTurn)))
    await harness.pump(until: Self.waitTimeout) { !actions.calls.isEmpty }

    #expect(actions.calls == [.send(UserInput(text: "a"))])
    #expect(queue.items.map(\.input.text) == ["b"])
  }

  @Test func aCancelledTurnKeepsTheQueue() {
    let queue = PromptQueueTests.queue("a")
    let thread = Self.runningThread()
    let actions = NoopThreadActions()
    let model = PromptInputHostedTestModel()
    let harness = threadViewHarness(size: Self.size, actions: actions, thread: thread) {
      PromptInputHost(model: model)
        .promptQueue(queue)
    }
    defer { harness.close() }
    harness.pump()

    thread.apply(.setState(.idle(.cancelled)))
    harness.pump()

    #expect(actions.calls.isEmpty)
    #expect(queue.count == 1)
  }

  @Test func commandReturnWhileRunningSendsAtOnce() async throws {
    let queue = PromptQueueTests.queue("a")
    let actions = NoopThreadActions()
    let model = PromptInputHostedTestModel()
    let harness = threadViewHarness(size: Self.size, actions: actions, thread: Self.runningThread()) {
      PromptInputHost(model: model)
        .promptQueue(queue)
    }
    defer { harness.close() }
    harness.pump()

    try #require(harness.focusFirstEditableTextView())
    harness.type(Self.message)
    try harness.sendKey(.return, modifiers: .command)
    await harness.pump(until: Self.waitTimeout) { !actions.calls.isEmpty }

    #expect(actions.calls == [.send(UserInput(text: Self.message))])
    #expect(queue.items.map(\.input.text) == ["a"])
    #expect(model.plainText.isEmpty)
  }

  @Test func escapeWhileRunningCallsCancelAndKeepsTheQueue() async throws {
    let queue = PromptQueueTests.queue("a", "b")
    let actions = NoopThreadActions()
    let model = PromptInputHostedTestModel()
    let harness = threadViewHarness(size: Self.size, actions: actions, thread: Self.runningThread()) {
      PromptInputHost(model: model)
        .promptQueue(queue)
    }
    defer { harness.close() }
    harness.pump()

    try #require(harness.focusFirstEditableTextView())
    harness.type(Self.message)
    try harness.sendKey(.escape)
    await harness.pump(until: Self.waitTimeout) { !actions.calls.isEmpty }

    #expect(actions.calls == [.cancel])
    #expect(queue.count == 2)
    #expect(model.plainText == Self.message)
  }

  @Test func escapeWhileIdleCallsNothing() throws {
    let actions = NoopThreadActions()
    let model = PromptInputHostedTestModel()
    let harness = threadViewHarness(size: Self.size, actions: actions) {
      PromptInputHost(model: model)
        .promptQueue(PromptQueue())
    }
    defer { harness.close() }
    harness.pump()

    try #require(harness.focusFirstEditableTextView())
    try harness.sendKey(.escape)

    #expect(actions.calls.isEmpty)
  }

  @Test func theSubmitActionIsEnabledWhileRunningWithAQueue() {
    let model = PromptInputHostedTestModel(text: Self.message)
    let harness = threadViewHarness(
      size: Self.size, actions: NoopThreadActions(), thread: Self.runningThread()
    ) {
      PromptInputView(text: Bindable(model).text, onSubmit: {}) { context in
        StockPromptEditor(context: context)
      } accessory: {
        SubmitStateProbe()
      }
      .promptQueue(PromptQueue())
    }
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: SubmitStateProbe.identifier)?.isEnabled == true)
  }
}

/// An accessory that shows whether the submit action is enabled.
private struct SubmitStateProbe: View {
  /// The accessibility identifier of the probe button.
  static let identifier = "submit-state-probe"

  @Environment(\.promptSubmitAction) private var submit

  var body: some View {
    Button("Submit") { submit() }
      .disabled(!submit.isEnabled)
      .accessibilityIdentifier(Self.identifier)
  }
}
