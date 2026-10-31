@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorStyle
import EditorSwiftUI
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

/// The fixed data of the snapshot images (AVK-13).
///
/// Each session is a preview model (`SessionModel.preview`): it reads a
/// clock that never moves and the wall clock `SessionModel.previewDate`, so
/// each image shows the same times on each run.
enum SnapshotFixtures {
  /// The shell command of the code block in the thread: a test run of one
  /// module.
  static let shellCode = "swift test --filter CheckoutTests"

  /// The fenced code block of ``shellCode`` in Markdown.
  static let shellFence = "```shell\n\(shellCode)\n```"

  /// The text of the agent message with the code block.
  static let agentMessage = """
    Give `swift test` a **filter** with the name of the test target:

    \(shellFence)

    The filter matches the name of each test class of the module.
    """

  /// The command of the terminal image: the short status of a working tree.
  static let terminalCommand = "git status --short"

  /// The output of ``terminalCommand``: a changed file and a new file.
  static let terminalOutput = " M README.md\n?? Docs/setup.md"

  /// The width of the image of the thread, the composer and the elicitation
  /// form, in points.
  static let wideWidth = FailedTurnFixtures.threadWidth

  /// The width of the image of a card, a banner, the code block and the
  /// terminal output, in points.
  static let narrowWidth: CGFloat = 420

  /// The height of the image of the composer, in points.
  static let composerHeight: CGFloat = 140

  /// The height of the image of a card or a banner, in points.
  static let cardHeight: CGFloat = 220

  /// The height of the image of a banner of one line, in points.
  static let bannerHeight: CGFloat = 90

  /// The height of the image of the title lines of the bars, in points.
  static let titleLineBarsHeight: CGFloat = 520

  /// The height of the image of the code block, in points.
  static let codeBlockHeight: CGFloat = 150

  /// The height of the image of the terminal output, in points.
  static let terminalHeight: CGFloat = 200

  /// The height of the image of the elicitation form, in points.
  static let elicitationHeight: CGFloat = 620

  /// The size of the image of the thread, in points.
  static let threadSize = FailedTurnFixtures.threadSize

  /// The size of the image of the composer, in points.
  static let composerSize = CGSize(width: wideWidth, height: composerHeight)

  /// The size of the image of a card or a banner, in points.
  static let cardSize = CGSize(width: narrowWidth, height: cardHeight)

  /// The size of the image of the title lines of the bars, in points.
  static let titleLineBarsSize = CGSize(width: narrowWidth, height: titleLineBarsHeight)

  /// The size of the image of a banner of one line, in points.
  static let bannerSize = CGSize(width: narrowWidth, height: bannerHeight)

  /// The size of the image of the code block, in points.
  static let codeBlockSize = CGSize(width: narrowWidth, height: codeBlockHeight)

  /// The size of the image of the terminal output, in points.
  static let terminalSize = CGSize(width: narrowWidth, height: terminalHeight)

  /// The size of the image of the elicitation form, in points.
  static let elicitationSize = CGSize(width: wideWidth, height: elicitationHeight)

  /// The width of the image of the attachment inspector, in points: about
  /// the width of an inspector column.
  static let inspectorWidth: CGFloat = 320

  /// The height of the image of the attachment inspector, in points. The
  /// grouped form of the inspector fits in it with no scroll.
  static let inspectorHeight: CGFloat = 440

  /// The size of the image of the attachment inspector, in points.
  static let inspectorSize = CGSize(width: inspectorWidth, height: inspectorHeight)

  /// The name of the file that the attachment inspector shows.
  static let inspectorFileName = "answer.swift"

  /// A session with a user message, an agent message with a code block, a
  /// tool call that completed, and a last agent message.
  static var threadSession: SessionModel {
    SessionModel.preview(transcript: [
      .user("How do I run only the tests of the checkout module?"),
      .agent(agentMessage),
      .toolCall(title: "Run \(shellCode)", kind: .execute, status: .completed),
      .agent("The 18 tests of the checkout module pass."),
    ])
  }

  /// A session with no transcript, whose agent does not run.
  static var idleSession: SessionModel {
    SessionModel.preview()
  }

  /// A session whose agent runs.
  static var runningSession: SessionModel {
    SessionModel.preview(transcript: [.update(.stateUpdate(.running(RunningStateUpdate())))])
  }

  /// The size of the image of the request deck in the bar, in points.
  static let requestDeckSize = CGSize(width: 320, height: 320)

  /// The deck of a code-built session model that holds one form elicitation,
  /// in a `FloatingGlassContainer`, as in the composer slot of
  /// ``AgentThreadView``.
  static var deckInBar: some View {
    FloatingGlassContainer(spacing: EditorStyle.default.spacing.s) {
      RequestDeck(session: .preview(pendingElicitations: [PreviewFixtures.formElicitation]))
    }
  }

  /// A code-built session model that holds one permission request, with one
  /// `allow_once` option and one `reject_once` option.
  static var permissionSession: SessionModel {
    SessionModel.preview(pendingPermissions: [
      RequestPermissionRequest(
        options: [
          PermissionOption(kind: .allowOnce, name: "Allow", optionId: PermissionOptionId(rawValue: "allow")),
          PermissionOption(kind: .rejectOnce, name: "Reject", optionId: PermissionOptionId(rawValue: "reject")),
        ],
        sessionId: SessionModel.previewSessionId,
        title: "Run the database migration?"
      )
    ])
  }

  /// The card of the one request of ``permissionSession``.
  ///
  /// - Returns: The card.
  /// - Throws: An issue when the session model holds no request.
  static func permissionCard() throws -> PermissionView {
    let session = permissionSession
    let request = try #require(session.pendingPermissions.first)
    return PermissionView(request: request, session: session)
  }

  /// The bars of each shape of the title line: a long title and a long
  /// explanation, a short title and a long explanation, only a title, each with
  /// a button, and the dismissible notice of a request that the agent withdrew.
  /// The stack spaces the bars as the top bar of a thread does.
  static var titleLineBars: some View {
    let style = EditorStyle.default
    let action = PreviewFixtures.statusAction(isEnabled: true)
    return VStack(spacing: style.tile.margin) {
      StatusBar(message: PreviewFixtures.longStatusMessage, action: action)
      StatusBar(message: PreviewFixtures.longExplanationStatusMessage, action: action)
      StatusBar(message: PreviewFixtures.titleOnlyStatusMessage, action: action)
      WithdrawnNoticeRow(notice: PreviewFixtures.withdrawnNotice, dismiss: {})
    }
    .padding(style.tile.margin)
  }

  /// A code-built session model that holds one warning notice with a
  /// description.
  static var noticeSession: SessionModel {
    let notice = Notice(
      severity: .warning, title: "The context is almost full",
      description: "The agent compacts the context before the next prompt.")
    return SessionModel.preview(transcript: [.update(.notice(notice))])
  }

  /// The thread of the `bottom-bar-buttons` images: the failed turn of
  /// ``FailedTurnFixtures/failedTurnSession(messageCount:)``, with the sign-in
  /// card of ``FailedTurnFixtures/signInConnection`` and the default composer.
  static var bottomBarThread: some View {
    AgentThreadView(
      session: FailedTurnFixtures.failedTurnSession(), connection: FailedTurnFixtures.signInConnection
    ) {
      DefaultThreadComposer()
    }
  }

  /// The default composer of the thread for `session`.
  ///
  /// The composer reads its session model from the environment, as in the
  /// composer slot of ``AgentThreadView``.
  ///
  /// - Parameter session: The session of the composer.
  /// - Returns: The composer.
  static func composer(for session: SessionModel) -> some View {
    DefaultThreadComposer().environment(\.sessionModel, session)
  }

  /// The model of the code block of the agent message of `session` in
  /// `cache`.
  ///
  /// The thread makes the model in its first render pass. The identity of
  /// the model is the identity that ``ParagraphView`` gives the paragraph of
  /// the code block: the id of the text block of the message, and the key of
  /// the paragraph.
  ///
  /// - Parameters:
  ///   - cache: The cache that the thread uses.
  ///   - session: The session of ``threadSession``.
  /// - Returns: The model.
  /// - Throws: An issue when the session has no agent message with the code
  ///   block, or the cache has no model for it.
  static func codeBlockModel(in cache: CodeBlockModelCache, session: SessionModel) throws -> EditorModel {
    let entry = try #require(session.transcript.first(where: isCodeMessage))
    let paragraph = try #require(ParagraphSplitter.paragraphs(agentMessage).first { $0.text.contains(shellFence) })
    let id = CodeBlockID(
      messageID: EntryContentView.blockID(entryID: entry.id.rowKey, index: 0),
      paragraphID: ParagraphView.key(for: paragraph.id))
    try #require(cache.contains(id))
    return cache.model(for: id, code: shellCode)
  }

  /// Whether `entry` is the agent message with the code block.
  ///
  /// - Parameter entry: An entry of the transcript.
  /// - Returns: `true` when the entry is that message.
  private static func isCodeMessage(_ entry: TranscriptEntry) -> Bool {
    let blocks = (entry.object as? AgentMessageEntry)?.content ?? []
    return blocks.contains { block in
      if case .text(let text) = block { return text.text.contains(shellFence) }
      return false
    }
  }

  /// Waits for the end of the syntax parse of `model`.
  ///
  /// The parse runs off the main actor, and it ends for certain. The wait has
  /// no clock.
  ///
  /// - Parameter model: The model of a code block.
  static func waitForSyntax(of model: EditorModel) async {
    _ = await model.syntax?.ensureParsed(upTo: model.state.version)
  }
}
