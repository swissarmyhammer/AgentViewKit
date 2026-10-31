@testable import AgentViewKit
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The failed turn of a thread, with a sign-in card in its bottom bar.
///
/// The hosted tests of the bars read its layout, and the review gallery shows
/// it. `ScreenshotTests/Tests/ScreenshotTests` holds a symlink to this file, so
/// that the two packages keep one copy.
enum FailedTurnFixtures {
  /// The width of a thread, in points.
  static let threadWidth: CGFloat = 480

  /// The height of a thread, in points.
  static let threadHeight: CGFloat = 640

  /// The size of a thread, in points.
  static let threadSize = CGSize(width: threadWidth, height: threadHeight)

  /// The default number of the agent messages of
  /// ``failedTurnSession(messageCount:)``. With the error entry, they fit in
  /// the part of the list of a thread of ``threadSize`` between its two bars,
  /// when the bottom bar shows the failure banner and the sign-in card. So at
  /// rest no row is under a bar, and each line of the image is readable
  /// (^zg9tysk).
  static let failedTurnMessageCount = 1

  /// A session whose last turn failed: `messageCount` agent messages, an idle
  /// state with the stop reason `error`, and an error entry at the end of the
  /// transcript. In a thread, the state banner in the bottom bar then shows
  /// its Show Error button.
  ///
  /// - Parameter messageCount: The number of the agent messages, at least
  ///   one.
  /// - Returns: The session model.
  static func failedTurnSession(messageCount: Int = failedTurnMessageCount) -> SessionModel {
    let messages = (1...messageCount).map { number in
      PreviewTranscriptItem.agent(
        "Step \(number): the import reads the next rows of the customer file, and skips each row that has no "
          + "email address. The count of the skipped rows goes to the log.")
    }
    let session = SessionModel.preview(
      transcript: messages + [.update(.stateUpdate(.idle(IdleStateUpdate(stopReason: .error))))])
    session.appendError(code: .internalError, message: "The tool did not start.", data: nil)
    return session
  }

  /// The one agent auth method of ``signInConnection``.
  static let signInMethod = AuthMethod.agent(
    AuthMethodAgent(
      methodId: AuthMethodId(rawValue: "tests-agent-login"), name: "Sign in with the agent",
      description: "The agent opens its sign-in page."))

  /// A code-built connection model that asks for a sign-in with
  /// ``signInMethod``.
  static var signInConnection: ConnectionModel {
    .preview(
      authState: .required([signInMethod]),
      initializeResponse: InitializeResponse(
        info: Implementation(name: "tests-agent", version: "1.0.0"),
        protocolVersion: ACPClient.supportedProtocolVersion, authMethods: [signInMethod]))
  }
}
