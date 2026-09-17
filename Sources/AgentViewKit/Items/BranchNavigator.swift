import OSLog
import SwiftUI

/// The regenerate and branch paging control of an assistant message
/// (plan.md §9 A).
///
/// Put the control in the footer slot of the message views:
///
/// ```swift
/// AgentThreadView(thread: thread)
///   .messageFooter { message in BranchNavigator(messageID: message.id) }
/// ```
///
/// The control has these parts:
///
/// - A "< 2 / 3 >" pager, when the user message before the message has a
///   ``BranchSet`` and the message is the first assistant message after that
///   user message (``AgentThread/branchUserMessageID(forAssistantMessage:)``).
///   The buttons apply ``ThreadChange/selectBranch(afterUserMessage:index:)``.
/// - A Regenerate button, on the last assistant message of the thread only.
///   The button records the items after the user message as a branch, shows
///   a new empty branch, and sends the input of the user message again
///   through the `threadActions` environment value.
///
/// The control reads the thread from the `agentThread` environment value.
/// With no thread, or with no part to show, the control shows nothing. While
/// the thread runs a turn, the buttons are disabled.
///
/// The kit keeps the branches local (plan.md §9 A). A source does not know
/// that the thread shows a different branch.
public struct BranchNavigator: View {
  /// One part of the control.
  public enum Control: String, CaseIterable, Sendable {
    /// Shows the previous branch.
    case previous
    /// The position of the shown branch, such as "1 / 2".
    case position
    /// Shows the next branch.
    case next
    /// Records the current branch and sends the user input again.
    case regenerate

    /// The accessibility identifier of the part, such as `branch-previous`.
    public var identifier: String {
      "branch-\(rawValue)"
    }
  }

  /// The SF Symbol of the Regenerate button.
  private static let regenerateSymbol = "arrow.trianglehead.2.clockwise"

  /// The identifier of the assistant message of the control.
  internal let messageID: String

  @Environment(\.agentThread) private var thread
  @Environment(\.threadActions) private var actions
  @Environment(\.agentTheme) private var theme

  private let logger = Logger(subsystem: "AgentViewKit", category: "BranchNavigator")

  /// Makes the control of an assistant message.
  ///
  /// - Parameter messageID: The identifier of the assistant message.
  public init(messageID: String) {
    self.messageID = messageID
  }

  public var body: some View {
    if let thread {
      content(in: thread)
    }
  }

  /// The parts of the control that apply to the message in `thread`.
  ///
  /// - Parameter thread: The thread of the message.
  /// - Returns: The parts, or no view when no part applies.
  @ViewBuilder private func content(in thread: AgentThread) -> some View {
    let userID = thread.branchUserMessageID(forAssistantMessage: messageID)
    let set = userID.flatMap { thread.branches[$0] }
    let canRegenerate = Self.isLastAssistantMessage(messageID, in: thread)
    if set != nil || canRegenerate {
      HStack(spacing: theme.spacing.xs) {
        if let userID, let set {
          pager(userID: userID, set: set, in: thread)
        }
        if canRegenerate {
          Button(String(localized: "Regenerate"), systemImage: Self.regenerateSymbol) {
            regenerate(in: thread)
          }
          .help(String(localized: "Regenerate"))
          .accessibilityIdentifier(Control.regenerate.identifier)
        }
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.glass)
      .foregroundStyle(.secondary)
      .disabled(thread.state == .running)
    }
  }

  /// The "< 2 / 3 >" pager of a branch set.
  ///
  /// - Parameters:
  ///   - userID: The identifier of the user message of the set.
  ///   - set: The branch set.
  ///   - thread: The thread of the set.
  /// - Returns: The pager.
  @ViewBuilder private func pager(userID: String, set: BranchSet, in thread: AgentThread)
    -> some View
  {
    Button(String(localized: "Previous Branch"), systemImage: "chevron.left") {
      thread.apply(.selectBranch(afterUserMessage: userID, index: set.selectedIndex - 1))
    }
    .disabled(set.selectedIndex == 0)
    .help(String(localized: "Previous Branch"))
    .accessibilityIdentifier(Control.previous.identifier)
    Text(Self.positionText(of: set))
      .monospacedDigit()
      .accessibilityLabel(Self.positionLabel(of: set))
      .accessibilityIdentifier(Control.position.identifier)
    Button(String(localized: "Next Branch"), systemImage: "chevron.right") {
      thread.apply(.selectBranch(afterUserMessage: userID, index: set.selectedIndex + 1))
    }
    .disabled(set.selectedIndex == set.count - 1)
    .help(String(localized: "Next Branch"))
    .accessibilityIdentifier(Control.next.identifier)
  }

  /// The visible position of the shown branch.
  ///
  /// - Parameter set: The branch set.
  /// - Returns: The one-based position and the count, such as "1 / 2".
  internal static func positionText(of set: BranchSet) -> String {
    "\(set.selectedIndex + 1) / \(set.count)"
  }

  /// The spoken position of the shown branch.
  ///
  /// - Parameter set: The branch set.
  /// - Returns: The one-based position and the count, such as
  ///   "Branch 1 of 2".
  private static func positionLabel(of set: BranchSet) -> String {
    String(localized: "Branch \(set.selectedIndex + 1) of \(set.count)")
  }

  /// Tells if the message is the last assistant message of the thread.
  ///
  /// - Parameters:
  ///   - id: The identifier of the message.
  ///   - thread: The thread.
  /// - Returns: `true` when no assistant message follows the message.
  private static func isLastAssistantMessage(_ id: String, in thread: AgentThread) -> Bool {
    let last = thread.items.last { item in
      if case .assistantMessage = item { return true }
      return false
    }
    return last?.id == id
  }

  /// Records the items after the user message before the message as a
  /// branch, and shows a new empty branch.
  ///
  /// - Parameters:
  ///   - id: The identifier of the assistant message.
  ///   - thread: The thread of the message.
  /// - Returns: The input of the user message, or `nil` when no user message
  ///   is before the message.
  internal static func startBranch(after id: String, in thread: AgentThread) -> UserInput? {
    guard let user = MessageActions.lastUserMessage(before: id, in: thread) else { return nil }
    thread.apply(.addBranch(afterUserMessage: user.id, items: []))
    if let count = thread.branches[user.id]?.count {
      thread.apply(.selectBranch(afterUserMessage: user.id, index: count - 1))
    }
    return MessageActions.input(of: user)
  }

  /// Starts a new branch and sends the user input again.
  ///
  /// - Parameter thread: The thread of the message.
  private func regenerate(in thread: AgentThread) {
    guard let input = Self.startBranch(after: messageID, in: thread) else {
      logger.error("Regenerate found no user message before \(messageID, privacy: .private).")
      return
    }
    actions.startSend(input)
  }
}
