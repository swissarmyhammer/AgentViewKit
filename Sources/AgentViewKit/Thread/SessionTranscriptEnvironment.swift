import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

extension EnvironmentValues {
  /// The session model whose transcript the item views show (plan.md §3.2).
  ///
  /// ``AgentThreadView/init(session:connection:sessionTitle:headerContextMenuPath:)``
  /// sets its model for its rows.
  /// The composer, the tool call views and the sign-in views read the model
  /// to call its verbs and to show its state. The value is `nil` outside a
  /// thread view over a session model.
  @Entry public var sessionModel: SessionModel? = nil

  /// The connection model of the agent of the session (plan.md §3.3).
  ///
  /// The composer reads the prompt capabilities of the agent from
  /// `ConnectionModel.agentCapabilities` at the time of use, and keeps no copy
  /// of them. Its attachment chips and the blocks of each prompt follow those
  /// capabilities. When the value is `nil`, the composer reads no capability:
  /// it does not send an image, and it sends each other file as a resource
  /// link. Give the model with `.environment(\.connectionModel, model)`.
  @Entry public var connectionModel: ConnectionModel? = nil
}

extension SessionModel {
  /// Whether the agent runs: `agentState` is `.running`.
  ///
  /// The agent runs for a prompt, for background work, or for a compaction,
  /// also when no prompt is open. ``ActivityIndicator`` and the suggestions
  /// of ``DefaultPromptAccessory`` read this value. The Stop control reads
  /// the cancel rule of the kit (``AgentCommandTarget/canCancel(_:)``). No
  /// transcript row reads this value: a row shows its entry with the same
  /// look while the agent runs and after it stops.
  var isRunning: Bool {
    guard case .running = agentState else { return false }
    return true
  }
}
