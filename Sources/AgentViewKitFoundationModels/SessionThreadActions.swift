import AgentViewKit
import Foundation
import FoundationModels
import OSLog

/// The verbs of a thread that a FoundationModels session fills
/// (plan.md §3.4).
///
/// Each verb has one behavior:
///
/// - ``send(_:)`` writes the error handling policy to the session, and then
///   runs ``SessionThreadSource/stream(_:)`` in a task that the actions keep
///   in ``turn``. The verb returns when the turn ends. The session reads the
///   policy when a turn starts, so the policy must be on the session before
///   the turn.
/// - ``cancel()`` cancels ``turn`` and waits for the turn to end. The SDK has
///   no cancel API. The session applies the policy that ``send(_:)`` wrote:
///   `.revertTranscript` removes the turn, and `.preserveTranscript` keeps
///   it.
/// - The permission, elicitation, config option, connect, login, terminal
///   login, terminal input, and logout verbs write one `debug` message and
///   return. The bare SDK has none of these.
public final class SessionThreadActions: AgentThreadActions {
  /// The source that fills the thread.
  public let source: SessionThreadSource

  /// The task of the last turn that ``send(_:)`` started, or `nil` before the
  /// first turn.
  public private(set) var turn: Task<Void, Never>?

  /// The policy that the session applies when a turn fails or is cancelled,
  /// or `nil` to keep the policy of the session.
  private let transcriptErrorHandlingPolicy: TranscriptErrorHandlingPolicy?

  /// The function that writes a debug message.
  private let debugLog: (String) -> Void

  /// Makes the actions.
  ///
  /// - Parameters:
  ///   - source: The source that fills the thread. The actions use its
  ///     session.
  ///   - transcriptErrorHandlingPolicy: The policy that the session applies
  ///     when a turn fails or is cancelled, or `nil` to keep the policy of
  ///     the session.
  ///   - debugLog: The function that writes a debug message. The default
  ///     writes to the unified log.
  public init(
    source: SessionThreadSource,
    transcriptErrorHandlingPolicy: TranscriptErrorHandlingPolicy? = .revertTranscript,
    debugLog: ((String) -> Void)? = nil
  ) {
    self.source = source
    self.transcriptErrorHandlingPolicy = transcriptErrorHandlingPolicy
    self.debugLog = debugLog ?? Self.unifiedLog
  }

  public func send(_ input: UserInput) async {
    if !input.attachments.isEmpty {
      debugLog("The FoundationModels prompt takes text only. The attachments are not sent.")
    }
    if let transcriptErrorHandlingPolicy {
      source.session.transcriptErrorHandlingPolicy = transcriptErrorHandlingPolicy
    }
    turn?.cancel()
    let source = source
    let regenerated = source.thread.regeneratedUserMessage(for: input)?.id
    let task = Task { await source.stream(input.text, regenerating: regenerated) }
    turn = task
    await task.value
  }

  public func cancel() async {
    guard let turn else { return }
    turn.cancel()
    await turn.value
  }

  public func respond(to request: PermissionRequest, _ decision: PermissionDecision) async {
    logUnsupported("respond(to: PermissionRequest)")
  }

  public func respond(to request: ElicitationRequest, _ result: ElicitationResult) async {
    logUnsupported("respond(to: ElicitationRequest)")
  }

  public func setConfigOption(_ id: ConfigOptionID, _ value: ConfigValue) async {
    logUnsupported("setConfigOption")
  }

  public func connect(_ request: AuthorizationRequest) async throws {
    logUnsupported("connect")
  }

  public func login(_ methodId: AuthMethodID) async throws {
    logUnsupported("login")
  }

  public func runTerminalAuth(_ method: AuthMethod.Terminal) async throws {
    logUnsupported("runTerminalAuth")
  }

  public func writeTerminalLine(_ line: String, to terminal: TerminalID) async throws {
    logUnsupported("writeTerminalLine")
  }

  public func logout() async throws {
    logUnsupported("logout")
  }

  /// Writes that the bare SDK has no behavior for `verb`.
  ///
  /// - Parameter verb: The name of the verb that a view called.
  private func logUnsupported(_ verb: String) {
    debugLog("\(verb) has no FoundationModels behavior. Nothing occurs.")
  }

  /// The log of the actions.
  private static let logger = Logger(subsystem: "AgentViewKit", category: "SessionThreadActions")

  /// Writes a debug message to the unified log.
  ///
  /// - Parameter message: The message.
  private static func unifiedLog(_ message: String) {
    logger.debug("\(message, privacy: .public)")
  }
}
