import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

extension EnvironmentValues {
  /// The session model whose transcript the item views show (update.md §4.2).
  ///
  /// ``AgentThreadView/init(session:connection:workingDirectory:actions:)``
  /// sets its model for its rows.
  /// The composer, the tool call views and the sign-in views read the model
  /// to call its verbs and to show its state. The value is `nil` outside a
  /// thread view over a session model.
  @Entry public var sessionModel: SessionModel? = nil

  /// The connection model of the agent of the session (update.md §4.3).
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
  /// Whether the agent runs a turn: `agentState` is `.running`.
  ///
  /// The Stop control of the composer reads this value. No transcript row
  /// reads it: a row shows its entry with the same look while the agent runs
  /// and after it stops.
  var isRunning: Bool {
    guard case .running = agentState else { return false }
    return true
  }
}
