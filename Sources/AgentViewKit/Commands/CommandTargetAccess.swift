import EditorCommands

/// The one way a kit command reaches the target that it holds weakly.
///
/// EditorKit asks a command for its availability and runs it off the main
/// actor (`nonisolated`), and it does so on the main thread, so a command
/// reads its target, a main actor object, through
/// `MainActor.assumeIsolated`. A command whose target is gone is unavailable
/// with the reason of its kind, and its run declines. The thread command
/// (``AgentCommand``) and the attachment command (``AgentAttachmentCommand``)
/// both read their target here.
nonisolated enum CommandTargetAccess {
  /// The availability of a command at its live target.
  ///
  /// - Parameters:
  ///   - target: The target of the command, or `nil` when it is gone.
  ///   - unavailable: The availability of the command with no target.
  ///   - check: The availability at the live target.
  /// - Returns: `unavailable` with no target, otherwise the answer of
  ///   `check`.
  static func availability<Target: AnyObject & Sendable>(
    at target: Target?, unavailable: Availability, _ check: @MainActor (Target) -> Availability
  ) -> Availability {
    MainActor.assumeIsolated {
      guard let target else { return unavailable }
      return check(target)
    }
  }

  /// Runs a command at its live target.
  ///
  /// - Parameters:
  ///   - target: The target of the command, or `nil` when it is gone.
  ///   - perform: The run at the live target.
  /// - Returns: `false` with no target, otherwise the answer of `perform`.
  static func run<Target: AnyObject & Sendable>(at target: Target?, _ perform: @MainActor (Target) -> Bool) -> Bool {
    MainActor.assumeIsolated {
      guard let target else { return false }
      return perform(target)
    }
  }
}
