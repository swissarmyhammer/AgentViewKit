import AgentViewKit
import Foundation
import FoundationModelsExtras
import FoundationModelsRouter
import OSLog

/// The errors of ``RouterThreadActions``.
public enum RouterThreadActionsError: Error, Equatable, Sendable {
  /// The `meta` value of the authorization request has no `elicitationId`
  /// string, so the session cannot know which elicitation the connection
  /// completes.
  case missingElicitationId(AuthorizationRequestID)
}

/// The verbs of a thread that a FoundationModelsRouter session fills
/// (plan.md §3.4).
///
/// Each verb has one behavior:
///
/// - ``send(_:)`` adds the message of the user and starts a turn through
///   `RoutedSession.streamEvents(to:)`. The text fragments of the turn go to
///   the source. The session stream gives the other events of the turn.
/// - ``cancel()`` calls `RoutedSession.cancelCurrentTurn()`.
/// - ``respond(to:_:)-(ElicitationRequest,_)`` sends the answer through
///   `RoutedSession.respond(elicitationId:response:)`. For a URL request, an
///   accept tells the session that the flow in the browser is complete: the
///   verb sends the accept, then calls `RoutedSession.complete(elicitationId:)`.
/// - ``connect(_:)`` opens the authorization URL through the
///   ``AuthorizationPresenter``, then accepts and completes the elicitation
///   that `meta["elicitationId"]` names.
/// - The permission, config option, login, terminal login, terminal input,
///   and logout verbs
///   write one `debug` message and return. The Router has no permission gate,
///   no config options, and no login methods.
public final class RouterThreadActions: AgentThreadActions {
  /// The URL scheme of the callback when the request gives no scheme.
  public static let defaultCallbackScheme = "agentviewkit"

  /// The `meta` key of the elicitation id of an authorization request.
  public static let elicitationIdMetaKey = "elicitationId"

  /// The `meta` key of the callback scheme of an authorization request.
  public static let callbackSchemeMetaKey = "callbackScheme"

  /// The source that fills the thread.
  public let source: RouterThreadSource

  /// The presenter that opens each authorization URL.
  private let presenter: AuthorizationPresenter

  /// The URL scheme of the callback when the request gives no scheme.
  private let callbackScheme: String

  /// Whether the browser must not share cookies with other sessions.
  private let ephemeral: Bool

  /// The log of the actions.
  private let logger = Logger(subsystem: "AgentViewKit", category: "RouterThreadActions")

  /// Makes the actions.
  ///
  /// - Parameters:
  ///   - source: The source that fills the thread. The actions use its
  ///     session.
  ///   - presenter: The presenter that opens each authorization URL.
  ///   - callbackScheme: The URL scheme of the callback when the request
  ///     gives no scheme in `meta["callbackScheme"]`.
  ///   - ephemeral: Whether the browser must not share cookies with other
  ///     sessions.
  public init(
    source: RouterThreadSource,
    presenter: AuthorizationPresenter = AuthorizationPresenter(),
    callbackScheme: String = RouterThreadActions.defaultCallbackScheme,
    ephemeral: Bool = false
  ) {
    self.source = source
    self.presenter = presenter
    self.callbackScheme = callbackScheme
    self.ephemeral = ephemeral
  }

  /// The session of the source.
  private var session: any RouterSessionPort { source.session }

  /// The thread of the source.
  private var thread: AgentThread { source.thread }

  public func send(_ input: UserInput) async {
    if !input.attachments.isEmpty {
      logger.debug("The Router prompt takes text only. The attachments show in the thread but are not sent.")
    }
    source.addUserMessage(input)
    thread.apply(.setState(.running))
    let events = await session.promptEvents(for: input.text)
    do {
      for try await event in events {
        switch event {
        case .textDelta, .textReset:
          source.apply(event)
        default:
          continue
        }
      }
    } catch is CancellationError {
      logger.debug("The Router turn was cancelled.")
    } catch {
      source.report(error)
    }
  }

  public func cancel() async {
    await session.cancelCurrentTurn()
  }

  public func respond(to request: PermissionRequest, _ decision: PermissionDecision) async {
    logUnsupported("respond(to: PermissionRequest)")
  }

  public func respond(to request: AgentViewKit.ElicitationRequest, _ result: ElicitationResult) async {
    let response = SessionEventMapping.response(for: result)
    switch request.mode {
    case .form:
      await session.respond(elicitationId: request.id.rawValue, response: response)
    case .url(_, let elicitationId):
      await session.respond(elicitationId: elicitationId, response: response)
      if case .accept = result {
        await session.complete(elicitationId: elicitationId)
      }
    }
    thread.apply(.resolveElicitation(request.id))
  }

  public func setConfigOption(_ id: ConfigOptionID, _ value: ConfigValue) async {
    logUnsupported("setConfigOption")
  }

  public func connect(_ request: AuthorizationRequest) async throws {
    guard let elicitationId = request.meta?[Self.elicitationIdMetaKey]?.stringValue else {
      throw RouterThreadActionsError.missingElicitationId(request.id)
    }
    let scheme = request.meta?[Self.callbackSchemeMetaKey]?.stringValue ?? callbackScheme
    _ = try await presenter.present(
      url: request.authorizationURL, callbackScheme: scheme, ephemeral: ephemeral)
    await session.respond(elicitationId: elicitationId, response: .accept(content: nil))
    await session.complete(elicitationId: elicitationId)
    thread.apply(.resolveAuthorization(request.id))
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

  /// Writes that the Router has no behavior for `verb`.
  ///
  /// - Parameter verb: The name of the verb that a view called.
  private func logUnsupported(_ verb: String) {
    logger.debug("\(verb, privacy: .public) has no Router behavior. Nothing occurs.")
  }
}
