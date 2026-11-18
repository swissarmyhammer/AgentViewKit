import FoundationModelsACP
import FoundationModelsACPClient

extension Implementation {
  /// The name of the agent that the kit shows: the title of the agent, or its
  /// name when the agent sent no title.
  var displayName: String {
    title ?? name
  }
}

extension ConnectionModel {
  /// The name of the agent of the connection that the kit shows, from the
  /// `initialize` answer of the agent, or `nil` before the answer.
  var agentName: String? {
    initializeResponse?.info.displayName
  }
}
