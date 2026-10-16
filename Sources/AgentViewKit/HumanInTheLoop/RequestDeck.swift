import FoundationModelsACPClient
import SwiftUI

/// The deck of the requests that wait for the answer of the user
/// (plan.md §3.2 "Pending requests", §3.3 "Request-scoped elicitations",
/// §11 decision 4).
///
/// The deck is a component of its own. The chat stream, the deck and the
/// prompt editor are three separate components, and the app arranges them.
/// Put the three in one ``SwiftUI/View/accessibilityFocusScope()``, so that
/// the focus can go back to the prompt editor. Give the session model and the
/// connection model to the prompt editor in the environment
/// (``SwiftUI/EnvironmentValues/sessionModel``,
/// ``SwiftUI/EnvironmentValues/connectionModel``):
///
/// ```swift
/// VStack {
///   AgentThreadView(session: session, connection: connection)
///   RequestDeck(session: session)
///   PromptInputView(text: $draft) {}
/// }
/// .accessibilityFocusScope()
/// .environment(\.sessionModel, session)
/// .environment(\.connectionModel, connection)
/// ```
///
/// ``AgentThreadView`` shows no card. Thus, without a session deck, the
/// requests of the session do not show.
///
/// - ``init(session:)`` shows the permission requests and the elicitations
///   of a `SessionModel`, from `pendingRequests`, oldest first.
/// - ``init(connection:)`` shows the request-scoped elicitations of a
///   `ConnectionModel`, for example the elicitations of `auth/login`. Put
///   this deck at the window level, for example at the top of the detail
///   column. The model removes each elicitation when its client request
///   ends.
///
/// The deck keeps no copy of the requests. It reads `pendingRequests` of the
/// model in each body, and the model removes a request when it resolves. A
/// permission card is a ``PermissionView``. An elicitation card is an
/// ``ElicitationView`` for a form mode request, or an
/// ``ElicitationURLConsentView`` for a URL mode request. The deck shows no
/// card for an elicitation mode that the kit does not know. Each card sends
/// the answer of the user to the reply methods of the model that holds the
/// request. To change the cards, use the field overrides of the elicitation
/// views and the ``SwiftUI/EnvironmentValues/agentTheme``.
///
/// The deck is a container with the identifier ``identifier``. Each card is
/// in a container with the identifier `pending-card-<id>`
/// (``identifier(for:)``), where `<id>` is the local id of the pending
/// request. The `ForEach` gives each card the identity of its request, so
/// that each card keeps its own state. The deck is not in the lazy list of
/// the conversation, so a card is always mounted.
///
/// The deck applies ``SwiftUI/View/accessibilityFocusScope()``, which does
/// nothing when the environment already has a mover. The deck tells the
/// ``SwiftUI/EnvironmentValues/accessibilityFocusMover`` and the
/// ``SwiftUI/EnvironmentValues/focusReporter`` where the focus goes. Each
/// card container can take the VoiceOver focus
/// (``SwiftUI/View/accessibilityFocusTarget(_:)``).
public struct RequestDeck: View, PrefixedAccessibilityIdentifier {
  /// The accessibility identifier of the deck container.
  public static let identifier = "request-deck"

  /// The start of the accessibility identifier of each card container.
  public static let identifierPrefix = "pending-card-"

  /// The model whose pending requests the deck shows.
  let source: DeckSource

  /// Makes the deck of the pending requests of a session.
  ///
  /// - Parameter session: The session model.
  public init(session: SessionModel) {
    source = .session(session)
  }

  /// Makes the deck of the request-scoped elicitations of a connection.
  ///
  /// - Parameter connection: The connection model.
  public init(connection: ConnectionModel) {
    source = .connection(connection)
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
  static func focusTarget(old: [String], new: [String]) -> String? {
    let oldIDs = Set(old)
    if let added = new.last(where: { !oldIDs.contains($0) }) {
      return identifier(for: added)
    }
    let newIDs = Set(new)
    guard old.contains(where: { !newIDs.contains($0) }) else { return nil }
    guard let last = new.last else { return StockPromptEditor.identifier }
    return identifier(for: last)
  }

  public var body: some View {
    // The cards read the mover of the scope, so the scope is outside them.
    DeckCards(source: source)
      .accessibilityFocusScope()
  }
}

/// The model whose pending requests a ``RequestDeck`` shows.
///
/// The two cases give one code path to the deck: the requests, the session
/// model that answers each permission request, and the model that answers
/// each elicitation.
enum DeckSource {
  /// The permission requests and the elicitations of a session.
  case session(SessionModel)

  /// The request-scoped elicitations of a connection.
  case connection(ConnectionModel)

  /// The pending requests of the model that have a card, oldest first.
  var requests: [PendingRequest] {
    let pending =
      switch self {
      case .session(let session): session.pendingRequests
      case .connection(let connection): connection.pendingRequests
      }
    return pending.filter(Self.hasCard(for:))
  }

  /// The session model that answers the permission requests, or `nil` for a
  /// connection, which has no permission request.
  var session: SessionModel? {
    switch self {
    case .session(let session): session
    case .connection: nil
    }
  }

  /// The model that holds the elicitations, and takes the answer to each
  /// elicitation card.
  var elicitationOwner: any PendingElicitationOwner {
    switch self {
    case .session(let session): session
    case .connection(let connection): connection
    }
  }

  /// Tells if the deck has a card for a pending request.
  ///
  /// - Parameter request: The pending request.
  /// - Returns: `true` for each permission request, and for an elicitation
  ///   with a mode that the kit knows.
  private static func hasCard(for request: PendingRequest) -> Bool {
    switch request {
    case .permission: true
    case .elicitation(let elicitation): ElicitationCard.hasCard(for: elicitation)
    }
  }
}

/// The cards of a ``RequestDeck``, in the focus scope of the deck.
private struct DeckCards: View {
  /// The model to read.
  let source: DeckSource

  @Environment(\.agentTheme) private var theme

  /// The action that moves the VoiceOver focus and tells the host.
  private let moveFocus = AccessibilityFocusMove()

  var body: some View {
    let requests = source.requests
    VStack(alignment: .leading, spacing: theme.spacing.m) {
      ForEach(requests) { request in
        card(for: request)
      }
    }
    .padding(requests.isEmpty ? 0 : theme.spacing.m)
    .contentContainer(identifier: RequestDeck.identifier)
    .onChange(of: requests.map(\.id.uuidString)) { old, new in
      if let target = RequestDeck.focusTarget(old: old, new: new) {
        moveFocus(to: target)
      }
    }
  }

  /// The card of one request, in its container.
  ///
  /// - Parameter request: The pending request.
  /// - Returns: The card in a container with the identifier
  ///   `pending-card-<id>`. The container can take the VoiceOver focus.
  private func card(for request: PendingRequest) -> some View {
    let identifier = RequestDeck.identifier(for: request.id.uuidString)
    return cardContent(for: request)
      .contentContainer(identifier: identifier)
      .accessibilityFocusTarget(identifier)
  }

  /// The card view of one request.
  ///
  /// - Parameter request: The pending request.
  /// - Returns: A ``PermissionView`` or an ``ElicitationCard``.
  @ViewBuilder
  private func cardContent(for request: PendingRequest) -> some View {
    switch request {
    case .permission(let permission):
      if let session = source.session {
        PermissionView(request: permission, session: session)
      }
    case .elicitation(let elicitation):
      ElicitationCard(request: elicitation, owner: source.elicitationOwner)
    }
  }
}
