import EditorCommands
import EditorCommandsUI
import EditorStyle
import FoundationModelsACPClient
import SwiftUI

/// The view of the transcript of a `SessionModel` (plan.md §3.2, §3.6,
/// §3.8, §8, §9 A).
///
/// The view shows the transcript in a ``ConversationView``, in a lazy stack
/// that follows the bottom. The conversation keys each row on
/// `TranscriptEntry.id`, and each item view reads its own entry object, so a
/// streamed chunk draws only the row of its entry.
///
/// In the top bar of the view (`.safeAreaBar(edge: .top)`), a
/// ``SessionNoticeBanner`` shows one banner for each notice of the session
/// model, and a ``SessionStreamBanner`` shows the stream state: the replay
/// marker, the partial-history note, the missed-updates banner with its
/// Reload button, and the closed state. In the bottom bar, a ``StateBanner``
/// shows the agent state. Each banner view, and not this view, reads its part
/// of the model.
///
/// The conversation scrolls under the top bar, and thus under the toolbar of
/// the window, with the scroll edge effect (D113 answer 7). The rows under
/// the top bar and the toolbar do not stay readable: AppKit sizes the one top
/// edge effect of the list to the whole top inset, so the effect washes out
/// the rows under the full stack of bars, and fades only near the top of the
/// list. The user accepted this system look on 2026-10-23 (^22wbz12). The
/// top bar has no background. The ``AgentInfoHeader`` in it floats on
/// `.regular` glass, the same as the conversation header in Messages
/// (`.floatingGlass()`). The banners in it are content
/// with no glass. VoiceOver reads the top bar, the conversation, and then
/// the bottom bar.
///
/// The bottom bar of the view (`.safeAreaBar(edge: .bottom)`) holds the
/// floating controls of the thread. The conversation scrolls under the bar
/// (EditorKit `style.md`, "Scroll under the bars"). From the top,
/// the bar shows the state banner, the login prompt and the composer slot.
/// The banner and the login prompt are content with no glass. Their buttons
/// keep the glass styles, because the content scrolls under them (EditorKit
/// `style.md`, rule 4). The composer slot is directly below its chat
/// (D36). The default slot is a ``DefaultThreadComposer``: a
/// ``PromptInputView`` that keeps its own text. Give a custom composer with
/// ``init(session:connection:sessionTitle:headerContextMenuPath:composer:)``,
/// or `EmptyView()` for no composer.
/// The scroll-to-bottom pill (``ScrollToBottomPill``) floats over the list,
/// above the bar, and takes no space in the bar. Thus the bottom inset of the
/// list does not change when the pill shows or goes away (^66has33). The pill
/// and the slot are in one `GlassEffectContainer`, with no glass on glass
/// (D110 (c)).
/// The thread view gives its session model and its connection model to the
/// slot (``SwiftUI/EnvironmentValues/sessionModel``,
/// ``SwiftUI/EnvironmentValues/connectionModel``), and the slot is in the
/// focus scope and the agent command scope of the thread. The commands of
/// the floating controls are ``AgentCommandVerb/scrollToBottom``,
/// ``AgentCommandVerb/focusComposer`` and ``AgentCommandVerb/send``, so the
/// menus, the keys and the command palette reach them.
///
/// The view shows no card for a pending permission request or a pending
/// elicitation of the session. Put a ``RequestDeck`` next to the view, or in
/// the composer slot above the composer:
///
/// ```swift
/// AgentThreadView(session: session, connection: connection) {
///   RequestDeck(session: session)
///   PromptInputView(text: $draft) {}
/// }
/// ```
///
/// A deck next to the view goes in one
/// ``SwiftUI/View/accessibilityFocusScope()`` with the thread view. The
/// ``RequestDeck`` documentation shows the full example.
///
/// When the host gives the connection model, an ``AgentInfoHeader`` names the
/// agent from its `initialize` answer and an ``AgentConnectionBanner`` shows
/// the connection state, at the top of the top bar, and an
/// ``AgentAuthView`` shows in the bottom bar while `ConnectionModel.authState`
/// asks for a sign-in, for example after an answer with the code `-32000`
/// (authentication required).
///
/// The host gives no actions. Each view in the thread calls the methods of
/// the session model or of the connection model directly. The two host hooks
/// are the ``SwiftUI/EnvironmentValues/terminalAuthRunner`` value, which runs
/// a terminal sign-in, and the ``SwiftUI/EnvironmentValues/agentReconnect``
/// value, which the Reconnect button calls. No model gives that work, so the
/// host gives it. See `Docs/decisions/acp-client-kit.md`.
///
/// To replace the view of a transcript entry case, use a typed modifier such
/// as ``SwiftUI/View/toolCallView(_:)``. The override gets the entry object.
///
/// The view gives an ``ExpandedBlocksStore`` to its rows. When the
/// environment has a store, the view uses that store.
///
/// A tap on an attachment in the view shows the file in an inspector. The
/// ``SwiftUI/View/agentAttachmentInspector(_:)`` modifier selects the
/// inspector:
///
/// - ``AttachmentInspectorMode/builtIn`` (the default): the view shows the
///   file in its own trailing inspector. See
///   ``SwiftUI/View/attachmentInspector(selection:)``. When the environment
///   has an ``InspectorSelection``, the view uses that selection. Do not use
///   this mode in a view that has its own `inspector(isPresented:content:)`,
///   such as a `NavigationSplitView` with an inspector. Two inspectors make
///   the minimum width of the column equal to the width of the window, and
///   AppKit can then stop the app.
/// - ``AttachmentInspectorMode/host(_:)``: the view applies no inspector. A
///   tap writes an ``AgentAttachmentSelection`` with the file and the session
///   id of this view to the binding of the host, and the host shows the file
///   in its own inspector, for example with ``AttachmentInspector``. More
///   than one thread view can share the binding.
///
/// Apply the modifier one time, at the root of the window. A change of the
/// mode makes the content of the view again, with new view state.
///
/// The view registers the agent commands of the session model
/// (``AgentCommandVerb``) with the keys of ``AgentKeymap``. See
/// ``SwiftUI/View/agentCommandScope(session:)``.
///
/// The view is accessible by default (plan.md §6, ``ThreadAccessibility``):
///
/// - It owns the namespace of the linked reading groups of its messages and
///   rows (``SwiftUI/View/accessibilityReadingScope()``).
/// - It tells the ``SwiftUI/EnvironmentValues/announcer`` when the work of a
///   prompt of this client ends (the first idle after the echo of the
///   prompt), and when a tool call gets its result. A streaming chunk gives
///   no announcement. The announcements read the session model directly.
///   The ``RequestDeck`` announces each new request that needs the user.
/// - It gives an ``AccessibilityFocusMover`` to its subtree
///   (``SwiftUI/View/accessibilityFocusScope()``) when the environment has
///   no mover, so that the views in its rows can move the VoiceOver focus.
///   A scope around the thread view, the deck and the prompt editor gives
///   one mover to the three.
public struct AgentThreadView<Composer: View>: View {
  /// The session model whose transcript the view shows.
  let session: SessionModel

  /// The connection model that closes the session when the view goes away,
  /// and that the Reload button of the missed-updates banner resumes the
  /// session on, or `nil`.
  let connection: ConnectionModel?

  /// The manager of the scroll position that a test gave, or `nil`.
  let hostAnchors: ScrollAnchorManager?

  /// The title of the session that the header shows after the agent, or
  /// `nil` for the agent alone.
  let sessionTitle: String?

  /// The path of the host scope whose context menu the header shows, or
  /// `nil` for no context menu.
  let headerContextMenuPath: FocusPath?

  /// The view in the composer slot, below the conversation.
  let composer: Composer

  /// The store that the view makes when the environment has none.
  @State private var ownExpandedBlocks = ExpandedBlocksStore()

  /// The inspector selection that the view makes when the environment has
  /// none.
  @State private var ownInspectorSelection = InspectorSelection()

  /// The scroll anchors of the list that the view makes when no manager is
  /// given. The agent commands use them to jump and to scroll.
  @State private var ownAnchors = ScrollAnchorManager()

  @Environment(\.expandedBlocksStore) private var hostExpandedBlocks
  @Environment(\.inspectorSelection) private var hostInspectorSelection
  @Environment(\.agentAttachmentInspector) private var inspectorMode
  @Environment(\.connectionModel) private var hostConnection
  @Environment(\.editorStyle) private var editorStyle

  /// The report that gets the close decision of the view when it goes away,
  /// or `nil`.
  @Environment(\.threadCloseReport) private var reportClose

  /// Makes the view of the transcript of a session model, with a custom view
  /// in the composer slot.
  ///
  /// The slot shows below the conversation, in one glass container with the
  /// scroll-to-bottom pill. The slot gets the session model and the
  /// connection model of the thread view in its environment. Give
  /// `EmptyView()` for no composer.
  ///
  /// See ``init(session:connection:sessionTitle:headerContextMenuPath:)`` for
  /// the close of the session, the Reload button, the session title and the
  /// context menu of the header.
  ///
  /// - Parameters:
  ///   - session: The session model whose transcript the view shows.
  ///   - connection: The connection model that opened the session, or `nil`
  ///     when the host closes the session itself.
  ///   - sessionTitle: The title of the session that the header shows after
  ///     the agent, such as the title of a tab, or `nil` for the agent alone.
  ///   - headerContextMenuPath: The path of a host scope whose context menu
  ///     a right click on the header shows, or `nil` for no context menu.
  ///   - composer: The builder of the view in the composer slot, such as a
  ///     ``PromptInputView``.
  public init(
    session: SessionModel, connection: ConnectionModel? = nil, sessionTitle: String? = nil,
    headerContextMenuPath: FocusPath? = nil, @ViewBuilder composer: () -> Composer
  ) {
    self.init(
      session: session, connection: connection, anchors: nil, sessionTitle: sessionTitle,
      headerContextMenuPath: headerContextMenuPath, composer: composer)
  }

  /// Makes the view of the transcript of a session model with a given
  /// manager of the scroll position.
  ///
  /// A hosted test gives the manager, so that it can give the manager a
  /// visibility report and read its pin state.
  ///
  /// - Parameters:
  ///   - session: The session model whose transcript the view shows.
  ///   - connection: The connection model that opened the session, or `nil`.
  ///   - anchors: The manager of the scroll position, or `nil` to let the
  ///     view make its own manager.
  ///   - sessionTitle: The title of the session that the header shows, or
  ///     `nil`.
  ///   - headerContextMenuPath: The path of the host scope whose context
  ///     menu the header shows, or `nil`.
  ///   - composer: The builder of the view in the composer slot.
  init(
    session: SessionModel, connection: ConnectionModel? = nil, anchors: ScrollAnchorManager?,
    sessionTitle: String? = nil, headerContextMenuPath: FocusPath? = nil,
    @ViewBuilder composer: () -> Composer
  ) {
    self.session = session
    self.connection = connection
    self.hostAnchors = anchors
    self.sessionTitle = sessionTitle
    self.headerContextMenuPath = headerContextMenuPath
    self.composer = composer()
  }

  /// The manager of the scroll position that the view uses.
  private var anchors: ScrollAnchorManager {
    hostAnchors ?? ownAnchors
  }

  public var body: some View {
    content
      // The agent command scope reads neither scope, so it can be inside
      // them.
      .accessibilityReadingScope()
      .accessibilityFocusScope()
      .environment(\.expandedBlocksStore, hostExpandedBlocks ?? ownExpandedBlocks)
      .modifier(
        ThreadAttachmentInspector(
          mode: inspectorMode, sessionId: session.sessionId,
          selection: Self.inspectorSelection(
            host: hostInspectorSelection, own: ownInspectorSelection)))
  }

  /// The selection that the view gives to its inspector.
  ///
  /// - Parameters:
  ///   - host: The selection of the environment, or `nil` when the
  ///     environment has none.
  ///   - own: The selection that the view makes itself.
  /// - Returns: `host` when it is not `nil`, otherwise `own`.
  static func inspectorSelection(host: InspectorSelection?, own: InspectorSelection)
    -> InspectorSelection
  {
    host ?? own
  }

  /// The conversation of the session model, with the header and the banners
  /// at the top in the top bar, and the floating controls in the bottom bar.
  ///
  /// The list scrolls under the two bars, and thus under the toolbar of the
  /// window, with the scroll edge effect (EditorKit `style.md`,
  /// "Scroll under the bars", D113 answer 7). The ``ConversationView`` asks
  /// for the soft effect at its top and bottom edges, so no window gives the
  /// opaque hard band. At the top, AppKit makes the effect as tall as the
  /// whole top inset: the toolbar, the bars of the host and this top bar. So
  /// the rows under that stack are washed out, and the fade is gradual only
  /// near the top of the list. The user accepted this system look on
  /// 2026-10-23 (^22wbz12). The top bar has no background
  /// (D112 (e)). The header is a floating surface: it is on the floating
  /// glass of the kit, in its own glass container. The banners are content
  /// with no glass, out of that container, so their buttons keep the button
  /// styles of content (``RequestDeckPlace/style(of:)``). From the top, the
  /// bar shows the header and the connection banner when the host gave the
  /// connection model, the notice banner and the stream banner. VoiceOver
  /// reads the top bar, the list and then the bottom bar.
  private var content: some View {
    VStack(spacing: 0) {
      ConversationView(session: session, anchors: anchors)
        // The state banner and the pill are in the floating controls, in the
        // bottom bar with the composer.
        .environment(\.conversationShowsPill, false)
        .environment(\.conversationShowsStateBanner, false)
    }
    .safeAreaBar(edge: .top) {
      VStack(spacing: 0) {
        if let connection {
          // The header floats on glass in its own container. The banners are
          // out of the container, so their buttons keep the place of content.
          // The padding is in the container, so a header that shows nothing
          // takes no space. The header has no padding of its own (^rgsq3k4):
          // the bar insets it in its glass with the steps of the style.
          FloatingGlassContainer(spacing: editorStyle.spacing.s) {
            AgentInfoHeader(connection: connection, sessionTitle: sessionTitle).padding(headerInset).floatingGlass()
              .hostPathContextMenu(headerContextMenuPath)
              .padding(.horizontal, barEdgeInset)
              .padding(.vertical, editorStyle.spacing.s)
          }
        }
        // The bar spaces the banners, which have no margin of their own
        // (^rgsq3k4): the stack stands them one tile margin apart. With no
        // subview there is no stack, so banners that show nothing take no
        // space.
        Group(subviews: banners) { subviews in
          if !subviews.isEmpty {
            VStack(spacing: editorStyle.tile.margin) { subviews }
              .padding(.horizontal, barEdgeInset)
              .padding(.vertical, editorStyle.tile.margin)
          }
        }
      }
    }
    .safeAreaBar(edge: .bottom) { floatingControls }
    .background { SessionAnnouncementObserver(session: session) }
    .agentCommandScope(session: session, anchors: anchors)
    .onDisappear(perform: closeWhenSupported)
  }

  /// The banners of the top bar, from the top: the connection banner when the
  /// host gave the connection model, the notice banner and the stream banner.
  @ViewBuilder private var banners: some View {
    if let connection {
      AgentConnectionBanner(connection: connection)
    }
    SessionNoticeBanner(session: session)
    SessionStreamBanner(session: session, connection: connection)
  }

  /// The inset of the content of the two bars from the side edges of the
  /// thread: the medium spacing step. The header, the banners and the floating
  /// controls all take it, so their side edges line up.
  private var barEdgeInset: CGFloat {
    editorStyle.spacing.m
  }

  /// The inset of the ``AgentInfoHeader`` in its glass: the medium spacing
  /// step on the leading and the trailing edge, and the small step on the
  /// top and the bottom edge. The header has no padding of its own
  /// (^rgsq3k4).
  private var headerInset: EdgeInsets {
    let spacing = editorStyle.spacing
    return EdgeInsets(top: spacing.s, leading: spacing.m, bottom: spacing.s, trailing: spacing.m)
  }

  /// The content of the bottom bar: the state banner, the login prompt, the
  /// scroll-to-bottom pill and the composer slot, in one glass container
  /// (D110 (c)).
  ///
  /// The list scrolls under the bar (EditorKit `style.md`, "Scroll
  /// under the bars", D113 answer 7). The banner and the login prompt are
  /// content: they have no glass, and a container with no glass child draws
  /// nothing. Each of them declares the place of a bar with no glass
  /// (``RequestDeckPlace/barWithoutGlass``), so their buttons keep the glass
  /// styles (``RequestDeckPlace/style(of:)``, EditorKit `style.md`,
  /// rule 4). Only the buttons on the glass of a request deck in the
  /// composer slot use the bordered styles. From the top,
  /// the order is the pill, the banner, the login prompt when the host gave
  /// the connection model, and the composer. VoiceOver reads them in this
  /// order. The pill is an overlay that floats one small spacing above the
  /// stack, over the list. It is not in the layout of the stack, so the height
  /// of the bar, and thus the bottom inset of the list, does not depend on the
  /// pin state. A pill in the stack made each pin change move the inset, and
  /// each move of the inset made the list report a layout with no row in view
  /// and unpin again: a loop that held the main actor (^66has33). A composer
  /// in the slot that makes its own container, such
  /// as ``PromptInputView``, uses this container. The controls are one
  /// accessibility container with
  /// ``AgentThreadLayout/floatingControlsIdentifier``.
  private var floatingControls: some View {
    // The alignment guide of the pill runs in a `Sendable` closure, so it
    // reads this copy and not the main-actor `theme`.
    let spacing = editorStyle.spacing.s
    return FloatingGlassContainer(spacing: spacing) {
      VStack(spacing: spacing) {
        // The banner reads `agentState` in its own body, so a change of the
        // state evaluates only the banner.
        StateBanner(session: session) { showItem($0.rowKey) }
        if let connection {
          AgentLoginPrompt(session: session, connection: connection)
        }
        composer
          .environment(\.sessionModel, session)
          .environment(\.connectionModel, connection ?? hostConnection)
      }
      // The pill floats above the controls and takes no space in their
      // layout, so its show and its hide keep the bottom inset of the list.
      .overlay(alignment: .top) {
        ConversationPill(anchors: anchors)
          .alignmentGuide(.top) { $0[.bottom] + spacing }
      }
    }
    .padding(barEdgeInset)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(AgentThreadLayout.floatingControlsIdentifier)
  }

  /// Moves the list to the item with `id`, for the Show Error button of the
  /// state banner.
  ///
  /// The manager keeps the item as its anchor. The conversation gets the
  /// scroll through ``ScrollAnchorManager/onScroll``, and it shows the page
  /// of the item before it scrolls.
  ///
  /// - Parameter id: The row key of the item.
  private func showItem(_ id: String) {
    anchors.noteJump(to: id)
    anchors.onScroll(.item(id))
  }

  /// Starts the close of the session when the host gave the connection
  /// model, the agent serves `session/close`, and the session is not closed.
  ///
  /// The view gives the decision to the
  /// ``SwiftUI/EnvironmentValues/threadCloseReport`` value in the same step,
  /// before the close starts.
  private func closeWhenSupported() {
    let closes = connection.map { $0.canCloseSessions && !session.isClosed } ?? false
    reportClose?(closes)
    guard closes, let connection else { return }
    Task { [session] in await Self.close(session, on: connection) }
  }

  /// Sends `session/close` for a session. A close that fails adds an error
  /// entry to the transcript of the session, which then stays open.
  ///
  /// - Parameters:
  ///   - session: The session to close.
  ///   - connection: The connection model of the session.
  private static func close(_ session: SessionModel, on connection: ConnectionModel) async {
    do {
      try await connection.close(session)
    } catch {
      session.appendError(reporting: error)
    }
  }
}

/// The fixed values of ``AgentThreadView``.
///
/// A generic view type cannot hold a stored static property, so the values
/// are in this separate type.
public enum AgentThreadLayout {
  /// The accessibility identifier of the floating controls of a thread: the
  /// state banner, the login prompt, the scroll-to-bottom pill and the
  /// composer slot, in one glass container in the bottom bar.
  public static let floatingControlsIdentifier = "thread-floating-controls"
}

extension EnvironmentValues {
  /// The ``ObservationReport`` that gets the close decision of the nearest
  /// ``AgentThreadView`` when the view goes away, or `nil`.
  ///
  /// The view calls the report in the same step as the decision: `true`
  /// when it starts the close of the session, `false` when it sends nothing.
  /// Thus a test that checks that no `session/close` goes out waits for the
  /// report, and not for a time.
  @Entry var threadCloseReport: ObservationReport<Bool>? = nil
}

#Preview("Thread") {
  let connection = ConnectionModel.previewSample
  if let session = connection.openSessions.first {
    AgentThreadView(session: session, connection: connection)
  }
}
