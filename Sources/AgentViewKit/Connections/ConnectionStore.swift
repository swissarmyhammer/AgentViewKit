import Foundation
import Observation
import SwiftUI
import os

/// The identifier of a ``Connection`` in a ``ConnectionStore``.
///
/// For an MCP server, this is the name of the server in the host
/// configuration.
public typealias ConnectionID = Identifier<Connection>

/// The identifier of a ``ToolToggle`` in its ``Connection``.
///
/// For an MCP tool, this is the tool name. Two connections can have a tool
/// with the same identifier.
public typealias ToolToggleID = Identifier<ToolToggle>

/// The connection state of a server (plan.md §12).
///
/// The states follow the MCP 2025-11-25 authorization flow. The host moves a
/// connection from one state to a different state with
/// ``ConnectionStore/transition(_:to:)``. The kit makes this state and does
/// not read it from a wire string, so it has no `unknown` case.
public nonisolated enum ConnectionState: Sendable, Hashable {
  /// The server is not connected. This is the initial state, and the state
  /// after the Disconnect action.
  case disconnected

  /// The server is connected.
  case connected

  /// The server replied `401` with `WWW-Authenticate`, or `403` with
  /// `insufficient_scope`. The user must authorize.
  case needsAuth

  /// The browser session for the authorization is open.
  case authenticating

  /// The refresh of the token failed.
  case expired

  /// A failure that is not a `401`, with the text to show.
  case error(String)

  /// The kind of a ``ConnectionState``: the state with no error text.
  ///
  /// The raw value is the name of the state in accessibility identifiers.
  public enum Kind: String, Sendable, Hashable, CaseIterable {
    /// The kind of ``ConnectionState/disconnected``.
    case disconnected
    /// The kind of ``ConnectionState/connected``.
    case connected
    /// The kind of ``ConnectionState/needsAuth``.
    case needsAuth = "needs-auth"
    /// The kind of ``ConnectionState/authenticating``.
    case authenticating
    /// The kind of ``ConnectionState/expired``.
    case expired
    /// The kind of ``ConnectionState/error(_:)``.
    case error

    /// The name of the state that the user sees and that VoiceOver reads.
    public var label: String {
      switch self {
      case .disconnected: "Disconnected"
      case .connected: "Connected"
      case .needsAuth: "Needs authorization"
      case .authenticating: "Authorizing"
      case .expired: "Expired"
      case .error: "Error"
      }
    }
  }

  /// The kind of the state.
  public var kind: Kind {
    switch self {
    case .disconnected: .disconnected
    case .connected: .connected
    case .needsAuth: .needsAuth
    case .authenticating: .authenticating
    case .expired: .expired
    case .error: .error
    }
  }

  /// The error text of an ``error(_:)`` state, or `nil` for each other state.
  public var errorMessage: String? {
    if case .error(let message) = self { message } else { nil }
  }

  /// The edges of the state machine (plan.md §12), keyed by the start kind.
  ///
  /// - A connect goes from `disconnected` to `connected`, `needsAuth`, or
  ///   `error`.
  /// - A `401` or an `insufficient_scope` reply goes from `connected` to
  ///   `needsAuth`. A refresh failure goes to `expired`.
  /// - The Connect action on `needsAuth` or `expired` opens the browser
  ///   session: the state goes to `authenticating`.
  /// - A successful retry goes from `authenticating` or `error` to
  ///   `connected`. A cancelled browser session goes back to `needsAuth`.
  /// - Each state other than `disconnected` goes to `error` and to
  ///   `disconnected`. An `error` goes to `error` with a new text.
  private static let edges: [Kind: Set<Kind>] = [
    .disconnected: [.connected, .needsAuth, .error],
    .connected: [.needsAuth, .expired, .error, .disconnected],
    .needsAuth: [.authenticating, .error, .disconnected],
    .authenticating: [.connected, .needsAuth, .error, .disconnected],
    .expired: [.authenticating, .needsAuth, .error, .disconnected],
    .error: [.connected, .needsAuth, .error, .disconnected],
  ]

  /// Whether the state machine has an edge from `from` to `to`.
  ///
  /// - Parameters:
  ///   - from: The kind of the current state.
  ///   - to: The kind of the next state.
  /// - Returns: `true` when the edge is in the table of plan.md §12.
  public static func canTransition(from: Kind, to: Kind) -> Bool {
    edges[from, default: []].contains(to)
  }
}

/// A tool of a connection that the user can turn on or off.
public nonisolated struct ToolToggle: Sendable, Hashable, Identifiable {
  /// The identifier of the tool in its connection.
  public let id: ToolToggleID
  /// The name of the tool that the user sees.
  public var name: String
  /// Whether the agent can use the tool.
  public var isEnabled: Bool

  /// Makes a tool toggle.
  ///
  /// - Parameters:
  ///   - id: The identifier of the tool in its connection.
  ///   - name: The name of the tool that the user sees.
  ///   - isEnabled: Whether the agent can use the tool.
  public init(id: ToolToggleID, name: String, isEnabled: Bool) {
    self.id = id
    self.name = name
    self.isEnabled = isEnabled
  }
}

/// A server that the kit shows in ``ConnectionsView`` (plan.md §12).
public nonisolated struct Connection: Sendable, Hashable, Identifiable {
  /// The identifier of the connection.
  public let id: ConnectionID
  /// The name of the server that the user sees.
  public var name: String
  /// The connection state.
  public var state: ConnectionState
  /// The tools of the server, in the order to show.
  public var tools: [ToolToggle]

  /// Makes a connection.
  ///
  /// - Parameters:
  ///   - id: The identifier of the connection.
  ///   - name: The name of the server that the user sees.
  ///   - state: The connection state. The default is
  ///     ``ConnectionState/disconnected``.
  ///   - tools: The tools of the server.
  public init(
    id: ConnectionID,
    name: String,
    state: ConnectionState = .disconnected,
    tools: [ToolToggle] = []
  ) {
    self.id = id
    self.name = name
    self.state = state
    self.tools = tools
  }
}

/// The connect and disconnect work that the host does (plan.md §12).
///
/// The kit presents. The runtime authorizes. The host does the discovery,
/// the token exchange, and the token storage, and reports each state change
/// with ``ConnectionStore/transition(_:to:)``.
@MainActor
public protocol ConnectionActions: AnyObject {
  /// Connects the server of `id`.
  ///
  /// - Parameter id: The identifier of the connection.
  /// - Throws: The failure. The store then moves the connection to
  ///   ``ConnectionState/error(_:)``.
  func connect(_ id: ConnectionID) async throws

  /// Disconnects the server of `id`.
  ///
  /// - Parameter id: The identifier of the connection.
  /// - Throws: The failure. The store then moves the connection to
  ///   ``ConnectionState/error(_:)``.
  func disconnect(_ id: ConnectionID) async throws
}

/// The durable list of server connections (plan.md §12).
///
/// A grant to a server is longer than a thread, so the store is not on
/// `AgentThread`. The host puts one store in the environment with
/// ``SwiftUI/View/connectionStore(_:)``, and ``ConnectionsView`` shows it.
@Observable
public final class ConnectionStore {
  /// The connections, in the order to show.
  public private(set) var connections: [Connection]

  /// The host object that connects and disconnects a server.
  ///
  /// The store keeps a weak reference, because the host usually owns the
  /// store.
  @ObservationIgnored public weak var actions: (any ConnectionActions)?

  /// The log of the store.
  @ObservationIgnored private let logger = Logger(
    subsystem: "AgentViewKit", category: "ConnectionStore")

  /// Makes a store.
  ///
  /// - Parameters:
  ///   - connections: The connections, in the order to show.
  ///   - actions: The host object that connects and disconnects a server.
  public init(connections: [Connection] = [], actions: (any ConnectionActions)? = nil) {
    self.connections = connections
    self.actions = actions
  }

  /// The connection of `id`.
  ///
  /// - Parameter id: The identifier of the connection.
  /// - Returns: The connection, or `nil` when the store has no connection
  ///   with `id`.
  public func connection(_ id: ConnectionID) -> Connection? {
    connections.first { $0.id == id }
  }

  /// Moves the connection of `id` to `state`.
  ///
  /// When the edge is not in the table of plan.md §12, or the store has no
  /// connection with `id`, the store does not change and writes a log entry.
  ///
  /// - Parameters:
  ///   - id: The identifier of the connection.
  ///   - state: The next state.
  /// - Returns: `true` when the connection moved to `state`.
  @discardableResult
  public func transition(_ id: ConnectionID, to state: ConnectionState) -> Bool {
    guard let index = connections.firstIndex(where: { $0.id == id }) else {
      logger.error("No connection \(id.rawValue, privacy: .public) for a transition.")
      return false
    }
    let current = connections[index].state.kind
    guard ConnectionState.canTransition(from: current, to: state.kind) else {
      logger.error(
        """
        Refused the transition of \(id.rawValue, privacy: .public) \
        from \(current.rawValue, privacy: .public) \
        to \(state.kind.rawValue, privacy: .public).
        """
      )
      return false
    }
    connections[index].state = state
    return true
  }

  /// Turns the tool `toolID` of the connection `connectionID` on or off.
  ///
  /// When the store has no such tool, the store does not change and writes a
  /// log entry.
  ///
  /// - Parameters:
  ///   - connectionID: The identifier of the connection.
  ///   - toolID: The identifier of the tool in the connection.
  ///   - isEnabled: Whether the agent can use the tool.
  public func setToolEnabled(_ connectionID: ConnectionID, _ toolID: ToolToggleID, _ isEnabled: Bool) {
    guard let index = connections.firstIndex(where: { $0.id == connectionID }),
      let toolIndex = connections[index].tools.firstIndex(where: { $0.id == toolID })
    else {
      logger.error(
        """
        No tool \(toolID.rawValue, privacy: .public) \
        in connection \(connectionID.rawValue, privacy: .public).
        """
      )
      return
    }
    guard connections[index].tools[toolIndex].isEnabled != isEnabled else { return }
    connections[index].tools[toolIndex].isEnabled = isEnabled
  }

  /// Asks the host to connect the server of `id`.
  ///
  /// When the host throws, the store moves the connection to
  /// ``ConnectionState/error(_:)`` with the text of the error. When the store
  /// has no ``actions``, the function does nothing.
  ///
  /// - Parameter id: The identifier of the connection.
  public func connect(_ id: ConnectionID) async {
    await perform(id) { actions in try await actions.connect(id) }
  }

  /// Asks the host to disconnect the server of `id`.
  ///
  /// When the host throws, the store moves the connection to
  /// ``ConnectionState/error(_:)`` with the text of the error. When the store
  /// has no ``actions``, the function does nothing.
  ///
  /// - Parameter id: The identifier of the connection.
  public func disconnect(_ id: ConnectionID) async {
    await perform(id) { actions in try await actions.disconnect(id) }
  }

  /// Runs `action` on the host actions, and records a failure on `id`.
  ///
  /// - Parameters:
  ///   - id: The identifier of the connection.
  ///   - action: The host call.
  private func perform(
    _ id: ConnectionID,
    _ action: @MainActor (any ConnectionActions) async throws -> Void
  ) async {
    guard let actions else {
      logger.error("No connection actions for \(id.rawValue, privacy: .public).")
      return
    }
    do {
      try await action(actions)
    } catch {
      transition(id, to: .error(error.localizedDescription))
    }
  }
}

extension EnvironmentValues {
  /// The connection store that ``ConnectionsView`` shows.
  ///
  /// The value is `nil` until a host sets a store with
  /// ``SwiftUI/View/connectionStore(_:)``.
  @Entry public var connectionStore: ConnectionStore? = nil
}

extension View {
  /// Sets the connection store for this view and each view in it.
  ///
  /// - Parameter store: The store to show.
  /// - Returns: A view that gives `store` to its subtree.
  public func connectionStore(_ store: ConnectionStore?) -> some View {
    environment(\.connectionStore, store)
  }
}
