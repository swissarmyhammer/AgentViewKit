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
/// The deck keeps no copy of the requests. It reads `pendingRequests` and
/// `frontRequest` of the model in each body, and the model removes a request
/// when it resolves. A permission card is a ``PermissionView``. An
/// elicitation card is an ``ElicitationView`` for a form mode request, or an
/// ``ElicitationURLConsentView`` for a URL mode request. The deck shows no
/// card for an elicitation mode that the kit does not know. Each card sends
/// the answer of the user to the reply methods of the model that holds the
/// request. To change the cards, use the field overrides of the elicitation
/// views and the ``SwiftUI/EnvironmentValues/agentTheme``.
///
/// The cards are in one stack, in FIFO order (deck design sections 2 and 3):
///
/// - The front card is the `frontRequest` of the model, at full size. A new
///   request goes at the back, and the front does not change. When the front
///   request resolves, the front is the oldest request that stays.
/// - Behind the front card, a maximum of three cards show their top edges,
///   in FIFO order with the front skipped. The header shows "+N" for the
///   cards that do not show (identifier ``moreIdentifier``).
/// - With more than one request, the header shows "k of N" (identifier
///   ``positionIdentifier``), where k is the position of the front request
///   in `pendingRequests`. The Previous and Next buttons (identifiers
///   ``previousIdentifier`` and ``nextIdentifier``) bring the request before
///   or after the front request to the front, with `bringToFront(_:)` of the
///   model. They do not wrap. ``AgentCommandVerb/previousRequest`` and
///   ``AgentCommandVerb/nextRequest`` do the same from a key or the command
///   palette.
/// - Only the front card takes a click or the keyboard focus. A card that
///   does not show has no opacity.
/// - An empty deck shows nothing and takes no space. The change of the front
///   card is animated only when Reduce Motion is off.
///
/// ``layout(requests:front:)`` gives the front card, the edges, "+N",
/// "k of N" and the state of Previous and Next.
///
/// The deck is a container with the identifier ``identifier``. Each card is
/// in a container with the identifier `pending-card-<id>`
/// (``identifier(for:)``), where `<id>` is the local id of the pending
/// request. All cards stay mounted in one `ForEach` that gives each card the
/// identity of its request, so that each card keeps its own state, for
/// example a partly completed form. The deck is not in the lazy list of the
/// conversation, so a card is always mounted.
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

  /// The accessibility identifier of the "k of N" text of the header.
  public static let positionIdentifier = "request-deck-position"

  /// The accessibility identifier of the Previous button of the header.
  public static let previousIdentifier = "request-deck-previous"

  /// The accessibility identifier of the Next button of the header.
  public static let nextIdentifier = "request-deck-next"

  /// The accessibility identifier of the "+N" text of the header.
  public static let moreIdentifier = "request-deck-more"

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
/// The two cases give one code path to the deck: the requests, the front
/// request and the move of a request to the front, the session model that
/// answers each permission request, and the model that answers each
/// elicitation.
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

  /// The pending request that the model shows first, or `nil` when no
  /// request waits.
  var front: PendingRequest? {
    switch self {
    case .session(let session): session.frontRequest
    case .connection(let connection): connection.frontRequest
    }
  }

  /// The layout of the deck now.
  var layout: DeckLayout {
    layout(of: requests)
  }

  /// The layout of the deck for requests that the caller read.
  ///
  /// - Parameter requests: The ``requests`` of the model.
  /// - Returns: The layout of the requests, with the ``front`` of the model.
  func layout(of requests: [PendingRequest]) -> DeckLayout {
    RequestDeck.layout(requests: requests.map(\.id), front: front?.id)
  }

  /// Brings one pending request to the front. The order of the requests does
  /// not change.
  ///
  /// - Parameter id: The id of the pending request.
  func bringToFront(_ id: PendingRequest.ID) {
    switch self {
    case .session(let session): session.bringToFront(id)
    case .connection(let connection): connection.bringToFront(id)
    }
  }

  /// Brings the request before or after the front request to the front.
  ///
  /// - Parameter neighbor: ``DeckLayout/previous`` or ``DeckLayout/next``.
  ///   When the layout has no such request, nothing changes.
  func bringToFront(neighbor: KeyPath<DeckLayout, PendingRequest.ID?>) {
    guard let id = layout[keyPath: neighbor] else { return }
    bringToFront(id)
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

/// The header and the cards of a ``RequestDeck``, in the focus scope of the
/// deck.
private struct DeckCards: View {
  /// The model to read.
  let source: DeckSource

  @Environment(\.agentTheme) private var theme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// The action that moves the VoiceOver focus and tells the host.
  private let moveFocus = AccessibilityFocusMove()

  var body: some View {
    let requests = source.requests
    let layout = source.layout(of: requests)
    VStack(alignment: .leading, spacing: theme.spacing.s) {
      if layout.showsHeader {
        DeckHeader(source: source, layout: layout)
      }
      DeckStackLayout(edgeStep: theme.spacing.s, edgeInset: theme.spacing.m) {
        ForEach(requests) { request in
          DeckCard(source: source, request: request, role: layout.role(of: request.id))
        }
      }
    }
    .padding(requests.isEmpty ? 0 : theme.spacing.m)
    .contentContainer(identifier: RequestDeck.identifier)
    .animation(reduceMotion ? nil : .default, value: layout.front)
    .onChange(of: requests.map(\.id.uuidString)) { old, new in
      if let target = RequestDeck.focusTarget(old: old, new: new) {
        moveFocus(to: target)
      }
    }
  }
}

/// The header of a ``RequestDeck`` with more than one request: the Previous
/// button, "k of N", the Next button, and "+N".
private struct DeckHeader: View {
  /// The model whose front the buttons change.
  let source: DeckSource

  /// The layout of the deck.
  let layout: DeckLayout

  @Environment(\.agentTheme) private var theme

  var body: some View {
    HStack(spacing: theme.spacing.s) {
      stepButton(
        verb: .previousRequest, symbol: SharedSymbol.previousRequest, neighbor: \.previous,
        identifier: RequestDeck.previousIdentifier)
      Text(String(localized: "\(layout.position) of \(layout.count)"))
        .monospacedDigit()
        .accessibilityIdentifier(RequestDeck.positionIdentifier)
      stepButton(
        verb: .nextRequest, symbol: SharedSymbol.nextRequest, neighbor: \.next,
        identifier: RequestDeck.nextIdentifier)
      Spacer()
      if layout.moreCount > 0 {
        Text(String(localized: "+\(layout.moreCount)"))
          .monospacedDigit()
          .foregroundStyle(.secondary)
          .accessibilityIdentifier(RequestDeck.moreIdentifier)
      }
    }
    .font(.callout)
    .labelStyle(.iconOnly)
    .buttonStyle(.borderless)
  }

  /// The Previous or the Next button. It is disabled when the layout has no
  /// request before or after the front request.
  ///
  /// - Parameters:
  ///   - verb: ``AgentCommandVerb/previousRequest`` or
  ///     ``AgentCommandVerb/nextRequest``, whose title is the label.
  ///   - symbol: The symbol of the button.
  ///   - neighbor: ``DeckLayout/previous`` or ``DeckLayout/next``.
  ///   - identifier: The accessibility identifier of the button.
  /// - Returns: The button.
  private func stepButton(
    verb: AgentCommandVerb, symbol: String, neighbor: KeyPath<DeckLayout, PendingRequest.ID?>,
    identifier: String
  ) -> some View {
    Button {
      source.bringToFront(neighbor: neighbor)
    } label: {
      Label(verb.title, systemImage: symbol)
    }
    .disabled(layout[keyPath: neighbor] == nil)
    .accessibilityIdentifier(identifier)
  }
}

/// One card of a ``RequestDeck`` at its place in the stack.
///
/// Each card has the same modifiers in each role, so that a change of the
/// role does not change the identity of the card, and the card keeps its
/// state.
private struct DeckCard: View {
  /// The z index of the front card, above each other card.
  static let frontZIndex: Double = 1

  /// The z index of a card that does not show, below each edge.
  static let hiddenZIndex = -Double(DeckLayout.maximumEdgeCount + 1)

  /// The model that holds the request.
  let source: DeckSource

  /// The pending request.
  let request: PendingRequest

  /// The place of the card in the deck.
  let role: DeckCardRole

  @Environment(\.agentTheme) private var theme

  var body: some View {
    let identifier = RequestDeck.identifier(for: request.id.uuidString)
    let isFront = role == .front
    let shape = RoundedRectangle(cornerRadius: theme.radii.l, style: .continuous)
    cardContent
      .frame(maxHeight: .infinity, alignment: .top)
      .background(.background, in: shape)
      .overlay(shape.strokeBorder(.separator))
      .clipShape(shape)
      .contentContainer(identifier: identifier)
      .accessibilityFocusTarget(identifier)
      .opacity(role == .hidden ? 0 : 1)
      .allowsHitTesting(isFront)
      .disabled(!isFront)
      .zIndex(Self.zIndex(of: role))
      .layoutValue(key: DeckCardRoleKey.self, value: role)
  }

  /// The card view of the request.
  @ViewBuilder
  private var cardContent: some View {
    switch request {
    case .permission(let permission):
      if let session = source.session {
        PermissionView(request: permission, session: session)
      }
    case .elicitation(let elicitation):
      ElicitationCard(request: elicitation, owner: source.elicitationOwner)
    }
  }

  /// The drawing order of a card: the front card on top, then the edges from
  /// the nearest to the deepest, then the cards that do not show.
  ///
  /// - Parameter role: The place of the card.
  /// - Returns: The z index.
  private static func zIndex(of role: DeckCardRole) -> Double {
    switch role {
    case .front: frontZIndex
    case .edge(let depth): -Double(depth)
    case .hidden: hiddenZIndex
    }
  }
}

/// The layout value that gives the place of a card to ``DeckStackLayout``.
private nonisolated struct DeckCardRoleKey: LayoutValueKey {
  static let defaultValue = DeckCardRole.hidden
}

/// The stack of the cards of a ``RequestDeck``.
///
/// The front card has its ideal height, and the stack has the height of the
/// front card and of the top edges above it. Each edge has the frame of the
/// front card, a step higher for each depth and an inset narrower on each
/// side, so that only its top edge shows above the front card. A card that
/// does not show has the frame of the front card. An empty stack has no
/// size.
private struct DeckStackLayout: Layout {
  /// The number of sides of an edge card that the inset makes narrower: the
  /// left side and the right side.
  static let insetSideCount: CGFloat = 2

  /// The height of the top edge of one card behind the front card.
  let edgeStep: CGFloat

  /// The horizontal inset of each side of a card, for each step of depth.
  let edgeInset: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    guard let front = subviews.first(where: { $0[DeckCardRoleKey.self] == .front }) else {
      return .zero
    }
    let size = front.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
    return CGSize(width: proposal.width ?? size.width, height: size.height + topInset(of: subviews))
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let inset = topInset(of: subviews)
    let frontFrame = CGRect(
      x: bounds.minX, y: bounds.minY + inset, width: bounds.width, height: bounds.height - inset)
    for subview in subviews {
      let frame = Self.frame(of: subview[DeckCardRoleKey.self], front: frontFrame, step: edgeStep, inset: edgeInset)
      subview.place(at: frame.origin, anchor: .topLeading, proposal: ProposedViewSize(frame.size))
    }
  }

  /// The height above the front card that the top edges take.
  ///
  /// - Parameter subviews: The cards.
  /// - Returns: The number of the edges times ``edgeStep``.
  private func topInset(of subviews: Subviews) -> CGFloat {
    let edgeCount = subviews.filter { subview in
      if case .edge = subview[DeckCardRoleKey.self] { true } else { false }
    }.count
    return CGFloat(edgeCount) * edgeStep
  }

  /// The frame of a card.
  ///
  /// - Parameters:
  ///   - role: The place of the card.
  ///   - front: The frame of the front card.
  ///   - step: The height of one top edge.
  ///   - inset: The inset of each side for one step of depth.
  /// - Returns: The frame of the front card for the front card and for a card
  ///   that does not show. For an edge, the frame of the front card moved up
  ///   one step and made narrower for each depth.
  private static func frame(of role: DeckCardRole, front: CGRect, step: CGFloat, inset: CGFloat) -> CGRect {
    guard case .edge(let depth) = role else { return front }
    let side = CGFloat(depth) * inset
    return CGRect(
      x: front.minX + side, y: front.minY - CGFloat(depth) * step,
      width: max(0, front.width - insetSideCount * side), height: front.height)
  }
}
