import OSLog
import SwiftUI

/// The verbs that act on a thread (plan.md §3.4).
///
/// The views call these verbs. A source implements them. This protocol is
/// the only surface of the kit that is not the model. Read the actions of a
/// view from ``SwiftUI/EnvironmentValues/threadActions``, and set them with
/// ``SwiftUI/View/threadActions(_:)``.
@MainActor
public protocol AgentThreadActions: AnyObject {
  /// Sends the input of the user to the agent.
  ///
  /// - Parameter input: The text and the attachments.
  func send(_ input: UserInput) async

  /// Stops the current turn.
  ///
  /// Each source implements this verb: `Task` cancellation for
  /// FoundationModels, and `session/cancel` for ACP.
  func cancel() async

  /// Answers a permission request.
  ///
  /// - Parameters:
  ///   - request: The request to answer.
  ///   - decision: The answer of the user.
  func respond(to request: PermissionRequest, _ decision: PermissionDecision) async

  /// Answers an elicitation request.
  ///
  /// - Parameters:
  ///   - request: The request to answer.
  ///   - result: The answer of the user.
  func respond(to request: ElicitationRequest, _ result: ElicitationResult) async

  /// Sets the value of a session option.
  ///
  /// - Parameters:
  ///   - id: The identifier of the option.
  ///   - value: The new value.
  func setConfigOption(_ id: ConfigOptionID, _ value: ConfigValue) async

  /// Starts the OAuth handoff for an MCP server (plan.md §12).
  ///
  /// - Parameter request: The authorization request.
  /// - Throws: The error of the handoff.
  func connect(_ request: AuthorizationRequest) async throws

  /// Sends ACP `auth/login` for an agent method (plan.md §12).
  ///
  /// - Parameter methodId: The identifier of the agent method.
  /// - Throws: The error of the login.
  func login(_ methodId: AuthMethodID) async throws

  /// Runs the agent again with the extra arguments and environment of a
  /// terminal method (plan.md §12).
  ///
  /// - Parameter method: The terminal method.
  /// - Throws: The error of the process.
  func runTerminalAuth(_ method: AuthMethod.Terminal) async throws

  /// Sends ACP `auth/logout` (plan.md §12).
  ///
  /// - Throws: The error of the logout.
  func logout() async throws
}

/// The actions that a view gets when no ancestor sets actions.
///
/// Each verb does nothing and writes one `debug` message to the log, so that
/// a developer can see that the host did not set actions. No verb throws.
public final class LoggingThreadActions: AgentThreadActions {
  /// The log of the actions.
  private let logger = Logger(subsystem: "AgentViewKit", category: "LoggingThreadActions")

  /// Makes actions that only log.
  public init() {}

  public func send(_ input: UserInput) async {
    log("send")
  }

  public func cancel() async {
    log("cancel")
  }

  public func respond(to request: PermissionRequest, _ decision: PermissionDecision) async {
    log("respond(to: PermissionRequest)")
  }

  public func respond(to request: ElicitationRequest, _ result: ElicitationResult) async {
    log("respond(to: ElicitationRequest)")
  }

  public func setConfigOption(_ id: ConfigOptionID, _ value: ConfigValue) async {
    log("setConfigOption")
  }

  public func connect(_ request: AuthorizationRequest) async throws {
    log("connect")
  }

  public func login(_ methodId: AuthMethodID) async throws {
    log("login")
  }

  public func runTerminalAuth(_ method: AuthMethod.Terminal) async throws {
    log("runTerminalAuth")
  }

  public func logout() async throws {
    log("logout")
  }

  /// Writes that the host did not set actions for `verb`.
  ///
  /// - Parameter verb: The name of the verb that a view called.
  private func log(_ verb: String) {
    logger.debug(
      "\(verb, privacy: .public) was called, but no threadActions are set. Nothing occurs.")
  }
}

extension EnvironmentValues {
  /// The actions that the views of this subtree call (plan.md §3.4).
  ///
  /// The default is a ``LoggingThreadActions``, which does nothing.
  @Entry public var threadActions: any AgentThreadActions = LoggingThreadActions()
}

extension View {
  /// Sets the actions that the views of this subtree call.
  ///
  /// - Parameter actions: The actions of the thread source.
  /// - Returns: A view that gives the actions to its subtree.
  public func threadActions(_ actions: any AgentThreadActions) -> some View {
    environment(\.threadActions, actions)
  }
}
