import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import SwiftUI
import Testing

/// Hosted tests of ``CheckpointView`` through a ``RecordingCheckpointActions``.
@Suite(.serialized, .hostedSerially) @MainActor struct CheckpointViewHostedTests {
  /// The longest time that a test waits for a restore call, in seconds.
  static let callWaitSeconds: TimeInterval = 1

  /// The number of checkpoints in the slider tests.
  static let stopCount = 5

  /// The index of the stop that the restore tests select. It is not the last
  /// stop, so a conversation restore drops later turns.
  static let earlierStop = 1

  /// The error that a failing restore throws.
  struct RestoreFailure: LocalizedError {
    var errorDescription: String? { "The snapshot is missing." }
  }

  /// Checkpoints for the turns from zero to `count - 1`.
  ///
  /// When `capabilities` is `nil`, each checkpoint can restore the code and
  /// the conversation, as the checkpoint of a host source that keeps its own
  /// file snapshots can.
  static func checkpoints(
    count: Int = stopCount,
    capabilities: CheckpointCapabilities? = nil
  ) -> [Checkpoint] {
    (0..<count).map { turn in
      Checkpoint(
        id: CheckpointID("checkpoint-\(turn)"),
        turnIndex: turn,
        createdAt: Date(timeIntervalSince1970: TimeInterval(turn)),
        label: "Turn \(turn + 1)",
        canRestoreCode: capabilities?.restoresCode ?? true,
        canRestoreConversation: capabilities?.restoresConversation ?? true)
    }
  }

  /// Mounts a checkpoint view with the actions.
  static func mount(
    _ checkpoints: [Checkpoint],
    actions: RecordingCheckpointActions
  ) -> HostedViewHarness<some View> {
    let harness = HostedViewHarness(
      CheckpointView(checkpoints: checkpoints).checkpointActions(actions))
    harness.pump()
    return harness
  }

  @Test func fiveCheckpointsMountFiveStopsInOrder() {
    let checkpoints = Self.checkpoints()
    let harness = Self.mount(checkpoints, actions: RecordingCheckpointActions())
    defer { harness.close() }

    let stops = harness.accessibilityElements().compactMap(\.identifier).filter {
      $0.hasPrefix(CheckpointView.stopIdentifierPrefix)
    }
    #expect(stops == (0..<Self.stopCount).map(CheckpointView.stopIdentifier(index:)))
    #expect(
      stops == [
        "checkpoint-stop-0", "checkpoint-stop-1", "checkpoint-stop-2",
        "checkpoint-stop-3", "checkpoint-stop-4",
      ])
    for (index, checkpoint) in checkpoints.enumerated() {
      let stop = harness.element(identifier: CheckpointView.stopIdentifier(index: index))
      #expect(stop?.label == checkpoint.label)
    }
  }

  @Test func noCheckpointsMountNoView() {
    let harness = Self.mount([], actions: RecordingCheckpointActions())
    defer { harness.close() }

    #expect(harness.element(identifier: CheckpointView.viewIdentifier) == nil)
    #expect(harness.element(identifier: CheckpointView.restoreCodeIdentifier) == nil)
  }

  @Test func aCheckpointThatCannotRestoreCodeDisablesTheCodeAction() {
    let checkpoints = Self.checkpoints(count: 1, capabilities: .router)
    let harness = Self.mount(checkpoints, actions: RecordingCheckpointActions())
    defer { harness.close() }

    let code = harness.element(identifier: CheckpointView.restoreCodeIdentifier)
    #expect(code != nil)
    #expect(code?.isEnabled == false)
    #expect(harness.element(identifier: CheckpointView.restoreBothIdentifier)?.isEnabled == false)
    #expect(
      harness.element(identifier: CheckpointView.restoreConversationIdentifier)?.isEnabled == true)
  }

  @Test func restoreBothAfterTheConfirmationRestoresBoth() async throws {
    let checkpoints = Self.checkpoints()
    let actions = RecordingCheckpointActions()
    let harness = Self.mount(checkpoints, actions: actions)
    defer { harness.close() }

    try harness.press(identifier: CheckpointView.stopIdentifier(index: Self.earlierStop))
    try harness.press(identifier: CheckpointView.restoreBothIdentifier)
    #expect(actions.calls.isEmpty, "A restore that drops turns must wait for the confirmation.")

    try harness.press(identifier: CheckpointView.confirmIdentifier)
    await harness.pump(until: Self.callWaitSeconds) { !actions.calls.isEmpty }

    #expect(
      actions.calls == [
        RecordingCheckpointActions.Call(
          checkpoint: checkpoints[Self.earlierStop], code: true, conversation: true)
      ])
    #expect(harness.element(identifier: CheckpointView.confirmIdentifier) == nil)
  }

  @Test func cancelRemovesTheConfirmationAndRestoresNothing() throws {
    let actions = RecordingCheckpointActions()
    let harness = Self.mount(Self.checkpoints(), actions: actions)
    defer { harness.close() }

    try harness.press(identifier: CheckpointView.stopIdentifier(index: Self.earlierStop))
    try harness.press(identifier: CheckpointView.restoreConversationIdentifier)
    #expect(harness.element(identifier: CheckpointView.confirmIdentifier) != nil)

    try harness.press(identifier: CheckpointView.cancelIdentifier)

    #expect(harness.element(identifier: CheckpointView.confirmIdentifier) == nil)
    #expect(actions.calls.isEmpty)
  }

  @Test func aCodeRestoreKeepsTheTurnsAndNeedsNoConfirmation() async throws {
    let checkpoints = Self.checkpoints()
    let actions = RecordingCheckpointActions()
    let harness = Self.mount(checkpoints, actions: actions)
    defer { harness.close() }

    try harness.press(identifier: CheckpointView.stopIdentifier(index: Self.earlierStop))
    try harness.press(identifier: CheckpointView.restoreCodeIdentifier)
    await harness.pump(until: Self.callWaitSeconds) { !actions.calls.isEmpty }

    #expect(harness.element(identifier: CheckpointView.confirmIdentifier) == nil)
    #expect(
      actions.calls == [
        RecordingCheckpointActions.Call(
          checkpoint: checkpoints[Self.earlierStop], code: true, conversation: false)
      ])
  }

  @Test func theLastStopRestoresTheConversationWithNoConfirmation() async throws {
    let checkpoints = Self.checkpoints()
    let actions = RecordingCheckpointActions()
    let harness = Self.mount(checkpoints, actions: actions)
    defer { harness.close() }

    try harness.press(identifier: CheckpointView.restoreConversationIdentifier)
    await harness.pump(until: Self.callWaitSeconds) { !actions.calls.isEmpty }

    #expect(harness.element(identifier: CheckpointView.confirmIdentifier) == nil)
    #expect(
      actions.calls == [
        RecordingCheckpointActions.Call(
          checkpoint: checkpoints[Self.stopCount - 1], code: false, conversation: true)
      ])
  }

  @Test func theSliderSelectsTheNextStop() async throws {
    let checkpoints = Self.checkpoints()
    let actions = RecordingCheckpointActions()
    let harness = Self.mount(checkpoints, actions: actions)
    defer { harness.close() }

    try harness.press(identifier: CheckpointView.stopIdentifier(index: 0))
    try harness.increment(identifier: CheckpointView.sliderIdentifier)
    // The AppKit slider gives its number as the value: the index of the stop.
    #expect(harness.element(identifier: CheckpointView.sliderIdentifier)?.value == "1")

    try harness.press(identifier: CheckpointView.restoreCodeIdentifier)
    await harness.pump(until: Self.callWaitSeconds) { !actions.calls.isEmpty }

    #expect(actions.calls.map(\.checkpoint) == [checkpoints[1]])
  }

  @Test func aFailedRestoreShowsTheError() async throws {
    let actions = RecordingCheckpointActions()
    actions.onRestore = { _ in throw RestoreFailure() }
    let harness = Self.mount(Self.checkpoints(), actions: actions)
    defer { harness.close() }

    try harness.press(identifier: CheckpointView.restoreCodeIdentifier)
    await harness.pump(until: Self.callWaitSeconds) {
      harness.element(identifier: CheckpointView.errorIdentifier) != nil
    }

    #expect(
      harness.element(identifier: CheckpointView.errorIdentifier)?.label
        == "The snapshot is missing.")
  }
}
