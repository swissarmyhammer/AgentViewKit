import EditorCommands
import EditorCommandsUI
import EditorStyle
import FoundationModelsACP
import FoundationModelsACPClient
import OSLog
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
/// marker, the missed-updates banner with its Reload button, and the closed
/// state. In the bottom bar, a ``StateBanner`` shows the agent state. Each
/// banner view, and not this view, reads its part of the model.
///
/// The view puts no padding around its bars (EditorKit `style.md`, rule
/// 10). The host pads them where it mounts the view, with `.barInsets()`,
/// which gives each bar the inset of the style (`EditorStyle.bar`). With no
/// `.barInsets()`, the bars have no inset (^e0wdpmg). The
/// ``ConversationView`` pads the content of its list on the leading and the
/// trailing edge by the same inset. Thus the leading edge of each row
/// surface, such as a message row or a tool call card, stands under the
/// leading edge of the header glass and of the composer glass (^0er2xf6).
///
/// The conversation scrolls under the top bar, and thus under the toolbar of
/// the window, with the scroll edge effect (D113 answer 7). The rows under
/// the top bar and the toolbar do not stay readable: AppKit sizes the one top
/// edge effect of the list to the whole top inset, so the effect washes out
/// the rows under the full stack of bars, and fades only near the top of the
/// list. The user accepted this system look on 2026-10-23 (^22wbz12). The
/// top bar has no background. The ``StatusLineView`` in it floats on
/// `.regular` glass, the same as the conversation header in Messages
/// (`.floatingGlass()`). The banners in it float over the conversation, so
/// they are on the same glass, in one glass container with the status line
/// (TestudoApp D213). VoiceOver reads the top bar, the conversation, and then
/// the bottom bar.
///
/// The bottom bar of the view (`.safeAreaBar(edge: .bottom)`) holds the
/// floating controls of the thread. The conversation scrolls under the bar
/// (EditorKit `style.md`, "Scroll under the bars"). From the top,
/// the bar shows the state banner, the login prompt and the composer slot.
/// The banner and the login prompt float over the conversation, so they are
/// on the floating glass of the kit (``StatusBarPlacement/floating``,
/// TestudoApp D213). Their buttons stand on that glass, so they take the
/// bordered styles (EditorKit `style.md`, rule 4). The composer slot is directly below its chat
/// (D36). The default slot is a ``DefaultThreadComposer``: a
/// ``PromptInputView`` that keeps its own text. Give a custom composer with
/// ``init(session:connection:sessionTitle:headerContextMenuPath:composer:)``,
/// or `EmptyView()` for no composer.
/// In a thread with no transcript entry, the editor of the composer takes the
/// first responder when the thread shows, and when the scope of the thread
/// gets the focus, for example from a click on the empty space of the thread
/// (``EmptyThreadComposerFocus``, Testudo, 2026-11-20).
/// For a read-only session (`SessionModel.isReadOnly`, the shared session of
/// TestudoApp D208 (i)), the view shows no composer slot
/// (``AgentThreadLayout/showsComposer(for:hasHostComposer:)``), and its scope
/// registers no verb that changes the session
/// (``AgentCommandGroup/changesSession``). With
/// ``SwiftUI/View/threadComposer(placeholder:onSubmit:)`` (TestudoApp D212),
/// the view of a read-only session shows the composer slot with the
/// placeholder of the host, and each prompt goes to the closure of the host,
/// not to the session.
/// The thread keeps the verbs that read it, such as Copy Thread, Export as
/// Markdown… and the find and navigation verbs. When the model gets a newer
/// snapshot (`SessionModel.replace(with:)`), each entry that stays keeps its
/// id and thus its row key, so the list keeps its scroll position.
/// The scroll-to-bottom pill (``ScrollToBottomPill``) floats over the list,
/// above the bar, and takes no space in the bar. Thus the bottom inset of the
/// list does not change when the pill shows or goes away (^66has33). The pill
/// and the slot are in one `GlassEffectContainer`, with no glass on glass
/// (D110 (c)). The button of the pill is in a second container in that
/// container, so the hidden pill draws no label (``ConversationPill``,
/// task ^ctzmqh3).
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
/// The side cards of `/btw` (``SideQuestionCard``) show at the trailing edge
/// above the composer with ``SwiftUI/View/sideCards(_:)`` (D205). They float with the
/// floating controls, so they do not change the transcript or the scroll
/// position.
///
/// A host fills the header slot above the transcript with
/// ``SwiftUI/View/threadHeader(_:)``, such as "Shared by Ann · Updated
/// today" for a shared session, and shows a message in place of the
/// transcript with ``SwiftUI/View/threadUnavailable(_:)``, such as "The owner
/// stopped sharing this session." (TestudoApp D208 (i)). The two are content
/// with no glass (D110). While the message shows, the header stays, and the
/// verbs that read the text of the session are not available.
///
/// The hits of a search of the session transcripts show in the thread with
/// ``SwiftUI/View/transcriptSearchHits(_:)`` (TestudoApp D207 (f)): the thread scrolls to
/// the best hit, and marks the matched words of each hit. Find Next Hit
/// (Command-G) and Find Previous Hit (Shift-Command-G) go through the hits
/// in the order of the transcript, and Clear Search Hits (Esc) removes them.
///
/// A deck next to the view goes in one
/// ``SwiftUI/View/accessibilityFocusScope()`` with the thread view. The
/// ``RequestDeck`` documentation shows the full example.
///
/// When the host gives the connection model, a ``StatusLineView`` shows the
/// status line of the session (D194: the folder, git, the languages of the
/// code and the session, in the ``StatusLineDefinition`` of
/// ``SwiftUI/View/statusLine(_:)``) and an ``AgentConnectionBanner`` shows
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
/// A click on an attachment in the view shows the file in an inspector. The
/// view selects files with the selection model of EditorKit's lists: a click
/// selects one file, a Command-click adds a file or takes it out, and a
/// Shift-click adds each file from the anchor to the file, in transcript
/// order (``TranscriptFileOrder``). The
/// ``SwiftUI/View/agentAttachmentInspector(_:)`` modifier selects the
/// inspector:
///
/// - ``AttachmentInspectorMode/builtIn`` (the default): the view shows the
///   files in its own trailing inspector. See
///   ``SwiftUI/View/attachmentInspector(selection:)``. When the environment
///   has an ``InspectorSelection``, the view uses that selection. Do not use
///   this mode in a view that has its own `inspector(isPresented:content:)`,
///   such as a `NavigationSplitView` with an inspector. Two inspectors make
///   the minimum width of the column equal to the width of the window, and
///   AppKit can then stop the app.
/// - ``AttachmentInspectorMode/host(_:)``: the view applies no inspector. A
///   press changes the list of ``AgentAttachmentSelection`` values of the
///   binding of the host, each with the file and the session id of its
///   view, and the host shows the files in its own inspector, for example
///   with ``AttachmentInspector``. More than one thread view can share the
///   binding.
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
  /// The log of the view.
  private static var logger: Logger {
    Logger(subsystem: "AgentViewKit", category: "AgentThreadView")
  }

  /// The session model that the host gave: the root of the tree that the
  /// view can show. The view shows this session at first, and again after a
  /// resume.
  let root: SessionModel

  /// The session that the user chose in the header, a banner or a tool row.
  /// Which session a window shows is state of the view and not of the model,
  /// so two windows can show different sessions of one connection. The value
  /// keeps ids, and looks them up in the live tree (``SessionFocus``).
  @State private var focus = SessionFocus()

  /// The scroll position of each session that the view showed.
  @State private var anchorStore = SessionAnchorStore()

  /// Whether the list of Jump to Session shows.
  @State private var isJumpPresented = false

  /// The connection model that closes the session when the view goes away,
  /// and that the Reload button of the missed-updates banner resumes the
  /// session on, or `nil`.
  let connection: ConnectionModel?

  /// The manager of the scroll position that a test gave, or `nil`.
  let hostAnchors: ScrollAnchorManager?

  /// The title that the header shows for the session of the host, such as
  /// the title of a tab, or `nil` for the title of the session (D142).
  let sessionTitle: String?

  /// The path of the host scope whose context menu each point of the top bar
  /// shows (the status line, the header of the host, each banner and each
  /// gap between two parts), or `nil` for no context menu.
  let headerContextMenuPath: FocusPath?

  /// The view in the composer slot, below the conversation.
  let composer: Composer

  /// The store that the view makes when the environment has none.
  @State private var ownExpandedBlocks = ExpandedBlocksStore()

  /// The inspector selection that the view makes when the environment has
  /// none.
  @State private var ownInspectorSelection = InspectorSelection()

  /// The search hits of the host (``SwiftUI/View/transcriptSearchHits(_:)``), the current
  /// hit and its reveal.
  @State private var search = TranscriptSearch()

  @Environment(\.expandedBlocksStore) private var hostExpandedBlocks
  @Environment(\.inspectorSelection) private var hostInspectorSelection
  @Environment(\.agentAttachmentInspector) private var inspectorMode
  @Environment(\.connectionModel) private var hostConnection
  @Environment(\.editorStyle) private var editorStyle

  /// The side cards of the host (``SwiftUI/View/sideCards(_:)``), or `nil`.
  @Environment(\.sideCards) private var sideCards

  /// The header of the host (``SwiftUI/View/threadHeader(_:)``), or `nil`.
  @Environment(\.threadHeader) private var threadHeader

  /// The message that the host shows in place of the transcript
  /// (``SwiftUI/View/threadUnavailable(_:)``), or `nil`.
  @Environment(\.threadUnavailable) private var unavailableMessage

  /// The composer of the host for a read-only session
  /// (``SwiftUI/View/threadComposer(placeholder:onSubmit:)``), or `nil`.
  @Environment(\.threadComposerRoute) private var hostComposer

  /// The inset of each bar from the edges of the thread, which the host
  /// gives where it mounts the view (`.barInsets()`). The default is zero:
  /// the view pads nothing of its own.
  @Environment(\.barInsets) private var barInsets

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
  /// See ``init(session:connection:sessionTitle:headerContextMenuPath:composer:)`` for
  /// the close of the session, the Reload button, the path in the header and
  /// the context menu of the top bar.
  ///
  /// - Parameters:
  ///   - session: The session model whose transcript the view shows.
  ///   - connection: The connection model that opened the session, or `nil`
  ///     when the host closes the session itself.
  ///   - sessionTitle: The title of the crumb of the session in the header,
  ///     such as the title of a tab, or `nil` for the title of the session.
  ///     The header follows each change of it.
  ///   - headerContextMenuPath: The path of a host scope whose context menu
  ///     a right click on each point of the top bar shows (the status line,
  ///     the header of the host, each banner and each gap between two
  ///     parts), or `nil` for no context menu.
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
  ///   - sessionTitle: The title of the crumb of the session in the header,
  ///     or `nil`.
  ///   - headerContextMenuPath: The path of the host scope whose context
  ///     menu each point of the top bar shows, or `nil`.
  ///   - composer: The builder of the view in the composer slot.
  init(
    session: SessionModel, connection: ConnectionModel? = nil, anchors: ScrollAnchorManager?,
    sessionTitle: String? = nil, headerContextMenuPath: FocusPath? = nil,
    @ViewBuilder composer: () -> Composer
  ) {
    self.root = session
    self.connection = connection
    self.hostAnchors = anchors
    self.sessionTitle = sessionTitle
    self.headerContextMenuPath = headerContextMenuPath
    self.composer = composer()
  }

  /// The session that the view shows now: the session that the user chose, or
  /// the root. A chosen session that the client removed gives way to its
  /// nearest ancestor that is still open, so the view is never empty.
  private var session: SessionModel {
    focus.resolve(in: root)
  }

  /// Shows another session of the tree of the root.
  ///
  /// - Parameter id: The id of the session. An id that the tree does not hold
  ///   changes nothing.
  private func show(_ id: SessionId) {
    guard let found = root.session(withId: id), !found.isClosed else {
      Self.logger.info(
        "A request to show the session \(id.rawValue, privacy: .public) found no open session in the tree."
      )
      return
    }
    focus.choose(found)
  }

  /// The name of the agent, for the paths of the jump list, or `nil`.
  private var agentName: String? {
    (connection ?? hostConnection)?.agentName
  }

  /// The manager of the scroll position that the view uses.
  private var anchors: ScrollAnchorManager {
    hostAnchors ?? anchorStore.anchors(for: session.sessionId)
  }

  public var body: some View {
    content
      // The agent command scope reads neither scope, so it can be inside
      // them.
      .accessibilityReadingScope()
      .accessibilityFocusScope()
      .environment(\.expandedBlocksStore, expandedBlocks)
      .modifier(
        ThreadAttachmentInspector(
          mode: inspectorMode, sessionId: session.sessionId,
          selection: Self.inspectorSelection(
            host: hostInspectorSelection, own: ownInspectorSelection))
      )
      // The thread has one text selection: the transcript, the prompts, the
      // bars and the inspector (Docs/decisions/text-selection.md).
      .threadTextSelection()
  }

  /// The store of the expanded rows that the view gives to its rows: the
  /// store of the environment, or the store of the view.
  private var expandedBlocks: ExpandedBlocksStore {
    hostExpandedBlocks ?? ownExpandedBlocks
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
  /// (D112 (e)). The status line and the banners float over the list: each
  /// is on the floating glass of the kit, in one glass container, so the
  /// text of the list does not show through them (TestudoApp D213). The
  /// header of the host is in the same container with no glass, and its
  /// buttons keep the button styles of content
  /// (`EditorStyle.ButtonSurface.content`). From the top, the
  /// bar shows the header and the connection banner when the host gave the
  /// connection model, the notice banner and the stream banner. VoiceOver
  /// reads the top bar, the list and then the bottom bar.
  private var content: some View {
    VStack(spacing: 0) {
      ThreadTranscriptSlot(message: unavailableMessage) {
        ConversationView(session: session, anchors: anchors)
          .id(session.sessionId)
          // The state banner and the pill are in the floating controls, in
          // the bottom bar with the composer.
          .environment(\.conversationShowsPill, false)
          .environment(\.conversationShowsStateBanner, false)
      }
    }
    .safeAreaBar(edge: .top) {
      // The bar stands the header and the banners one tile margin apart. The
      // parts have no margin of their own (^rgsq3k4), and the bar has no
      // inset of its own: the host gives the inset of the bar where it mounts
      // the view (`\.barInsets`, ^e0wdpmg). With no part there is no stack,
      // so a bar that shows nothing takes no space. The glass of the status
      // line and of the banners is in one container, so it blends where the
      // parts touch (TestudoApp D213). The full frame of the stack, with the
      // gaps between the parts, shows the context menu of the host path
      // (``TopBarContextMenu``, ^z7r9tk).
      Group(subviews: topBarParts) { subviews in
        if !subviews.isEmpty {
          FloatingGlassContainer(spacing: editorStyle.spacing.s) {
            VStack(spacing: editorStyle.tile.margin) { subviews }
              .topBarContextMenu(headerContextMenuPath)
          }
          .padding(barInsets)
        }
      }
    }
    .safeAreaBar(edge: .bottom) { floatingControls }
    .background { SessionAnnouncementObserver(session: session) }
    .background { TranscriptSearchDriver(session: session, search: search, store: expandedBlocks) }
    // In a thread with no message, the composer takes the focus when the
    // thread shows and when its scope gets the focus (Testudo, 2026-11-20).
    .background { EmptyThreadComposerFocus(session: session) }
    .environment(\.transcriptSearch, search)
    // After a resume the view shows the root: a child that needs the user
    // shows through its mark and the jump of the banner.
    .onChange(of: root.replayEndCount) { focus.resumeEnded() }
    .onChange(of: root.sessionId) { focus.resumeEnded() }
    .environment(\.openSession, OpenSessionAction(run: show))
    .agentCommandScope(
      session: session, anchors: anchors,
      navigation: AgentSessionNavigation(show: show, presentJump: { isJumpPresented = true }),
      connection: connection, search: search, isUnavailable: unavailableMessage != nil
    )
    .sheet(isPresented: $isJumpPresented) {
      SessionJumpList(agent: agentName, entries: session.jumpEntries) { id in
        isJumpPresented = false
        show(id)
      }
    }
    .onDisappear(perform: closeWhenSupported)
  }

  /// The parts of the top bar, from the top: the status line when the host
  /// gave the connection model, the header of the host
  /// (``SwiftUI/View/threadHeader(_:)``), then the ``banners``.
  ///
  /// The status line (``ThreadStatusHeader``) and the banners float on the
  /// glass of the kit, in the one container of the top bar. The header of the
  /// host has no glass (D110), and its buttons keep the place of content
  /// (``ThreadHeaderSlot``).
  ///
  /// The top bar shows the context menu of ``headerContextMenuPath`` on the
  /// full frame of the stack of the parts (``TopBarContextMenu``): a right
  /// click on the status line, on the header of the host, on a banner or in
  /// the gap between two parts shows the same menu (D108, ^tsr28g, ^z7r9tk).
  /// A control of a part keeps its own action. With no path, the top bar has
  /// no context menu, and a click in a gap goes to the list.
  @ViewBuilder private var topBarParts: some View {
    if let connection {
      ThreadStatusHeader(
        session: session, connection: connection, sessionTitle: sessionTitle,
        contextMenuPath: headerContextMenuPath, select: show)
    }
    if let threadHeader {
      ThreadHeaderSlot(header: threadHeader)
    }
    banners
  }

  /// The banners of the top bar, from the top: the connection banner when the
  /// host gave the connection model, the notice banner and the stream banner.
  ///
  /// Each banner is a note that floats over the list, so each bar of a banner
  /// is on the floating glass of the kit (``StatusBarPlacement/floating``,
  /// TestudoApp D213).
  @ViewBuilder private var banners: some View {
    Group {
      if let connection {
        AgentConnectionBanner(connection: connection)
      }
      SessionNoticeBanner(session: session)
      UnconfirmedSessionBanner(session: session)
      WaitingDescendantBanner(session: session, jump: show)
      SessionStreamBanner(session: session, connection: connection)
    }
    .statusBarPlacement(.floating)
  }

  /// The content of the bottom bar: the state banner, the login prompt, the
  /// scroll-to-bottom pill and the composer slot, in one glass container
  /// (D110 (c)).
  ///
  /// The list scrolls under the bar (EditorKit `style.md`, "Scroll
  /// under the bars", D113 answer 7). The state banner and the login prompt
  /// are notes that float over the list, so each is on the floating glass of
  /// the kit (``StatusBarPlacement/floating``, TestudoApp D213), and their
  /// buttons stand on that glass with the bordered style (EditorKit
  /// `style.md`, rule 4). The buttons on the glass of a request deck in the
  /// composer slot also use the bordered styles. The placement is on the
  /// banner and the prompt only: a bar on the glass of the deck stays
  /// content, so no glass stands on glass. From the top,
  /// the order is the pill, the banner, the login prompt when the host gave
  /// the connection model, and the composer. VoiceOver reads them in this
  /// order. The pill is an overlay that floats one small spacing above the
  /// stack, over the list. The side cards of ``SwiftUI/View/sideCards(_:)`` float in the
  /// same overlay, under the pill, at the trailing edge (D205). It is not in the layout of the stack, so the height
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
    #if DEBUG
      BodyEvaluationCounter.note(AgentThreadLayout.floatingControlsCounterKey(for: session))
    #endif
    return FloatingGlassContainer(spacing: spacing) {
      VStack(spacing: spacing) {
        Group {
          // The banner reads `agentState` in its own body, so a change of the
          // state evaluates only the banner.
          StateBanner(session: session) { showItem($0.rowKey) }
          if let connection {
            AgentLoginPrompt(session: session, connection: connection)
          }
        }
        .statusBarPlacement(.floating)
        if AgentThreadLayout.showsComposer(for: session, hasHostComposer: hostComposer != nil) {
          composer
            .disabled(!session.canPrompt)
            .modifier(ThreadComposerRouting(route: session.isReadOnly ? hostComposer : nil))
            .environment(\.sessionModel, session)
            .environment(\.connectionModel, connection ?? hostConnection)
        }
      }
      // The pill and the side cards float above the controls and take no
      // space in their layout, so their show and their hide keep the bottom
      // inset of the list and the scroll position.
      .overlay(alignment: .top) {
        VStack(spacing: spacing) {
          if AgentThreadLayout.showsPill(unavailableMessage: unavailableMessage) {
            ConversationPill(anchors: anchors)
          }
          if let sideCards {
            SideCardStack(cards: sideCards)
          }
        }
        .alignmentGuide(.top) { $0[.bottom] + spacing }
      }
    }
    .padding(barInsets)
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
    let closes = connection.map { $0.canCloseSessions && !root.isClosed } ?? false
    reportClose?(closes)
    guard closes, let connection else { return }
    Task { [root] in await Self.close(root, on: connection) }
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

/// The scroll position of each session that a thread view showed, so that a
/// switch to a child and back keeps the place of each. The unsent draft is
/// the draft of the session model, which the model keeps for each session.
@MainActor
final class SessionAnchorStore {
  /// The manager of each session id.
  private var managers: [SessionId: ScrollAnchorManager] = [:]

  /// The manager of a session, made at the first request.
  ///
  /// - Parameter id: The id of the session.
  /// - Returns: The manager.
  func anchors(for id: SessionId) -> ScrollAnchorManager {
    if let existing = managers[id] { return existing }
    let made = ScrollAnchorManager()
    managers[id] = made
    return made
  }
}

/// The action that shows another session of the tree in the nearest
/// ``AgentThreadView`` (``SwiftUI/EnvironmentValues/openSession``).
///
/// The function is in a struct, not in the environment value itself: an
/// environment value that holds a closure can invalidate its dependents on
/// each update.
struct OpenSessionAction {
  /// The function that shows the session with an id.
  let run: @MainActor (SessionId) -> Void

  /// Shows the session with an id.
  ///
  /// - Parameter id: The id of the session.
  func callAsFunction(_ id: SessionId) {
    run(id)
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

  /// The accessibility identifier of the group of the header of the host
  /// (``SwiftUI/View/threadHeader(_:)``) in the top bar of a thread.
  public static let headerIdentifier = "thread-header"

  /// The accessibility identifier of the static text of the unavailable
  /// message of the host (``SwiftUI/View/threadUnavailable(_:)``) in place
  /// of the transcript of a thread.
  public static let unavailableIdentifier = "thread-unavailable"

  /// The prefix of the ``BodyEvaluationCounter`` key of the floating
  /// controls of a thread.
  static let floatingControlsCounterKeyPrefix = "thread-floating-controls-"

  /// The ``BodyEvaluationCounter`` key of the floating controls of a thread
  /// of a session model. The thread notes the key each time that it makes
  /// its floating controls.
  ///
  /// - Parameter session: The session model that the thread shows.
  /// - Returns: The key.
  static func floatingControlsCounterKey(for session: SessionModel) -> String {
    BodyEvaluationKey.make(
      prefix: floatingControlsCounterKeyPrefix, object: session)
  }

  /// Tells if a thread view of `session` shows its composer slot.
  ///
  /// A read-only session (`SessionModel.isReadOnly`, the shared session of
  /// TestudoApp D208 (i)) cannot get a prompt, so the view shows no
  /// composer slot: no composer, no request deck in the slot, and no mode
  /// or model picker of the accessory of the composer. A read-only session
  /// also has no pending request, so a deck next to the view shows no card.
  /// With the composer of the host
  /// (``SwiftUI/View/threadComposer(placeholder:onSubmit:)``, TestudoApp
  /// D212), the view of a read-only session shows its composer slot, and
  /// each prompt goes to the host.
  ///
  /// - Parameters:
  ///   - session: The session that the view shows.
  ///   - hasHostComposer: Whether the host gave its composer.
  /// - Returns: `false` when the session is read-only and the host gave no
  ///   composer.
  static func showsComposer(for session: SessionModel, hasHostComposer: Bool = false) -> Bool {
    !session.isReadOnly || hasHostComposer
  }

  /// Tells if a thread view shows its scroll-to-bottom pill.
  ///
  /// While the view shows the unavailable message of the host in place of
  /// the transcript (``SwiftUI/View/threadUnavailable(_:)``), no list shows,
  /// so the pill has no list to scroll.
  ///
  /// - Parameter message: The unavailable message of the host, or `nil`.
  /// - Returns: `true` when the host gave no message.
  static func showsPill(unavailableMessage message: String?) -> Bool {
    message == nil
  }
}

extension EnvironmentValues {
  /// Shows another session of the tree in the nearest ``AgentThreadView``, or
  /// `nil` outside a thread view. A tool row of an `agents` call uses it to
  /// jump to the child session of the call.
  @Entry var openSession: OpenSessionAction? = nil

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
      .barInsets()
  }
}
