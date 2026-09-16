import AgentViewKit

/// An ``AgentThreadActions`` that records each call and does nothing else.
///
/// Each verb first appends one ``Call`` to ``calls``, then runs the closure of
/// the verb, if it has one. A closure lets a test delay a verb, or make a
/// throwing verb throw.
public final class NoopThreadActions: AgentThreadActions {
  /// One recorded call, with its arguments.
  public enum Call: Equatable, Sendable {
    /// ``AgentThreadActions/send(_:)`` was called.
    case send(UserInput)
    /// ``AgentThreadActions/cancel()`` was called.
    case cancel
    /// The permission form of `respond(to:_:)` was called.
    case respondToPermission(PermissionRequest, PermissionDecision)
    /// The elicitation form of `respond(to:_:)` was called.
    case respondToElicitation(ElicitationRequest, ElicitationResult)
    /// ``AgentThreadActions/setConfigOption(_:_:)`` was called.
    case setConfigOption(ConfigOptionID, ConfigValue)
    /// ``AgentThreadActions/connect(_:)`` was called.
    case connect(AuthorizationRequest)
    /// ``AgentThreadActions/login(_:)`` was called.
    case login(AuthMethodID)
    /// ``AgentThreadActions/runTerminalAuth(_:)`` was called.
    case runTerminalAuth(AuthMethod.Terminal)
    /// ``AgentThreadActions/logout()`` was called.
    case logout
  }

  /// A closure that runs after a verb that does not throw.
  public typealias Handler<Argument> = @MainActor (Argument) async -> Void

  /// A closure that runs after a verb that can throw. The error that it
  /// throws is the error of the verb.
  public typealias ThrowingHandler<Argument> = @MainActor (Argument) async throws -> Void

  /// Each call, in call order.
  public private(set) var calls: [Call] = []

  /// Runs after ``send(_:)``.
  public var onSend: Handler<UserInput>?

  /// Runs after ``cancel()``.
  public var onCancel: Handler<Void>?

  /// Runs after the permission form of `respond(to:_:)`.
  public var onRespondToPermission: Handler<(PermissionRequest, PermissionDecision)>?

  /// Runs after the elicitation form of `respond(to:_:)`.
  public var onRespondToElicitation: Handler<(ElicitationRequest, ElicitationResult)>?

  /// Runs after ``setConfigOption(_:_:)``.
  public var onSetConfigOption: Handler<(ConfigOptionID, ConfigValue)>?

  /// Runs after ``connect(_:)``.
  public var onConnect: ThrowingHandler<AuthorizationRequest>?

  /// Runs after ``login(_:)``.
  public var onLogin: ThrowingHandler<AuthMethodID>?

  /// Runs after ``runTerminalAuth(_:)``.
  public var onRunTerminalAuth: ThrowingHandler<AuthMethod.Terminal>?

  /// Runs after ``logout()``.
  public var onLogout: ThrowingHandler<Void>?

  /// Makes actions with no calls and no closures.
  public init() {}

  /// Removes each recorded call. The closures do not change.
  public func reset() {
    calls.removeAll()
  }

  public func send(_ input: UserInput) async {
    calls.append(.send(input))
    await onSend?(input)
  }

  public func cancel() async {
    calls.append(.cancel)
    await onCancel?(())
  }

  public func respond(to request: PermissionRequest, _ decision: PermissionDecision) async {
    calls.append(.respondToPermission(request, decision))
    await onRespondToPermission?((request, decision))
  }

  public func respond(to request: ElicitationRequest, _ result: ElicitationResult) async {
    calls.append(.respondToElicitation(request, result))
    await onRespondToElicitation?((request, result))
  }

  public func setConfigOption(_ id: ConfigOptionID, _ value: ConfigValue) async {
    calls.append(.setConfigOption(id, value))
    await onSetConfigOption?((id, value))
  }

  public func connect(_ request: AuthorizationRequest) async throws {
    calls.append(.connect(request))
    try await onConnect?(request)
  }

  public func login(_ methodId: AuthMethodID) async throws {
    calls.append(.login(methodId))
    try await onLogin?(methodId)
  }

  public func runTerminalAuth(_ method: AuthMethod.Terminal) async throws {
    calls.append(.runTerminalAuth(method))
    try await onRunTerminalAuth?(method)
  }

  public func logout() async throws {
    calls.append(.logout)
    try await onLogout?(())
  }
}
