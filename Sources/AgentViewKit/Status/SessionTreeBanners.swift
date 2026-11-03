import EditorStyle
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The banner that tells that a session below the shown one needs the user.
///
/// The body reads the descendants of the session directly, and keeps no copy.
/// While a descendant at any level waits for an answer, the banner names it
/// by its path, such as "Agent > Reviewer > Linter", and its button jumps to
/// it through `jump`. The banner shows nothing when no descendant needs the
/// user, and it shows nothing for work of the replay phase: the client counts
/// that as history.
///
/// The text has the identifier ``identifier``, and the button has
/// ``jumpIdentifier``.
public struct WaitingDescendantBanner: View {
  /// The accessibility identifier of the text of the banner.
  public static let identifier = "session-waiting-descendant"

  /// The accessibility identifier of the jump button.
  public static let jumpIdentifier = "session-waiting-descendant-jump"

  /// The session whose descendants the banner watches.
  let session: SessionModel

  /// Called with the id of the descendant that the button names.
  let jump: (SessionId) -> Void

  /// Makes the banner of the waiting descendants of a session.
  ///
  /// - Parameters:
  ///   - session: The shown session.
  ///   - jump: Called with the id of the descendant to show.
  public init(session: SessionModel, jump: @escaping (SessionId) -> Void) {
    self.session = session
    self.jump = jump
  }

  /// The text of the banner for a descendant.
  ///
  /// - Parameter entry: The path entry of the descendant.
  /// - Returns: The message, with the path of the descendant in the
  ///   explanation.
  static func message(for entry: SessionPathEntry) -> StatusBar.Message {
    StatusBar.Message(
      title: String(localized: "Another session needs you", bundle: .module),
      explanation: entry.path.joined(separator: SessionJumpList.pathSeparator),
      symbolName: SharedSymbol.warning, identifier: identifier, severity: .warning)
  }

  /// The bar for the descendant that waits, or nothing.
  public var body: some View {
    if let entry = session.waitingElsewhere {
      StatusBar(
        message: Self.message(for: entry),
        action: StatusBar.Action(
          title: String(localized: "Show", bundle: .module), systemImage: SharedSymbol.disclosure,
          identifier: Self.jumpIdentifier, isEnabled: true
        ) { jump(entry.sessionId) }
      )
      .statusBarActionStyle(AgentStatusBarActionStyle())
    }
  }
}

/// The banner of a child session whose state the client does not know yet,
/// or whose restore failed.
///
/// After a resume, a child is unconfirmed until its first current snapshot:
/// the view shows it as unknown, and the thread disables its controls. A
/// child that failed to restore stays unknown, and the banner gives the
/// reason that the agent sent. A root session, and a child with a known
/// state, show nothing.
public struct UnconfirmedSessionBanner: View {
  /// The accessibility identifier of the text of the banner.
  public static let identifier = "session-unconfirmed"

  /// The session that the banner watches.
  let session: SessionModel

  /// Makes the banner of a session.
  ///
  /// - Parameter session: The shown session.
  public init(session: SessionModel) {
    self.session = session
  }

  /// The text of the banner.
  ///
  /// - Parameter status: The status of the session.
  /// - Returns: The message, or `nil` when the state is known.
  static func message(for status: SessionStatus) -> StatusBar.Message? {
    switch status {
    case .running, .requiresAction, .idle: return nil
    case .restoreFailed(let reason):
      return StatusBar.Message(
        title: String(localized: "This sub-session did not restore", bundle: .module), explanation: reason,
        symbolName: SharedSymbol.warning, identifier: identifier, severity: .warning)
    case .unconfirmed:
      return information(
        title: String(localized: "The state of this sub-session is not known yet", bundle: .module),
        explanation: String(localized: "The agent has not sent the current state after the resume.", bundle: .module))
    case .unknown:
      return information(
        title: String(localized: "The agent gave no state for this sub-session", bundle: .module),
        explanation: String(localized: "The state stays unknown.", bundle: .module))
    }
  }

  /// A neutral message of the banner.
  private static func information(title: String, explanation: String) -> StatusBar.Message {
    StatusBar.Message(
      title: title, explanation: explanation, symbolName: SharedSymbol.information, identifier: identifier,
      severity: .information)
  }

  /// The bar for an unconfirmed child, or nothing.
  public var body: some View {
    if session.parent != nil, let message = Self.message(for: session.status) {
      StatusBar(message: message, action: nil)
    }
  }
}
