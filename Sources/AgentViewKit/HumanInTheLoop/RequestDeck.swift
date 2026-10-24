import EditorStyle
import EditorSwiftUI
import EditorTheme
import FoundationModelsACPClient
import SwiftUI

/// The deck of the requests that wait for the answer of the user
/// (plan.md §3.2 "Pending requests", §3.3 "Request-scoped elicitations",
/// §11 decision 4).
///
/// The deck is a component of its own. The chat stream, the deck and the
/// prompt editor are three separate components, and the app arranges them.
/// Put the deck and the prompt editor in the composer slot of the thread
/// view. The thread view then puts the three in one
/// ``SwiftUI/View/accessibilityFocusScope()``, so that the focus can go back
/// to the prompt editor, and it gives the session model and the connection
/// model to the prompt editor (``SwiftUI/EnvironmentValues/sessionModel``,
/// ``SwiftUI/EnvironmentValues/connectionModel``):
///
/// ```swift
/// AgentThreadView(session: session, connection: connection) {
///   RequestDeck(session: session)
///   PromptInputView(text: $draft) {}
/// }
/// ```
///
/// A deck out of the slot goes in one focus scope with the thread view.
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
/// The deck keeps no copy of the requests. It reads `pendingRequests`,
/// `awaitingURLCompletions` and `frontRequest` of the model in each body, and
/// the model removes a request when it resolves. A permission card is a
/// ``PermissionView``. An elicitation card is an ``ElicitationView`` for a
/// form mode request, or an ``ElicitationURLConsentView`` for a URL mode
/// request. The deck shows no card for an elicitation mode that the kit does
/// not know. Each card sends the answer of the user to the reply methods of
/// the model that holds the request. To change the cards, use the field
/// overrides of the elicitation views and the shared style
/// (`\.editorStyle`).
///
/// An elicitation card shows who asks, in the "who asks" line of
/// ``ElicitationHeader`` (identifier ``ElicitationView/whoAsksIdentifier``),
/// when the request has an agent path or a source, for example
/// "root › reviewer · runCode". The root label is the
/// ``SwiftUI/EnvironmentValues/elicitationRootAgentLabel`` environment value.
/// Set it on the deck to give the root agent a name, for example
/// `.environment(\.elicitationRootAgentLabel, "Claude")`. A permission card
/// shows no such line.
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
///   in `pendingRequests`. VoiceOver reads "k of N" and "+N" as one element,
///   for example "Request 1 of 6, 2 more" (``DeckLayout/positionLabel``), so
///   the "+N" text is hidden from VoiceOver. The Previous and Next buttons
///   (identifiers ``previousIdentifier`` and ``nextIdentifier``) bring the
///   request before or after the front request to the front, with
///   `bringToFront(_:)` of the model. They do not wrap.
///   ``AgentCommandVerb/previousRequest`` and
///   ``AgentCommandVerb/nextRequest`` do the same from a key or the command
///   palette.
/// - An accepted URL mode elicitation stays in the deck while the model holds
///   it in `awaitingURLCompletions` (deck design section 7). Its card is a
///   waiting card below the front card, at full size, and it is not in
///   "k of N". The header shows "N waiting" (identifier
///   ``waitingIdentifier``). The card keeps the identity that it had before
///   the accept, so its browser session continues. The card goes away when
///   the agent sends `elicitation/complete`, or when the user presses Cancel
///   in the waiting state (``ElicitationURLConsentView``).
/// - Only the front card and the waiting cards take a click or the keyboard
///   focus. A card that does not show has no opacity.
/// - A deck with no pending request, no waiting card and no notice of a
///   withdrawn request shows nothing and takes no space. A deck with only
///   notices shows the notices in the deck padding. The change of the front
///   card is animated only when Reduce Motion is off.
///
/// The deck shows one notice above the header for each request that the
/// agent withdrew with `$/cancel_request`, from `withdrawnRequests` of the
/// model, in withdrawal order. The text is "<title> was withdrawn: <reason>",
/// or "<title> was withdrawn." when the agent gave no reason. The title is
/// the permission title or the elicitation message. A notice has the
/// information symbol, the information tint of the EditorKit theme, the
/// content edge, and a Dismiss button that calls `dismissWithdrawn(_:)` of
/// the model. The text has the identifier `request-deck-withdrawn-<id>`
/// (``identifier(forWithdrawn:)``) and the button has the identifier
/// `request-deck-withdrawn-dismiss-<id>`, where `<id>` is the id that the
/// request had while it was pending. A notice stays until the user presses
/// Dismiss: a new request does not remove it.
///
/// The surface of the deck comes from its place (TestudoApp
/// `features/style.md`, "How the steps apply"). The deck reads whether a
/// `FloatingGlassContainer` is above it: the container gives its glass
/// namespace (`\.floatingGlassNamespace`), and out of a container the
/// namespace is `nil`:
///
/// - In a bar of floating controls, for example the composer slot of
///   ``AgentThreadView``, a request is user input. The whole deck is on the
///   `.regular` floating glass of the kit, in the `GlassEffectContainer` of
///   the bar (`.floatingGlass()`). The cards and the
///   notices in it have no glass of their own.
/// - In content, the deck has no glass and no fill.
///
/// The place also gives the button styles of the actions in the cards and in
/// the notices (``RequestDeckPlace/style(of:)``, TestudoApp
/// `features/style.md`, "Buttons on glass"). In the bar, a glass button on the
/// glass of the deck is glass on glass. Thus each action of a card uses the
/// `.bordered` style. In content, the actions use the `.glass` style. No
/// action, not even the primary action (for example Allow once), uses a
/// prominent style: the accent is only for the selection and the focus (card
/// ^k06v4gt).
///
/// In both places, each card has no fill, and the separator stroke of the
/// content edge marks it (`.inlineEdge(radius:)`, D113).
/// The front card does not hide the cards behind it. Thus a card behind the
/// front card shows only the top edge of its stroke, and not its content.
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
/// The focus and the announcements (deck design section 4):
///
/// - A new card does not take the VoiceOver focus or the keyboard focus. The
///   deck announces each new request of its model, "Action required:
///   <title>", at `.high` to the ``SwiftUI/EnvironmentValues/announcer``.
///   The deck announces each new notice of a withdrawn request one time,
///   with the text of the notice, at `.medium`. Previous, Next and Dismiss
///   give no announcement.
/// - The deck moves the focus only in two cases
///   (``focusTarget(oldIDs:newIDs:oldFront:newFront:)``). When the front
///   request leaves `pendingRequests`, the VoiceOver focus goes to the new
///   front card, or to the prompt editor when no pending request stays. The
///   accept of a URL mode elicitation removes it from `pendingRequests`, so
///   the focus moves also when its card stays as a waiting card. A waiting
///   card asks for no input and is not a pending request: when only waiting
///   cards stay, the focus goes to the prompt editor. When the user brings a
///   request to the front, for example with Previous or Next, the VoiceOver
///   focus and the keyboard focus go into its card. A notice of a withdrawn
///   request takes no focus, and its Dismiss button moves no focus.
/// - Only the front card and the waiting cards are in the accessibility tree.
///   The edges and the cards that do not show are hidden from VoiceOver. A
///   waiting card gives no announcement and moves no focus.
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

  /// The accessibility identifier of the "N waiting" text of the header.
  public static let waitingIdentifier = "request-deck-waiting"

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

  /// The accepted URL mode elicitations of the model that wait for the end
  /// of the flow in the browser (`awaitingURLCompletions`) and have a card,
  /// oldest first. They are not in ``requests``.
  var awaiting: [PendingRequest] {
    elicitationOwner.awaitingURLCompletions.filter(ElicitationCard.hasCard(for:)).map(PendingRequest.elicitation)
  }

  /// The pending request that the model shows first, or `nil` when no
  /// request waits.
  var front: PendingRequest? {
    switch self {
    case .session(let session): session.frontRequest
    case .connection(let connection): connection.frontRequest
    }
  }

  /// The notice of each request that the agent withdrew from the model
  /// (`withdrawnRequests`), in withdrawal order.
  var withdrawn: [WithdrawnNotice] {
    let records =
      switch self {
      case .session(let session): session.withdrawnRequests
      case .connection(let connection): connection.withdrawnRequests
      }
    return records.map(WithdrawnNotice.init(record:))
  }

  /// Removes the record of one withdrawn request from the model.
  ///
  /// - Parameter id: The id of the record.
  func dismissWithdrawn(_ id: WithdrawnRequest.ID) {
    switch self {
    case .session(let session): session.dismissWithdrawn(id)
    case .connection(let connection): connection.dismissWithdrawn(id)
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

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.announcer) private var announcer

  /// The request whose card has the keyboard focus, or `nil`. The deck sets
  /// it only when the user brings a request to the front.
  @FocusState private var keyboardFocus: PendingRequest.ID?

  /// The action that moves the VoiceOver focus and tells the host.
  private let moveFocus = AccessibilityFocusMove()

  var body: some View {
    let requests = source.requests
    let awaiting = source.awaiting
    let cards = requests + awaiting
    let withdrawn = source.withdrawn
    let layout = source.layout(of: requests)
    let waitingIDs = Set(awaiting.map(\.id))
    let edgeStep = editorStyle.spacing.s
    VStack(alignment: .leading, spacing: editorStyle.spacing.s) {
      ForEach(withdrawn) { notice in
        WithdrawnNoticeRow(notice: notice) { source.dismissWithdrawn(notice.id) }
      }
      if layout.showsHeader || !awaiting.isEmpty {
        DeckHeader(source: source, layout: layout, waitingCount: awaiting.count)
      }
      // With no card, the stack is not in the deck, so a deck with only
      // notices has no space below the notices.
      if !cards.isEmpty {
        DeckStackLayout(edgeStep: edgeStep, edgeInset: editorStyle.spacing.m, waitingSpacing: editorStyle.spacing.s) {
          // One `ForEach` for the pending and the waiting cards, so that an
          // accepted card keeps its identity and its browser session.
          ForEach(cards) { request in
            DeckCard(
              source: source, request: request,
              role: waitingIDs.contains(request.id) ? .waiting : layout.role(of: request.id),
              edgeStep: edgeStep, keyboardFocus: $keyboardFocus)
          }
        }
      }
    }
    .padding(cards.isEmpty && withdrawn.isEmpty ? 0 : editorStyle.spacing.m)
    .modifier(DeckSurface())
    .contentContainer(identifier: RequestDeck.identifier)
    .animation(reduceMotion ? nil : .default, value: layout.front)
    .announcing(
      changesOf: requests.map(ThreadAccessibility.PendingRequestSummary.init(request:)), to: announcer,
      priority: .high, texts: ThreadAccessibility.actionRequiredAnnouncements(old:new:)
    )
    .announcing(
      changesOf: withdrawn, to: announcer, priority: .medium, texts: RequestDeck.withdrawnAnnouncements(old:new:)
    )
    .onChange(of: DeckOrder(ids: requests.map(\.id), front: layout.front), deckDidChange(from:to:))
  }

  /// Moves the focus after one change of the requests or of the front, as
  /// ``RequestDeck/focusTarget(oldIDs:newIDs:oldFront:newFront:)`` tells.
  ///
  /// - Parameters:
  ///   - old: The requests and the front before the change.
  ///   - new: The requests and the front after the change.
  private func deckDidChange(from old: DeckOrder, to new: DeckOrder) {
    guard
      let move = RequestDeck.focusTarget(
        oldIDs: old.ids, newIDs: new.ids, oldFront: old.front, newFront: new.front)
    else { return }
    moveFocus(to: move.identifier)
    if let id = move.keyboardFocus {
      keyboardFocus = id
    }
  }
}

/// The place of a ``RequestDeck`` or of other action buttons, which gives the
/// surface of the deck (TestudoApp `features/style.md`, "How the steps
/// apply") and the button styles of the actions (``style(of:)``).
nonisolated enum RequestDeckPlace: Equatable, Sendable {
  /// In a bar of floating controls, for example the composer slot of
  /// ``AgentThreadView``. A request in the bar is user input, so the deck is
  /// in the control layer: it is on the floating glass of the kit, in the
  /// `GlassEffectContainer` of the bar. Only the buttons on the glass of the
  /// deck have this place.
  case bar

  /// In a bar with no glass surface, for example the state banner and the
  /// login prompt in the bottom bar of ``AgentThreadView``. The content
  /// scrolls under the bar (TestudoApp `features/style.md`, rule 4). A view
  /// declares this place for its buttons with
  /// ``SwiftUI/View/requestActionPlace(_:)``. A deck never has this place.
  case barWithoutGlass

  /// In content. The deck has no glass and no fill.
  case content

  /// The place of a deck in or out of a glass container of floating
  /// controls.
  ///
  /// - Parameter isInFloatingGlassContainer: Whether a
  ///   `FloatingGlassContainer` is above the deck: its
  ///   `\.floatingGlassNamespace` is not `nil`.
  init(isInFloatingGlassContainer: Bool) {
    self = isInFloatingGlassContainer ? .bar : .content
  }

  /// The place of action buttons: the place that a view above them declares,
  /// or else the place from the glass containers above them.
  ///
  /// - Parameters:
  ///   - declared: The ``SwiftUI/EnvironmentValues/requestActionPlace`` of
  ///     the buttons, or `nil` when no view declares a place.
  ///   - isInFloatingGlassContainer: Whether a `FloatingGlassContainer` is
  ///     above the buttons.
  init(declared: RequestDeckPlace?, isInFloatingGlassContainer: Bool) {
    self = declared ?? RequestDeckPlace(isInFloatingGlassContainer: isInFloatingGlassContainer)
  }
}

/// The surface of a ``RequestDeck`` in its place (``RequestDeckPlace``).
///
/// In the bar, the whole deck is on the floating glass of the kit
/// (`.floatingGlass()`), and the cards and the notices in
/// it have no glass of their own. In content, the deck has no surface: each
/// card has only the content edge (`.inlineEdge(radius:)`).
private struct DeckSurface: ViewModifier {
  /// The glass namespace of the `FloatingGlassContainer` above the deck, or
  /// `nil` out of a container.
  @Environment(\.floatingGlassNamespace) private var glassNamespace

  func body(content: Content) -> some View {
    switch RequestDeckPlace(isInFloatingGlassContainer: glassNamespace != nil) {
    case .bar: content.floatingGlass()
    case .barWithoutGlass, .content: content
    }
  }
}

/// The ids of the pending requests of a ``RequestDeck`` and its front
/// request, for the comparison of one change. The waiting cards are not in
/// the order.
private struct DeckOrder: Equatable {
  /// The ids of the pending requests, oldest first.
  let ids: [PendingRequest.ID]

  /// The id of the front request, or `nil` when no pending request stays.
  let front: PendingRequest.ID?
}

/// The header of a ``RequestDeck``: with more than one pending request, the
/// Previous button, "k of N", the Next button, and "+N"; with a waiting card,
/// "N waiting".
private struct DeckHeader: View {
  /// The model whose front the buttons change.
  let source: DeckSource

  /// The layout of the deck.
  let layout: DeckLayout

  /// The number of the waiting cards, which are not in "k of N".
  let waitingCount: Int

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme

  var body: some View {
    HStack(spacing: editorStyle.spacing.s) {
      if layout.showsHeader {
        position
      }
      Spacer()
      if layout.moreCount > 0 {
        Text(String(localized: "+\(layout.moreCount)", bundle: .module))
          .monospacedDigit()
          .foregroundStyle(.secondary)
          .accessibilityIdentifier(RequestDeck.moreIdentifier)
          // The label of "k of N" reads the count.
          .accessibilityHidden(true)
      }
      if waitingCount > 0 {
        Text(String(localized: "\(waitingCount) waiting", bundle: .module))
          .monospacedDigit()
          .foregroundStyle(.secondary)
          .accessibilityIdentifier(RequestDeck.waitingIdentifier)
      }
    }
    .font(editorTheme.font(for: .ui, style: .callout))
    .labelStyle(.iconOnly)
    .buttonStyle(.borderless)
  }

  /// The Previous button, "k of N", and the Next button.
  @ViewBuilder
  private var position: some View {
    stepButton(
      verb: .previousRequest, symbol: SharedSymbol.previousRequest, neighbor: \.previous,
      identifier: RequestDeck.previousIdentifier)
    Text(String(localized: "\(layout.position) of \(layout.count)", bundle: .module))
      .monospacedDigit()
      .accessibilityLabel(layout.positionLabel)
      .accessibilityIdentifier(RequestDeck.positionIdentifier)
    stepButton(
      verb: .nextRequest, symbol: SharedSymbol.nextRequest, neighbor: \.next,
      identifier: RequestDeck.nextIdentifier)
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

  /// The z index of a waiting card. It is below the front card and has no
  /// overlap with the other cards.
  static let waitingZIndex: Double = 0

  /// The model that holds the request.
  let source: DeckSource

  /// The pending request.
  let request: PendingRequest

  /// The place of the card in the deck.
  let role: DeckCardRole

  /// The height of the top edge of one card behind the front card, which
  /// ``DeckStackLayout`` uses.
  let edgeStep: CGFloat

  /// The keyboard focus of the deck: the card gets the keyboard focus when
  /// it holds the id of the request.
  let keyboardFocus: FocusState<PendingRequest.ID?>.Binding

  /// The shared style that gives the radius of the edge of the card.
  @Environment(\.editorStyle) private var editorStyle

  var body: some View {
    let identifier = RequestDeck.identifier(for: request.id.uuidString)
    let showsWhole = role.showsWhole
    // The card has no fill (D113), so the front card does not hide the cards
    // behind it. An edge card thus hides its content, and the band shows only
    // the top edge of its stroke above the front card.
    cardContent
      .focused(keyboardFocus, equals: request.id)
      .frame(maxHeight: .infinity, alignment: .top)
      .opacity(showsWhole ? 1 : 0)
      .inlineEdge(radius: editorStyle.radii.l)
      .mask { DeckCardBand(role: role, edgeStep: edgeStep) }
      .contentContainer(identifier: identifier)
      .accessibilityFocusTarget(identifier)
      .accessibilityHidden(!showsWhole)
      .opacity(role == .hidden ? 0 : 1)
      .allowsHitTesting(showsWhole)
      .disabled(!showsWhole)
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
          .agentItemScope(AgentScopeKind.request(permission.id), subject: permission, isTargetable: role.showsWhole)
      }
    case .elicitation(let elicitation):
      ElicitationCard(request: elicitation, owner: source.elicitationOwner)
    }
  }

  /// The drawing order of a card: the front card on top, then the waiting
  /// cards, then the edges from the nearest to the deepest, then the cards
  /// that do not show.
  ///
  /// - Parameter role: The place of the card.
  /// - Returns: The z index.
  private static func zIndex(of role: DeckCardRole) -> Double {
    switch role {
    case .front: frontZIndex
    case .waiting: waitingZIndex
    case .edge(let depth): -Double(depth)
    case .hidden: hiddenZIndex
    }
  }
}

/// The part of a ``RequestDeck`` card that shows: the mask of the card.
///
/// An edge card shows only its top band, above the front card: the depth of
/// the card times the edge step. Each other card shows its whole frame. The
/// band goes out of the frame by ``strokeOutset`` on each side, so that the
/// mask does not cut the half of the separator stroke that is out of the
/// frame. The bottom of the band of an edge card does not go out, so that no
/// part of the edge card shows on the front card.
nonisolated struct DeckCardBand: Shape {
  /// The distance that the band goes out of the frame of the card. It is more
  /// than the half width of the separator stroke of
  /// `.inlineEdge(radius:)`, which is one point wide.
  static let strokeOutset: CGFloat = 1

  /// The place of the card in the deck.
  let role: DeckCardRole

  /// The height of the top edge of one card behind the front card.
  let edgeStep: CGFloat

  func path(in rect: CGRect) -> Path {
    let outset = Self.strokeOutset
    var band = rect.insetBy(dx: -outset, dy: -outset)
    if case .edge(let depth) = role {
      band.size.height = CGFloat(depth) * edgeStep + outset
    }
    return Path(band)
  }
}

/// The layout value that gives the place of a card to ``DeckStackLayout``.
private nonisolated struct DeckCardRoleKey: LayoutValueKey {
  static let defaultValue = DeckCardRole.hidden
}

/// The stack of the cards of a ``RequestDeck``.
///
/// The front card has its ideal height, and the top edges are above it. Each
/// edge has the frame of the front card, a step higher for each depth and an
/// inset narrower on each side, so that only its top edge shows above the
/// front card. A card that does not show has the frame of the front card.
/// Each waiting card has its ideal height, below the front card, or at the
/// top when no card is at the front, with ``waitingSpacing`` between two
/// cards. An empty stack has no size. For a zero proposed height, the
/// minimum size that a host asks for, each card has its own minimum height.
private struct DeckStackLayout: Layout {
  /// The number of sides of an edge card that the inset makes narrower: the
  /// left side and the right side.
  static let insetSideCount: CGFloat = 2

  /// The height of the top edge of one card behind the front card.
  let edgeStep: CGFloat

  /// The horizontal inset of each side of a card, for each step of depth.
  let edgeInset: CGFloat

  /// The space above each waiting card that has a card above it.
  let waitingSpacing: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let wholeCards = subviews.filter { $0[DeckCardRoleKey.self].showsWhole }
    guard !wholeCards.isEmpty else { return .zero }
    // Each card takes its ideal height at the proposed width. The minimum
    // probe of a host, such as the window, proposes a zero size: then each
    // card gives its own minimum height, and not the height of its text
    // wrapped at a zero width, which is taller than a screen.
    let isMinimumProbe = proposal.height == .zero
    let cardProposal = ProposedViewSize(width: proposal.width, height: isMinimumProbe ? .zero : nil)
    let heights = wholeCards.map { $0.sizeThatFits(cardProposal).height }
    let width = proposal.width ?? wholeCards.map { $0.sizeThatFits(cardProposal).width }.max() ?? 0
    let height = heights.reduce(0, +) + CGFloat(heights.count - 1) * waitingSpacing + topInset(of: subviews)
    return CGSize(width: width, height: height)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let inset = topInset(of: subviews)
    let ideal = ProposedViewSize(width: bounds.width, height: nil)
    let waiting = subviews.filter { $0[DeckCardRoleKey.self] == .waiting }
    let waitingHeight = waiting.map { $0.sizeThatFits(ideal).height + waitingSpacing }.reduce(0, +)
    let hasFront = subviews.contains { $0[DeckCardRoleKey.self] == .front }
    // The front card takes the height that the edges and the waiting cards
    // do not take.
    let frontFrame = CGRect(
      x: bounds.minX, y: bounds.minY + inset, width: bounds.width,
      height: hasFront ? max(0, bounds.height - inset - waitingHeight) : 0)
    var waitingTop = hasFront ? frontFrame.maxY + waitingSpacing : bounds.minY
    for subview in subviews {
      let role = subview[DeckCardRoleKey.self]
      if role == .waiting {
        let height = subview.sizeThatFits(ideal).height
        subview.place(
          at: CGPoint(x: bounds.minX, y: waitingTop), anchor: .topLeading,
          proposal: ProposedViewSize(width: bounds.width, height: height))
        waitingTop += height + waitingSpacing
      } else {
        let frame = Self.frame(of: role, front: frontFrame, step: edgeStep, inset: edgeInset)
        subview.place(at: frame.origin, anchor: .topLeading, proposal: ProposedViewSize(frame.size))
      }
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

#Preview("Request deck") {
  RequestDeck(session: .previewSample)
}
