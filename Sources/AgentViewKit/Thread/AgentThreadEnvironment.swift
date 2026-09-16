import SwiftUI

extension EnvironmentValues {
  /// The thread that the item views show.
  ///
  /// ``AgentThreadView`` sets its thread for its rows. A row view reads the
  /// thread to find the in-progress state (plan.md §3.5) and the streaming
  /// text of its record. The value is `nil` outside an ``AgentThreadView``.
  @Entry public var agentThread: AgentThread? = nil
}
