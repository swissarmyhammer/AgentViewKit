import ACPMarkdown
import AgentViewKitTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

@testable import AgentViewKit

/// The read-only chat of a shared session for the review gallery
/// (TestudoApp D208 (i)): a read-only model with the header of the host
/// (`threadHeader(_:)`), and the same chat with the unavailable message of
/// the host (`threadUnavailable(_:)`).
///
/// The host gives the text of the header and of the message. These texts
/// stand for the strings of TestudoApp.
@MainActor
enum SharedThreadFixtures {
  /// The id of the shared session.
  static let sessionID = SessionId(rawValue: "shared-session")

  /// The text of the header of the host.
  static let headerText = "Shared by Ann Lee · Updated 2 hours ago"

  /// The unavailable message of the host.
  static let unavailableText = "The owner stopped sharing this session."

  /// The text of the user message.
  static let question = "How do I run only the tests of the checkout module?"

  /// The text of the agent message.
  static let answer = """
    Give the name of the module to the filter of the test command:

    ```sh
    swift test --filter CheckoutTests
    ```

    The 18 tests of the checkout module pass.
    """

  /// A read-only model that shows a share snapshot of one user message and
  /// one agent message.
  static var sharedSession: SessionModel {
    let updates: [SessionUpdate] = [
      .userMessageChunk(
        ContentChunk(
          content: .text(TextContent(text: question)), messageId: MessageId(rawValue: "user-1"))),
      BackgroundRunScript.makeChunkUpdate(messageID: "agent-1", text: answer),
    ]
    return SessionModel(snapshot: SessionSnapshot.build(updates: updates), sessionId: sessionID)
  }

  /// The read-only chat with the header of the host.
  static var sharedThread: some View {
    AgentThreadView(session: sharedSession) { EmptyView() }
      .threadHeader { header }
  }

  /// The read-only chat with the header and the unavailable message of the
  /// host.
  static var unavailableThread: some View {
    AgentThreadView(session: sharedSession) { EmptyView() }
      .threadHeader { header }
      .threadUnavailable(unavailableText)
  }

  /// The header of the host: one line of secondary text.
  static var header: some View {
    Text(headerText).foregroundStyle(.secondary)
  }
}
