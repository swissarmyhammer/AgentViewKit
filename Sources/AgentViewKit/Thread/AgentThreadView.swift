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
/// Above the conversation, a ``SessionNoticeBanner`` shows one banner for
/// each notice of the session model, and a ``SessionStreamBanner`` shows the
/// stream state: the replay marker, the partial-history note, the
/// missed-updates banner with its Reload button, and the closed state. Below
/// the conversation, a ``StateBanner`` shows the agent state. Each banner
/// view, and not this view, reads its part of the model.
///
/// Below the conversation, the floating controls of the thread show the
/// composer slot, directly below its chat (D36). The default slot is a
/// ``DefaultThreadComposer``: a ``PromptInputView`` that keeps its own text.
/// Give a custom composer with ``init(session:connection:composer:)``, or
/// `EmptyView()` for no composer. The scroll-to-bottom pill
/// (``ScrollToBottomPill``) shows above the composer, and the pill and the
/// slot are in one `GlassEffectContainer`, with no glass on glass (D110 (c)).
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
/// agent from its `initialize` answer, an ``AgentConnectionBanner`` shows the
/// connection state, and an ``AgentAuthView`` shows below the conversation
/// while the last entry of the transcript is an error entry with the code
/// `-32000` (authentication required).
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
/// A tap on an attachment in a row shows the file in a trailing inspector.
/// See ``SwiftUI/View/attachmentInspector(selection:)``. When the environment
/// has an ``InspectorSelection``, the view uses that selection. The view
/// always has this inspector, so do not put the view in a view that has its
/// own `inspector(isPresented:content:)`, such as a `NavigationSplitView`
/// with an inspector. Two inspectors make the minimum width of the column
/// equal to the width of the window, and AppKit can then stop the app.
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
  @Environment(\.connectionModel) private var hostConnection
  @Environment(\.agentTheme) private var theme

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
  /// See ``init(session:connection:)`` for the close of the session and the
  /// Reload button.
  ///
  /// - Parameters:
  ///   - session: The session model whose transcript the view shows.
  ///   - connection: The connection model that opened the session, or `nil`
  ///     when the host closes the session itself.
  ///   - composer: The builder of the view in the composer slot, such as a
  ///     ``PromptInputView``.
  public init(
    session: SessionModel, connection: ConnectionModel? = nil,
    @ViewBuilder composer: () -> Composer
  ) {
    self.init(session: session, connection: connection, anchors: nil, composer: composer)
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
  ///   - composer: The builder of the view in the composer slot.
  init(
    session: SessionModel, connection: ConnectionModel? = nil, anchors: ScrollAnchorManager?,
    @ViewBuilder composer: () -> Composer
  ) {
    self.session = session
    self.connection = connection
    self.hostAnchors = anchors
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
      .attachmentInspector(
        selection: Self.inspectorSelection(host: hostInspectorSelection, own: ownInspectorSelection))
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

  /// The conversation of the session model, with the parts that read the
  /// model, and the floating controls below it.
  private var content: some View {
    VStack(spacing: 0) {
      if let connection {
        AgentInfoHeader(connection: connection)
        AgentConnectionBanner(connection: connection)
      }
      SessionNoticeBanner(session: session)
      SessionStreamBanner(session: session, connection: connection)
      ConversationView(session: session, anchors: anchors)
        // The pill is in the floating controls, in one container with the
        // composer.
        .environment(\.conversationShowsPill, false)
      if let connection {
        AgentLoginPrompt(session: session, connection: connection)
      }
    }
    .safeAreaBar(edge: .bottom) { floatingControls }
    .background { SessionAnnouncementObserver(session: session) }
    .agentCommandScope(session: session, anchors: anchors)
    .onDisappear(perform: closeWhenSupported)
  }

  /// The scroll-to-bottom pill and the composer slot, in one glass container
  /// (D110 (c)).
  ///
  /// The pill is above the composer. A composer in the slot that makes its
  /// own container, such as ``PromptInputView``, uses this container. The
  /// controls are one accessibility container with
  /// ``AgentThreadLayout/floatingControlsIdentifier``.
  private var floatingControls: some View {
    FloatingGlassContainer(spacing: theme.spacing.s) {
      VStack(spacing: theme.spacing.s) {
        ConversationPill(anchors: anchors)
        composer
          .environment(\.sessionModel, session)
          .environment(\.connectionModel, connection ?? hostConnection)
      }
    }
    .padding(theme.spacing.m)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(AgentThreadLayout.floatingControlsIdentifier)
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
  /// scroll-to-bottom pill and the composer slot, in one glass container.
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
