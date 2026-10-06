import FoundationModelsACPClient
import SwiftUI

/// The view that shows the pending requests of a client model
/// (update.md §3 D7, §4.2 "Pending requests", §4.3 "Request-scoped
/// elicitations", §4.6 item 3).
///
/// The host keeps no copy of the requests. It reads them from the model in
/// each body, and the model removes a request when it resolves.
///
/// - ``init(session:)`` shows the requests of a `SessionModel`: one
///   ``PermissionView`` for each entry of `pendingPermissions`, then one
///   card for each entry of `pendingElicitations`.
/// - ``init(connection:)`` shows the request-scoped elicitations of a
///   `ConnectionModel`, for example the elicitations of `auth/login`. The
///   model removes each one when its client request ends.
///
/// An elicitation card is an ``ElicitationView`` for a form mode request, or
/// an ``ElicitationURLConsentView`` for a URL mode request. Each card sends
/// the answer of the user to the reply methods of the model that holds the
/// request.
///
/// Each card is in a container with the identifier `pending-card-<id>`,
/// where `<id>` is the local id of the pending request. The `ForEach` of
/// each list gives each card the identity of its request, so that each card
/// keeps its own state.
///
/// The host tells the ``SwiftUI/EnvironmentValues/accessibilityFocusMover``
/// and the ``SwiftUI/EnvironmentValues/focusReporter`` where the focus goes
/// (``focusTarget(old:new:)``). Each card container can take the VoiceOver
/// focus (``SwiftUI/View/accessibilityFocusTarget(_:)``). The host does not
/// show the cards in the lazy list of the conversation, so a card is always
/// mounted.
public struct PendingRequestsHost: View {
  /// The start of the accessibility identifier of each card container.
  public static let identifierPrefix = "pending-card-"

  /// The model whose pending requests the host shows.
  enum Source {
    /// The permission requests and the elicitations of a session.
    case session(SessionModel)

    /// The request-scoped elicitations of a connection.
    case connection(ConnectionModel)
  }

  /// The model to read.
  let source: Source

  @Environment(\.agentTheme) private var theme

  /// The action that moves the VoiceOver focus and tells the host.
  private let moveFocus = AccessibilityFocusMove()

  /// Makes the host of the pending requests of a session.
  ///
  /// - Parameter session: The session model.
  public init(session: SessionModel) {
    source = .session(session)
  }

  /// Makes the host of the request-scoped elicitations of a connection.
  ///
  /// - Parameter connection: The connection model.
  public init(connection: ConnectionModel) {
    source = .connection(connection)
  }

  /// The accessibility identifier of the container of a card.
  ///
  /// - Parameter requestID: The raw identifier of the request.
  /// - Returns: `pending-card-<requestID>`.
  public static func identifier(for requestID: String) -> String {
    AccessibilityIdentifier.make(prefix: identifierPrefix, value: requestID)
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
    let permissions = permissionRequests
    let elicitations = elicitationRequests
    let ids = permissions.map(\.id.rawValue) + elicitations.map(\.id.rawValue)
    VStack(alignment: .leading, spacing: theme.spacing.m) {
      ForEach(permissions) { request in
        card(for: request.id.rawValue) { PermissionView(request: request) }
      }
      ForEach(elicitations) { request in
        card(for: request.id.rawValue) { ElicitationCard(request: request) }
      }
    }
    .padding(ids.isEmpty ? 0 : theme.spacing.m)
    .environment(\.permissionReplies, permissionReplies)
    .environment(\.elicitationReplies, elicitationReplies)
    .onChange(of: ids) { old, new in
      if let target = Self.focusTarget(old: old, new: new) {
        moveFocus(to: target)
      }
    }
  }

  /// The kit requests of the pending permission requests, in arrival order.
  /// A connection has no permission request.
  private var permissionRequests: [PermissionRequest] {
    switch source {
    case .session(let session): session.pendingPermissions.map(SessionUpdateMapping.permissionRequest)
    case .connection: []
    }
  }

  /// The kit requests of the pending elicitations, in arrival order.
  private var elicitationRequests: [ElicitationRequest] {
    let pending =
      switch source {
      case .session(let session): session.pendingElicitations
      case .connection(let connection): connection.pendingElicitations
      }
    return pending.compactMap(ElicitationCard.request(for:))
  }

  /// The model that takes the answer to each permission card.
  private var permissionReplies: (any PermissionReplying)? {
    switch source {
    case .session(let session): session
    case .connection: nil
    }
  }

  /// The model that takes the answer to each elicitation card.
  private var elicitationReplies: any ElicitationReplying {
    switch source {
    case .session(let session): session
    case .connection(let connection): connection
    }
  }

  /// The container of the card of one request.
  ///
  /// - Parameters:
  ///   - requestID: The raw identifier of the request.
  ///   - content: The card.
  /// - Returns: The card in a container with the identifier
  ///   `pending-card-<id>`. The container can take the VoiceOver focus.
  private func card(
    for requestID: String, @ViewBuilder content: () -> some View
  ) -> some View {
    let identifier = Self.identifier(for: requestID)
    return content()
      .contentContainer(identifier: identifier)
      .accessibilityFocusTarget(identifier)
  }
}
