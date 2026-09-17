import SwiftUI

/// The fixed values and the pure functions of the thread accessibility
/// (plan.md §6, research R11).
///
/// - Reading groups: each paragraph of a message is in the linked group of
///   the message, and each row of a conversation is in the linked group of
///   the thread. VoiceOver then reads across the rows. The namespace of the
///   groups comes from ``SwiftUI/View/accessibilityReadingScope()``.
/// - Announcements: the kit announces only at three boundaries: turn
///   complete, tool result, and action required. A streaming chunk is not a
///   boundary.
/// - Focus: see ``AccessibilityFocusMover``.
public enum ThreadAccessibility {
  /// The id of the linked group of the rows of a thread.
  public static let threadGroupID = "agent-thread"

  // MARK: - Announcements

  /// The announcement when a turn stops.
  ///
  /// - Parameters:
  ///   - old: The state before the change.
  ///   - new: The state after the change.
  /// - Returns: The text, or `nil` when the change does not stop a turn. A
  ///   turn stops when the state goes from running or requires action to
  ///   idle. A stop reason with a ``StateBanner`` gives the banner title.
  public static func turnAnnouncement(old: ThreadState, new: ThreadState) -> String? {
    guard case .idle(let reason) = new else { return nil }
    if case .idle = old { return nil }
    if let banner = StateBanner.message(for: new) {
      return banner.title
    }
    if reason == .cancelled {
      return String(localized: "Response cancelled")
    }
    return String(localized: "Response complete")
  }

  /// The progress of one tool call, for the tool result announcement.
  public struct ToolCallProgress: Equatable, Sendable {
    /// The identifier of the record.
    public let id: String
    /// The title of the call.
    public let title: String
    /// The progress of the call.
    public let status: ToolCallStatus

    /// Makes the progress of a call.
    ///
    /// - Parameters:
    ///   - id: The identifier of the record.
    ///   - title: The title of the call.
    ///   - status: The progress of the call.
    public init(id: String, title: String, status: ToolCallStatus) {
      self.id = id
      self.title = title
      self.status = status
    }
  }

  /// The progress of each tool call in `items`, in item order.
  ///
  /// A view that calls this function observes the items and the title and
  /// status of each tool call record.
  ///
  /// - Parameter items: The items of a thread.
  /// - Returns: One value for each tool call item.
  public static func toolCallProgress(in items: [ThreadItem]) -> [ToolCallProgress] {
    items.compactMap { item in
      guard case .toolCall(let record) = item else { return nil }
      return ToolCallProgress(id: record.id, title: record.title, status: record.status)
    }
  }

  /// Tells if a call with `status` has its result.
  ///
  /// - Parameter status: The progress of a call.
  /// - Returns: `true` for completed, failed, cancelled, and lost calls.
  static func hasResult(_ status: ToolCallStatus) -> Bool {
    switch status {
    case .completed, .failed, .cancelled, .lost: true
    case .pending, .inProgress, .unknown: false
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

  /// The summary of each pending request of `thread`, in the order of the
  /// cards of ``PendingRequestsHost``.
  ///
  /// - Parameter thread: The thread.
  /// - Returns: The permission title, the elicitation message, or the
  ///   server name of each request.
  public static func pendingRequests(of thread: AgentThread) -> [PendingRequestSummary] {
    thread.pendingPermissions.map { PendingRequestSummary(id: $0.id.rawValue, title: $0.title) }
      + thread.pendingElicitations.map {
        PendingRequestSummary(id: $0.id.rawValue, title: $0.message)
      }
      + thread.pendingAuthorizations.map {
        PendingRequestSummary(
          id: $0.id.rawValue, title: String(localized: "Connect \($0.serverName)"))
      }
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
/// boundaries of a thread.
///
/// The view reads the state, the tool call progress, and the pending
/// requests of the thread. It does not read ``AgentThread/streaming``, so a
/// chunk does not evaluate its body.
struct ThreadAnnouncementObserver: View {
  /// The thread to observe.
  let thread: AgentThread

  @Environment(\.announcer) private var announcer

  var body: some View {
    Color.clear
      .accessibilityHidden(true)
      .onChange(of: thread.state) { old, new in
        if let text = ThreadAccessibility.turnAnnouncement(old: old, new: new) {
          announcer.announce(text, priority: .medium)
        }
      }
      .onChange(of: ThreadAccessibility.toolCallProgress(in: thread.items)) { old, new in
        for text in ThreadAccessibility.toolResultAnnouncements(old: old, new: new) {
          announcer.announce(text, priority: .medium)
        }
      }
      .onChange(of: ThreadAccessibility.pendingRequests(of: thread)) { old, new in
        for text in ThreadAccessibility.actionRequiredAnnouncements(old: old, new: new) {
          announcer.announce(text, priority: .high)
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
