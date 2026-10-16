// Scoped imports: the whole module also has a `Content` type, which hides the
// `Content` of each `ViewModifier` in this file.
import struct FoundationModelsACP.IdleStateUpdate
import struct FoundationModelsACP.MessageId
import enum FoundationModelsACP.SessionUpdate
import enum FoundationModelsACP.ToolCallStatus
import FoundationModelsACPClient
import SwiftUI

/// The fixed values and the pure functions of the thread accessibility
/// (plan.md §6, research R11).
///
/// - Reading groups: each paragraph of a message is in the linked group of
///   the message, and each row of a conversation is in the linked group of
///   the thread. VoiceOver then reads across the rows. The namespace of the
///   groups comes from ``SwiftUI/View/accessibilityReadingScope()``.
/// - Announcements: the kit announces only at three boundaries: the end of
///   the work of a prompt of this client, tool result, and action required.
///   A streaming chunk is not a boundary.
/// - Focus: see ``AccessibilityFocusMover``.
public enum ThreadAccessibility {
  /// The id of the linked group of the rows of a thread.
  public static let threadGroupID = "agent-thread"

  // MARK: - Announcements

  /// The announcement of the end of the work of a prompt with no stop reason
  /// to report, or with `end_turn`.
  private static var responseCompleteText: String {
    String(localized: "Response complete")
  }

  /// The announcement of the end of the work of a prompt with `cancelled`.
  private static var responseCancelledText: String {
    String(localized: "Response cancelled")
  }

  /// The announcement of the idle that ends the work of a prompt.
  ///
  /// ``makeTurnAnnouncements(of:)`` finds the idle that ends the work of a
  /// prompt of this client. This function gives only the text of that idle.
  ///
  /// - Parameter idle: The idle state that ends the work of a prompt.
  /// - Returns: "Response complete" for no stop reason and for `end_turn`,
  ///   "Response cancelled" for `cancelled`, and the title of the
  ///   ``StateBanner`` of each other stop reason.
  public static func turnAnnouncement(for idle: IdleStateUpdate) -> String {
    switch idle.stopReason {
    case nil, .endTurn: responseCompleteText
    case .cancelled: responseCancelledText
    case .maxTokens, .maxTurnRequests, .refusal, .error, .unknown:
      StateBanner.message(for: .idle(idle)).title
    }
  }

  /// The announcements of the idles that end the work of the prompts that
  /// this client sent to `session`.
  ///
  /// A prompt is mail. The agent answers `session/prompt` when it accepts
  /// the message, and gives the message id of the user message. The agent
  /// then echoes that user message with the same message id, and works. The
  /// first idle after the echo ends the work of the prompt
  /// (`SessionModel.prompt(_:meta:)`). Thus the stream gives a text only for
  /// the first idle after the echo of a prompt of this client:
  ///
  /// - An idle after background work only gives no text.
  /// - A later idle with no new prompt gives no text.
  /// - One idle that ends the work of two open prompts gives one text.
  /// - While `SessionModel.isReplaying` is true, the history replay of a
  ///   `session/resume` request gives no text.
  ///
  /// The stream reads `SessionModel.updateTap()`, which gives each update
  /// in arrival order. The tap starts when this function returns, so make
  /// the stream before the prompt goes out. The stream ends when the tap
  /// ends, for example when the session model closes.
  ///
  /// - Parameter session: The session model.
  /// - Returns: The text of each idle that ends the work of a prompt of
  ///   this client, as ``turnAnnouncement(for:)`` gives it, in order.
  public static func makeTurnAnnouncements(of session: SessionModel) -> AsyncStream<String> {
    makeTurnAnnouncements(of: session, report: nil)
  }

  /// The announcements of ``makeTurnAnnouncements(of:)``, and a report of
  /// each step of the reader.
  ///
  /// The reader calls `report` with ``TurnAnnouncementStep/started`` when
  /// the tap starts, and with ``TurnAnnouncementStep/handled(_:announcement:)``
  /// in the same step as it handles an update. Thus a test can wait for the
  /// event that the reader handled an update, and then check that no
  /// announcement came.
  ///
  /// - Parameters:
  ///   - session: The session model.
  ///   - report: The internal observation point for the tests, or `nil`.
  /// - Returns: The text of each idle that ends the work of a prompt of
  ///   this client, in order.
  static func makeTurnAnnouncements(
    of session: SessionModel, report: ObservationReport<TurnAnnouncementStep>?
  ) -> AsyncStream<String> {
    let updates = session.updateTap()
    report?(.started)
    let (announcements, continuation) = AsyncStream<String>.makeStream()
    let reader = Task { [weak session] in
      var tracker = PromptEndTracker()
      for await update in updates {
        guard let session else { continue }
        let text =
          session.isReplaying
          ? nil : tracker.receive(update, sentPromptIDs: sentPromptIDs(in: session.transcript))
        report?(.handled(update, announcement: text))
        if let text {
          continuation.yield(text)
        }
      }
      continuation.finish()
    }
    continuation.onTermination = { _ in reader.cancel() }
    return announcements
  }

  /// The message ids of the prompts that this client sent: the local user
  /// messages that the agent linked to a message id.
  ///
  /// - Parameter transcript: The transcript of a session model.
  /// - Returns: The message id of each local user message that has one.
  static func sentPromptIDs(in transcript: [TranscriptEntry]) -> Set<MessageId> {
    Set(
      transcript.compactMap { entry in
        guard case .userMessage(let message) = entry, message.origin == .local else { return nil }
        return message.messageId
      })
  }

  /// The progress of one tool call, for the tool result announcement.
  public struct ToolCallProgress: Equatable, Sendable {
    /// The text identity of the call: the row key of the transcript entry.
    public let id: String
    /// The title of the call.
    public let title: String
    /// The ACP progress of the call.
    public let status: FoundationModelsACP.ToolCallStatus

    /// Makes the progress of a call.
    ///
    /// - Parameters:
    ///   - id: The text identity of the call.
    ///   - title: The title of the call.
    ///   - status: The ACP progress of the call.
    public init(id: String, title: String, status: FoundationModelsACP.ToolCallStatus) {
      self.id = id
      self.title = title
      self.status = status
    }
  }

  /// The progress of each `ToolCallEntry` of `transcript`, in transcript
  /// order.
  ///
  /// A view that calls this function observes the transcript and the title
  /// and status of each tool call entry. The value is only for the
  /// comparison of one change. The view keeps no copy of it.
  ///
  /// - Parameter transcript: The transcript of a session model.
  /// - Returns: One value for each tool call entry, with the row key of the
  ///   entry as its identity.
  public static func toolCallProgress(in transcript: [TranscriptEntry]) -> [ToolCallProgress] {
    transcript.compactMap(\.toolCall).map {
      ToolCallProgress(id: $0.id.rowKey, title: $0.shownTitle, status: $0.shownStatus)
    }
  }

  /// Tells if a call with `status` has its result.
  ///
  /// - Parameter status: The ACP progress of a call.
  /// - Returns: `true` for completed, failed and cancelled calls, and for the
  ///   kit extension status of a lost call.
  static func hasResult(_ status: FoundationModelsACP.ToolCallStatus) -> Bool {
    switch status {
    case .completed, .failed, .cancelled: true
    case .unknown(let wireValue): wireValue == ToolStatusSymbol.lostWireValue
    case .pending, .inProgress: false
    }
  }

  /// The announcements of the tool calls that got their result.
  ///
  /// A call that the thread did not know before the change gives no
  /// announcement. Thus a thread that loads its history is silent.
  ///
  /// - Parameters:
  ///   - old: The progress of the calls before the change.
  ///   - new: The progress of the calls after the change.
  /// - Returns: "<title>, <status>" for each call whose result is new, in
  ///   item order.
  public static func toolResultAnnouncements(
    old: [ToolCallProgress], new: [ToolCallProgress]
  ) -> [String] {
    let oldStatus = Dictionary(old.map { ($0.id, $0.status) }, uniquingKeysWith: { _, last in last })
    return new.compactMap { call in
      guard let before = oldStatus[call.id], !hasResult(before), hasResult(call.status) else {
        return nil
      }
      return ToolCallView.accessibilityLabel(title: call.title, status: call.status)
    }
  }

  /// One pending request, for the action required announcement.
  public struct PendingRequestSummary: Equatable, Sendable {
    /// The raw identifier of the request.
    public let id: String
    /// The text that tells what the request is about.
    public let title: String

    /// Makes the summary of a request.
    ///
    /// - Parameters:
    ///   - id: The raw identifier of the request.
    ///   - title: The text that tells what the request is about.
    public init(id: String, title: String) {
      self.id = id
      self.title = title
    }
  }

  /// The summary of each pending request of a session model and of its
  /// connection model.
  ///
  /// The order is the order of the cards: the `pendingPermissions` of the
  /// session, then its `pendingElicitations`, then the request-scoped
  /// `pendingElicitations` of the connection. An elicitation of a mode that
  /// has no card (``PendingRequestsHost``) gives no summary. The value is
  /// only for the comparison of one change. The view keeps no copy of it.
  ///
  /// - Parameters:
  ///   - session: The session model.
  ///   - connection: The connection model of the session, or `nil`.
  /// - Returns: The permission title or the elicitation message of each
  ///   request, with the local id of the request as its identity.
  public static func pendingRequests(
    of session: SessionModel, connection: ConnectionModel?
  ) -> [PendingRequestSummary] {
    let elicitations = (session.pendingElicitations + (connection?.pendingElicitations ?? []))
      .filter(ElicitationCard.hasCard(for:))
    let permissions = session.pendingPermissions.map {
      PendingRequestSummary(id: $0.id.uuidString, title: $0.request.title)
    }
    let requests = elicitations.map { PendingRequestSummary(id: $0.id.uuidString, title: $0.request.message) }
    return permissions + requests
  }

  /// The announcements of the requests that are new.
  ///
  /// - Parameters:
  ///   - old: The pending requests before the change.
  ///   - new: The pending requests after the change.
  /// - Returns: "Action required: <title>" for each new request, in card
  ///   order.
  public static func actionRequiredAnnouncements(
    old: [PendingRequestSummary], new: [PendingRequestSummary]
  ) -> [String] {
    let oldIDs = Set(old.map(\.id))
    return new.filter { !oldIDs.contains($0.id) }.map {
      String(localized: "Action required: \($0.title)")
    }
  }
}

/// Finds the idle that ends the work of the prompts of this client
/// (elicitation-plan.md task 48).
///
/// The tracker keeps the message ids of the user-message echoes since the
/// last idle. Each idle removes them. An idle gives a text only when one of
/// them is the message id of a prompt of this client. Thus only the first
/// idle after the echo of such a prompt gives a text, and it gives one text
/// for all the prompts that it ends.
///
/// The tracker matches the echo and the prompt only by the message id. A
/// prompt of this client whose echo never arrives gives no text. The schema
/// requires the message id on the prompt response and on the echo, so an
/// echo with no message id cannot occur.
struct PromptEndTracker {
  /// The message ids of the user-message echoes since the last idle.
  private var echoedMessageIDs: Set<MessageId> = []

  /// Receives one raw session update, in arrival order.
  ///
  /// - Parameters:
  ///   - update: The update.
  ///   - sentPromptIDs: The message ids of the prompts of this client. The
  ///     tracker reads them only at an idle that comes after an echo.
  /// - Returns: The text of ``ThreadAccessibility/turnAnnouncement(for:)``
  ///   when the update is the first idle after the echo of a prompt of this
  ///   client, or `nil`.
  mutating func receive(_ update: SessionUpdate, sentPromptIDs: @autoclosure () -> Set<MessageId>) -> String? {
    if let messageID = Self.echoedMessageID(of: update) {
      echoedMessageIDs.insert(messageID)
      return nil
    }
    guard case .stateUpdate(.idle(let idle)) = update, !echoedMessageIDs.isEmpty else { return nil }
    let echoed = echoedMessageIDs
    echoedMessageIDs.removeAll()
    guard !echoed.isDisjoint(with: sentPromptIDs()) else { return nil }
    return ThreadAccessibility.turnAnnouncement(for: idle)
  }

  /// The message id of a user-message echo.
  ///
  /// - Parameter update: A session update.
  /// - Returns: The message id of a `user_message` or a `user_message_chunk`
  ///   update, or `nil` for each other update.
  private static func echoedMessageID(of update: SessionUpdate) -> MessageId? {
    if case .userMessage(let message) = update { return message.messageId }
    if case .userMessageChunk(let chunk) = update { return chunk.messageId }
    return nil
  }
}

// MARK: - Reading groups

extension EnvironmentValues {
  /// The namespace of the linked reading groups, or `nil` outside a
  /// reading scope.
  @Entry var accessibilityReadingNamespace: Namespace.ID? = nil

  /// The id of the linked group of the message that holds this subtree, or
  /// `nil` outside a message.
  @Entry var accessibilityMessageGroupID: String? = nil
}

extension View {
  /// Gives a namespace for linked reading groups to this subtree, when the
  /// environment has none.
  ///
  /// ``AgentThreadView`` applies this modifier, so that all the groups of a
  /// thread share one namespace. Apply it to a view that shows messages
  /// outside an ``AgentThreadView``.
  ///
  /// - Returns: A view whose subtree has a reading namespace.
  public func accessibilityReadingScope() -> some View {
    modifier(ReadingScopeModifier())
  }

  /// Puts this element in the linked reading group `id` of the scope.
  ///
  /// Outside a reading scope, the modifier does nothing.
  ///
  /// - Parameter id: The id of the group.
  /// - Returns: A view in the group.
  func accessibilityReadingGroup(_ id: String?) -> some View {
    modifier(ReadingGroupModifier(id: id))
  }
}

/// Gives a namespace to the subtree when the environment has none.
private struct ReadingScopeModifier: ViewModifier {
  /// The namespace that the modifier gives when the environment has none.
  @Namespace private var ownNamespace

  @Environment(\.accessibilityReadingNamespace) private var hostNamespace

  func body(content: Content) -> some View {
    content.environment(\.accessibilityReadingNamespace, hostNamespace ?? ownNamespace)
  }
}

/// Puts the element in a linked group of the reading namespace.
private struct ReadingGroupModifier: ViewModifier {
  /// The id of the group, or `nil` for no group.
  let id: String?

  @Environment(\.accessibilityReadingNamespace) private var namespace

  func body(content: Content) -> some View {
    if let id, let namespace {
      content.accessibilityLinkedGroup(id: id, in: namespace)
    } else {
      content
    }
  }
}

// MARK: - Announcements

/// The view that tells the ``SwiftUI/EnvironmentValues/announcer`` about the
/// boundaries of a session model (plan.md §3.2).
///
/// The view keeps no state of its own. It announces these boundaries:
///
/// - The first idle after the echo of a prompt of this client announces the
///   end of the work of the prompt, with the stop reason of the idle
///   (``ThreadAccessibility/makeTurnAnnouncements(of:)``). An idle after
///   background work only, and a later idle with no new prompt, announce
///   nothing. One idle that ends two open prompts announces one time. The
///   view reads these from `SessionModel.updateTap()`, in arrival order,
///   because the model state does not tell when the echo arrived.
///
/// The other announcements react to one change of an observable model
/// value, and compare only the old and the new value that `onChange` gives:
///
/// - A change of the `status` of a `ToolCallEntry` of
///   `SessionModel.transcript` to a result announces the `title` and the
///   status.
/// - While `SessionModel.isReplaying` is true, the history replay of a
///   `session/resume` request makes no tool result announcement.
/// - A new request in `SessionModel.pendingPermissions`,
///   `SessionModel.pendingElicitations`, or
///   `ConnectionModel.pendingElicitations` announces that an action is
///   required, with high priority.
///
/// A streamed chunk changes only the content of its entry, which the view
/// does not read, so a chunk does not evaluate its body.
struct SessionAnnouncementObserver: View {
  /// The session model to observe.
  let session: SessionModel

  /// The connection model of the session, whose request-scoped
  /// elicitations the view observes, or `nil`.
  let connection: ConnectionModel?

  @Environment(\.announcer) private var announcer
  @Environment(\.turnAnnouncementReport) private var reportTurnStep

  var body: some View {
    Color.clear
      .accessibilityHidden(true)
      .task(id: ObjectIdentifier(session)) {
        for await text in ThreadAccessibility.makeTurnAnnouncements(of: session, report: reportTurnStep) {
          announcer.announce(text, priority: .medium)
        }
      }
      .announcing(
        changesOf: ThreadAccessibility.toolCallProgress(in: session.transcript), to: announcer, priority: .medium
      ) { old, new in
        session.isReplaying ? [] : ThreadAccessibility.toolResultAnnouncements(old: old, new: new)
      }
      .announcing(
        changesOf: ThreadAccessibility.pendingRequests(of: session, connection: connection), to: announcer,
        priority: .high, texts: ThreadAccessibility.actionRequiredAnnouncements(old:new:))
  }
}

/// One step of the reader of the announcements of the end of the work of a
/// prompt
/// (``ThreadAccessibility/makeTurnAnnouncements(of:report:)``).
///
/// The reader reports each step through
/// ``SwiftUI/EnvironmentValues/turnAnnouncementReport``. A test reads the
/// report to learn that the reader handled an update, and that it gave no
/// announcement for it.
enum TurnAnnouncementStep {
  /// The reader started to read the update tap of the session model.
  case started

  /// The reader handled `update`, and gave `announcement`, or `nil` for no
  /// announcement.
  case handled(SessionUpdate, announcement: String?)
}

extension EnvironmentValues {
  /// The ``ObservationReport`` that gets each ``TurnAnnouncementStep`` of the
  /// nearest ``SessionAnnouncementObserver``, or `nil`.
  ///
  /// The reader calls the report in the same step as it handles an update.
  @Entry var turnAnnouncementReport: ObservationReport<TurnAnnouncementStep>? = nil
}

extension View {
  /// Tells `announcer` the texts that each change of `value` gives.
  ///
  /// - Parameters:
  ///   - value: The observed value. The modifier keeps no copy of it:
  ///     `onChange` gives the old and the new value of each change.
  ///   - announcer: The announcer that speaks the texts.
  ///   - priority: The priority of each text.
  ///   - texts: The texts of one change, from the old and the new value.
  /// - Returns: A view that announces the changes of `value`.
  fileprivate func announcing<Value: Equatable>(
    changesOf value: Value,
    to announcer: any Announcer,
    priority: AnnouncementPriority,
    texts: @escaping (Value, Value) -> [String]
  ) -> some View {
    onChange(of: value) { old, new in
      for text in texts(old, new) {
        announcer.announce(text, priority: priority)
      }
    }
  }
}

// MARK: - Focus

/// The default focus reporter: it moves the VoiceOver focus
/// (plan.md §6).
///
/// Each view that can take the focus applies
/// ``SwiftUI/View/accessibilityFocusTarget(_:)``. That modifier keeps an
/// `@AccessibilityFocusState` and sets it when ``focusMoved(to:)`` names its
/// identifier. ``AgentThreadView`` gives a mover to its subtree through
/// ``SwiftUI/View/accessibilityFocusScope()``. The views of the kit tell the
/// mover and the ``SwiftUI/EnvironmentValues/focusReporter`` of the host.
@Observable
public final class AccessibilityFocusMover: FocusReporter {
  /// One focus move.
  public struct Move: Equatable, Sendable {
    /// The accessibility identifier of the view that gets the focus.
    public let identifier: String
    /// The count of moves, so that two moves to one view are different.
    public let serial: Int
  }

  /// The last move, or `nil` before the first move.
  public private(set) var lastMove: Move?

  /// Makes a mover with no move.
  public init() {}

  /// Moves the focus to the view with `identifier`.
  ///
  /// - Parameter identifier: The accessibility identifier of the view.
  public func focusMoved(to identifier: String) {
    lastMove = Move(identifier: identifier, serial: (lastMove?.serial ?? 0) + 1)
  }
}

extension EnvironmentValues {
  /// The mover of the VoiceOver focus, or `nil` outside a focus scope.
  @Entry public var accessibilityFocusMover: AccessibilityFocusMover? = nil
}

extension View {
  /// Gives an ``AccessibilityFocusMover`` to this subtree, when the
  /// environment has none.
  ///
  /// ``AgentThreadView`` applies this modifier. When the composer is not in
  /// the thread view, apply the modifier to a view that holds both, so that
  /// the focus goes back to the composer.
  ///
  /// - Returns: A view whose subtree has a focus mover.
  public func accessibilityFocusScope() -> some View {
    modifier(FocusScopeModifier())
  }

  /// Lets the ``AccessibilityFocusMover`` of the environment move the
  /// VoiceOver focus to this view.
  ///
  /// - Parameter identifier: The identifier that a move names to focus this
  ///   view.
  /// - Returns: A view that takes the VoiceOver focus on a move to
  ///   `identifier`.
  public func accessibilityFocusTarget(_ identifier: String) -> some View {
    modifier(FocusTargetModifier(identifier: identifier))
  }
}

/// Gives a mover to the subtree when the environment has none.
private struct FocusScopeModifier: ViewModifier {
  /// The mover that the modifier gives when the environment has none.
  @State private var ownMover = AccessibilityFocusMover()

  @Environment(\.accessibilityFocusMover) private var hostMover

  func body(content: Content) -> some View {
    content.environment(\.accessibilityFocusMover, hostMover ?? ownMover)
  }
}

/// Sets the VoiceOver focus of the view when the mover names it.
private struct FocusTargetModifier: ViewModifier {
  /// The identifier that a move names to focus this view.
  let identifier: String

  @AccessibilityFocusState private var isFocused: Bool

  @Environment(\.accessibilityFocusMover) private var mover

  func body(content: Content) -> some View {
    content
      .accessibilityFocused($isFocused)
      .onChange(of: mover?.lastMove, initial: true) { _, move in
        if move?.identifier == identifier {
          isFocused = true
        }
      }
  }
}

/// The action that tells the focus mover and the focus reporter of the
/// environment about a focus move.
///
/// Keep an instance as a stored property of a view, and call it with the
/// identifier of the view that gets the focus.
struct AccessibilityFocusMove: DynamicProperty {
  @Environment(\.accessibilityFocusMover) private var mover
  @Environment(\.focusReporter) private var reporter

  /// Tells the mover and the reporter that the focus moves to `identifier`.
  ///
  /// - Parameter identifier: The accessibility identifier of the view.
  func callAsFunction(to identifier: String) {
    mover?.focusMoved(to: identifier)
    reporter?.focusMoved(to: identifier)
  }
}
