import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

extension EnvironmentValues {
  /// The session model whose transcript the item views show (update.md §4.2).
  ///
  /// ``AgentThreadView/init(session:connection:actions:)`` sets its model for its rows.
  /// A row view reads the model to find whether its entry still streams. The
  /// value is `nil` outside a thread view over a session model.
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
  var isRunning: Bool {
    guard case .running = agentState else { return false }
    return true
  }

  /// Tells whether an entry is the last entry of the transcript while the
  /// agent runs.
  ///
  /// The agent still writes such an entry, so a message streams and a thought
  /// is in progress. The function reads only `agentState` and the last entry
  /// of `transcript`.
  ///
  /// - Parameter id: The identity of the entry.
  /// - Returns: `true` when the entry is last and `agentState` is `.running`.
  func isLastWhileRunning(_ id: TranscriptEntry.ID) -> Bool {
    isRunning && transcript.last?.id == id
  }
}
