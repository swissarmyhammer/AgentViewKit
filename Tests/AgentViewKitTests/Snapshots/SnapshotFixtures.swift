@testable import AgentViewKit
import AgentViewKitTestSupport
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
  /// The Swift code of the code block in the thread and of the code block
  /// image.
  static let swiftCode = """
    import Foundation

    let url = URL(filePath: "/Users/preview/project")
    print(url.lastPathComponent)
    """

  /// The fenced code block of ``swiftCode`` in Markdown.
  static let swiftFence = "```swift\n\(swiftCode)\n```"

  /// The text of the agent message with the code block.
  static let agentMessage = """
    `Parser.swift` does not import **Foundation**. Add the import:

    \(swiftFence)

    Then run the tests again.
    """

  /// The width of the image of the thread, the composer and the elicitation
  /// form, in points.
  static let wideWidth: CGFloat = 480

  /// The width of the image of a card, a banner, the code block and the
  /// terminal output, in points.
  static let narrowWidth: CGFloat = 420

  /// The height of the image of the thread, in points.
  static let threadHeight: CGFloat = 640

  /// The height of the image of the composer, in points.
  static let composerHeight: CGFloat = 140

  /// The height of the image of a card or a banner, in points.
  static let cardHeight: CGFloat = 220

  /// The height of the image of a banner of one line, in points.
  static let bannerHeight: CGFloat = 90

  /// The height of the image of the code block, in points.
  static let codeBlockHeight: CGFloat = 150

  /// The height of the image of the terminal output, in points.
  static let terminalHeight: CGFloat = 200

  /// The height of the image of the elicitation form, in points.
  static let elicitationHeight: CGFloat = 620

  /// The size of the image of the thread, in points.
  static let threadSize = CGSize(width: wideWidth, height: threadHeight)

  /// The size of the image of the composer, in points.
  static let composerSize = CGSize(width: wideWidth, height: composerHeight)

  /// The size of the image of a card or a banner, in points.
  static let cardSize = CGSize(width: narrowWidth, height: cardHeight)

  /// The size of the image of a banner of one line, in points.
  static let bannerSize = CGSize(width: narrowWidth, height: bannerHeight)

  /// The size of the image of the code block, in points.
  static let codeBlockSize = CGSize(width: narrowWidth, height: codeBlockHeight)

  /// The size of the image of the terminal output, in points.
  static let terminalSize = CGSize(width: narrowWidth, height: terminalHeight)

  /// The size of the image of the elicitation form, in points.
  static let elicitationSize = CGSize(width: wideWidth, height: elicitationHeight)

  /// A session with a user message, an agent message with a code block, a
  /// tool call that completed, and a last agent message.
  static var threadSession: SessionModel {
    SessionModel.preview(transcript: [
      .user("Why does the build fail?"),
      .agent(agentMessage),
      .toolCall(title: "Run swift test", kind: .execute, status: .completed),
      .agent("The tests pass now."),
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
    let paragraph = try #require(ParagraphSplitter.paragraphs(agentMessage).first { $0.text.contains(swiftFence) })
    let id = CodeBlockID(
      messageID: EntryContentView.blockID(entryID: entry.id.rowKey, index: 0),
      paragraphID: ParagraphView.key(for: paragraph.id))
    try #require(cache.contains(id))
    return cache.model(for: id, code: swiftCode)
  }

  /// Whether `entry` is the agent message with the code block.
  ///
  /// - Parameter entry: An entry of the transcript.
  /// - Returns: `true` when the entry is that message.
  private static func isCodeMessage(_ entry: TranscriptEntry) -> Bool {
    let blocks = (entry.object as? AgentMessageEntry)?.content ?? []
    return blocks.contains { block in
      if case .text(let text) = block { return text.text.contains(swiftFence) }
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
