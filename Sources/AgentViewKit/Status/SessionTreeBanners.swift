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
      title: String(localized: "A sub-session needs you", bundle: .module),
      explanation: SessionPathText.label(entry.path),
      symbolName: SharedSymbol.warning, identifier: identifier, severity: .warning)
  }

  /// The bar for the descendant that waits, or nothing.
  public var body: some View {
    if let entry = session.waitingDescendant {
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
  /// - Parameter failure: The reason that the restore failed, or `nil` for a
  ///   child that waits for its first snapshot.
  /// - Returns: The message.
  static func message(failure: String?) -> StatusBar.Message {
    if let failure {
      return StatusBar.Message(
        title: String(localized: "This sub-session did not restore", bundle: .module), explanation: failure,
        symbolName: SharedSymbol.warning, identifier: identifier, severity: .warning)
    }
    return StatusBar.Message(
      title: String(localized: "The state of this sub-session is not known yet", bundle: .module),
      explanation: String(
        localized: "The controls stay off until the agent sends the current state.", bundle: .module),
      symbolName: SharedSymbol.information, identifier: identifier, severity: .information)
  }

  /// The bar for an unconfirmed child, or nothing.
  public var body: some View {
    if session.parent != nil, session.workState == .unknown {
      StatusBar(message: Self.message(failure: session.restoreFailure), action: nil)
    }
  }
}
