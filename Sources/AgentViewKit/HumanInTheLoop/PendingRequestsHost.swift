import SwiftUI

/// The part of ``AgentThreadView`` that shows the pending requests of a
/// thread (plan.md §3.2, §9 E, §12).
///
/// The host shows one card for each request, in this order:
///
/// 1. A ``PermissionView`` for each entry in
///    ``AgentThread/pendingPermissions``.
/// 2. An ``ElicitationView`` for each entry in
///    ``AgentThread/pendingElicitations``.
/// 3. An ``AuthorizationView`` for each entry in
///    ``AgentThread/pendingAuthorizations``.
///
/// Each card is in a container with the identifier `pending-card-<id>`. The
/// `ForEach` of each list gives each card the identity of its request, so
/// that each card keeps its own state.
///
/// The host tells the ``SwiftUI/EnvironmentValues/focusReporter`` where the
/// focus goes (``focusTarget(old:new:)``). The host does not show the cards
/// in the lazy list of the conversation, so a card is always mounted. The
/// host gives its thread to ``SwiftUI/EnvironmentValues/agentThread``, so
/// that a ``PermissionView`` finds the tool calls, the terminals, and the
/// config options of the thread.
public struct PendingRequestsHost: View {
  /// The start of the accessibility identifier of each card container.
  public static let identifierPrefix = "pending-card-"

  /// The thread whose pending requests the host shows.
  let thread: AgentThread

  @Environment(\.focusReporter) private var focusReporter
  @Environment(\.agentTheme) private var theme

  /// Makes the host of the pending requests of `thread`.
  ///
  /// - Parameter thread: The thread.
  public init(thread: AgentThread) {
    self.thread = thread
  }

  /// The accessibility identifier of the container of a card.
  ///
  /// - Parameter requestID: The raw identifier of the request.
  /// - Returns: `pending-card-<requestID>`.
  public static func identifier(for requestID: String) -> String {
    identifierPrefix + requestID
  }

  /// The raw identifiers of the pending requests of `thread`, in the order
  /// of the cards.
  ///
  /// - Parameter thread: The thread.
  /// - Returns: The identifiers of the permission, elicitation, and
  ///   authorization requests.
  static func requestIDs(of thread: AgentThread) -> [String] {
    thread.pendingPermissions.map(\.id.rawValue)
      + thread.pendingElicitations.map(\.id.rawValue)
      + thread.pendingAuthorizations.map(\.id.rawValue)
  }

  /// The accessibility identifier of the view that gets the focus after the
  /// pending requests change.
  ///
  /// - A new request moves the focus to its card. When more than one request
  ///   is new, the last new card gets the focus.
  /// - When no request is new and a request was resolved, the focus goes to
  ///   the last card that stays. When no card stays, the focus goes back to
  ///   the prompt editor (``StockPromptEditor/identifier``).
  ///
  /// - Parameters:
  ///   - old: The raw request identifiers before the change.
  ///   - new: The raw request identifiers after the change.
  /// - Returns: The identifier, or `nil` when the focus does not move.
  public static func focusTarget(old: [String], new: [String]) -> String? {
    let oldIDs = Set(old)
    if let added = new.last(where: { !oldIDs.contains($0) }) {
      return identifier(for: added)
    }
    let newIDs = Set(new)
    guard old.contains(where: { !newIDs.contains($0) }) else { return nil }
    return new.last.map(identifier(for:)) ?? StockPromptEditor.identifier
  }

  public var body: some View {
    let ids = Self.requestIDs(of: thread)
    VStack(alignment: .leading, spacing: theme.spacing.m) {
      ForEach(thread.pendingPermissions) { request in
        PermissionView(request: request)
          .contentContainer(identifier: Self.identifier(for: request.id.rawValue))
      }
      ForEach(thread.pendingElicitations) { request in
        ElicitationView(request: request)
          .contentContainer(identifier: Self.identifier(for: request.id.rawValue))
      }
      ForEach(thread.pendingAuthorizations) { request in
        AuthorizationView(request: request)
          .contentContainer(identifier: Self.identifier(for: request.id.rawValue))
      }
    }
    .padding(ids.isEmpty ? 0 : theme.spacing.m)
    .environment(\.agentThread, thread)
    .onChange(of: ids) { old, new in
      if let target = Self.focusTarget(old: old, new: new) {
        focusReporter?.focusMoved(to: target)
      }
    }
  }
}
