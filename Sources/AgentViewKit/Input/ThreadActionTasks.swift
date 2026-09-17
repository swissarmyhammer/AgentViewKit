/// The composer calls that start a thread action from a synchronous view
/// callback, such as a button action.
extension AgentThreadActions {
  /// Starts a main-actor task that sends `input` to the agent.
  ///
  /// - Parameter input: The text and the attachments.
  func startSend(_ input: UserInput) {
    Task { @MainActor in await send(input) }
  }

  /// Starts a main-actor task that stops the current turn.
  func startCancel() {
    Task { @MainActor in await cancel() }
  }
}
