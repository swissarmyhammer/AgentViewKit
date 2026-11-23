import ACPMarkdown
import AgentViewKitTestSupport
import EditorCommands
import EditorCommandsUI
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

@testable import AgentViewKit

/// The read-only chat of a shared session for the review gallery
/// (TestudoApp D208 (i)): a read-only model with the header of the host
/// (`threadHeader(_:)`), and the same chat with the unavailable message of
/// the host (`threadUnavailable(_:)`). It also gives the same chat as the
/// read-only tab of an external session (TestudoApp D212), with the header of
/// a title and the command Continue in Testudo (`threadHeader(_:action:)`),
/// and with the composer of the host
/// (`threadComposer(placeholder:onSubmit:)`).
///
/// The host gives the text of the header, of the message and of the command.
/// These texts stand for the strings of TestudoApp.
@MainActor
enum SharedThreadFixtures {
  /// The id of the shared session.
  static let sessionID = SessionId(rawValue: "shared-session")

  /// The text of the header of the host.
  static let headerText = "Shared by Ann Lee · Updated 2 hours ago"

  /// The title of the header of the read-only tab of an external session.
  static let externalHeaderText = "Claude Code · read-only · Nov 21, 2026"

  /// The id of the command Continue in Testudo of the host.
  nonisolated static let continueCommandID = CommandID("testudo.continueInTestudo")

  /// The title of the command Continue in Testudo of the host.
  nonisolated static let continueTitle = "Continue in Testudo"

  /// The scope of the tab of the host, which holds the command Continue in
  /// Testudo.
  static let tabScope = FocusSegment(kind: "externalSessionTab")

  /// The width of the narrow thread of the external session, in points: too
  /// narrow for the whole title and the button on one line.
  nonisolated static let narrowThreadWidth: CGFloat = 300

  /// The size of the narrow thread of the external session: the height of a
  /// thread at ``narrowThreadWidth``.
  nonisolated static let narrowThreadSize = CGSize(
    width: narrowThreadWidth, height: FailedTurnFixtures.threadHeight)

  /// The placeholder of the composer of the host in the read-only tab of an
  /// external session.
  static let continuePlaceholder = "Message to continue in Testudo"

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

  /// The read-only chat of an external session, with the header of the
  /// title and the command Continue in Testudo, in the scope of the tab of
  /// the host that registers the command.
  static var externalThread: some View {
    inExternalTab(
      AgentThreadView(session: sharedSession) { EmptyView() }
        .threadHeader(externalHeaderText, action: continueCommandID.rawValue))
  }

  /// The read-only chat of an external session, with the header of
  /// ``externalThread`` and the default composer, whose prompt goes to the
  /// host (TestudoApp D212). The composer shows the placeholder of the host,
  /// and a submit does nothing.
  static var externalComposerThread: some View {
    inExternalTab(
      AgentThreadView(session: sharedSession)
        .threadHeader(externalHeaderText, action: continueCommandID.rawValue)
        .threadComposer(placeholder: continuePlaceholder) { _ in })
  }

  /// Puts a thread in the scope of the tab of the host, under a command
  /// system that registers the command Continue in Testudo in that scope.
  ///
  /// - Parameter thread: The thread of the external session.
  /// - Returns: The thread in the scope of the tab.
  static func inExternalTab(_ thread: some View) -> some View {
    let system = CommandSystem()
    system.registry.register(continueDefinition, at: .root(tabScope))
    return thread
      .commandScope(segment: tabScope)
      .commandSystem(system)
  }

  /// The definition of the command Continue in Testudo of the host.
  static var continueDefinition: CommandDefinition {
    CommandDefinition(id: continueCommandID, title: .static(continueTitle)) { _ in
      ContinueInTestudoCommand()
    }
  }
}

/// The command Continue in Testudo of the host, for the review gallery: it is
/// available, and a run does nothing.
nonisolated struct ContinueInTestudoCommand: EditorCommands.Command {
  /// The id of the command.
  var id: CommandID { SharedThreadFixtures.continueCommandID }

  /// The title of the command.
  var title: String { SharedThreadFixtures.continueTitle }

  /// The command is available at each scope.
  ///
  /// - Parameter context: The context of the invocation, which the command
  ///   does not read.
  /// - Returns: `.available`.
  func availability(in context: CommandContext) -> Availability { .available }

  /// Does nothing: the gallery shows the button and presses nothing.
  ///
  /// - Parameter context: The context of the invocation, which the command
  ///   does not read.
  /// - Returns: `true`.
  func run(in context: CommandContext) -> Bool { true }
}
