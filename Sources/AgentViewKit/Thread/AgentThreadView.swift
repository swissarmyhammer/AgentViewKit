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
/// The view shows no card for a pending permission request or a pending
/// elicitation of the session. Put a ``RequestDeck`` next to the view, and
/// put the thread view, the deck and the prompt editor in one
/// ``SwiftUI/View/accessibilityFocusScope()``. The ``RequestDeck``
/// documentation shows the full example.
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
public struct AgentThreadView: View {
  /// The session model whose transcript the view shows.
  let session: SessionModel

  /// The connection model that closes the session when the view goes away,
  /// and that the Reload button of the missed-updates banner resumes the
  /// session on, or `nil`.
  let connection: ConnectionModel?

  /// The store that the view makes when the environment has none.
  @State private var ownExpandedBlocks = ExpandedBlocksStore()

  /// The inspector selection that the view makes when the environment has
  /// none.
  @State private var ownInspectorSelection = InspectorSelection()

  /// The scroll anchors of the list. The agent commands use them to jump
  /// and to scroll.
  @State private var anchors = ScrollAnchorManager()

  @Environment(\.expandedBlocksStore) private var hostExpandedBlocks
  @Environment(\.inspectorSelection) private var hostInspectorSelection

  /// The report that gets the close decision of the view when it goes away,
  /// or `nil`.
  @Environment(\.threadCloseReport) private var reportClose

  /// Makes the view of the transcript of a session model.
  ///
  /// When the host gives the connection model of the session, the view
  /// closes the session when the view goes away (plan.md §3.8 "Close"): it
  /// calls `ConnectionModel.close(_:)` when `canCloseSessions` is true and
  /// the session is not closed. A close that fails adds an error entry to
  /// the transcript of the session.
  ///
  /// With the connection model, the missed-updates banner of
  /// ``SessionStreamBanner`` also shows its Reload button. The button
  /// resumes the session with the `cwd` and the additional directories of
  /// the session model.
  ///
  /// - Parameters:
  ///   - session: The session model whose transcript the view shows.
  ///   - connection: The connection model that opened the session, or `nil`
  ///     when the host closes the session itself.
  public init(session: SessionModel, connection: ConnectionModel? = nil) {
    self.session = session
    self.connection = connection
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
  /// model.
  private var content: some View {
    VStack(spacing: 0) {
      if let connection {
        AgentInfoHeader(connection: connection)
        AgentConnectionBanner(connection: connection)
      }
      SessionNoticeBanner(session: session)
      SessionStreamBanner(session: session, connection: connection)
      ConversationView(session: session, anchors: anchors)
      if let connection {
        AgentLoginPrompt(session: session, connection: connection)
      }
    }
    .background { SessionAnnouncementObserver(session: session) }
    .agentCommandScope(session: session, anchors: anchors)
    .onDisappear(perform: closeWhenSupported)
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
