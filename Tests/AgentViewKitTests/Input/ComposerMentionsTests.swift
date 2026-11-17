import AgentViewKitTestSupport
import EditorComplete
import EditorCore
import Foundation
import Synchronization
import Testing

@testable import AgentViewKit

/// Keeps the bodies that a mention source got.
nonisolated final class BodyLog: Sendable {
  /// The bodies, in order.
  private let state = Mutex<[String]>([])

  /// The bodies, in order.
  var bodies: [String] { state.withLock { $0 } }

  /// Records `body`.
  func record(_ body: String) {
    state.withLock { $0.append(body) }
  }
}

/// Tests for the host mention rows under `@` (AVK-15.1, D199).
///
/// A host mention source adds its rows to the `@file` rows of the kit. The
/// file rows come first, then the rows of each source, in source order.
@Suite @MainActor struct ComposerMentionsTests {
  /// The mentions of the tests.
  nonisolated static let mentions = [
    ComposerMention(
      label: "claude-code", token: "claude-code", detail: "Fix the parser",
      link: URL(string: "testudo-session://01ABC")),
    ComposerMention(label: "reviewer", token: "reviewer", detail: nil, link: nil),
  ]

  /// A source that gives ``mentions`` and records each body.
  static func source(log: BodyLog = BodyLog()) -> ComposerMentionSource {
    ComposerMentionSource { body in
      log.record(body)
      return mentions
    }
  }

  /// A fixture with the `@` source of the kit over the in-memory files of
  /// ``FileReferenceSourceTests`` and `sources`.
  static func fixture(
    _ text: String, files: Bool = true, sources: [ComposerMentionSource]
  ) -> CompletionFixture {
    CompletionFixture(
      text,
      sources: [
        SlashCommandSource(commands: []),
        AtReferenceSource(
          files: files ? FileReferenceSource(fileSystem: FileReferenceSourceTests.fileSystem) : nil,
          mentions: ComposerMentionSources(sources)),
      ])
  }

  // MARK: - Rows

  @Test func theFileRowsComeFirstThenTheMentionRows() async {
    let labels = await Self.fixture("@", sources: [Self.source()]).query()

    #expect(labels == ["src/", "notes.txt", "README.md", "claude-code", "reviewer"])
  }

  @Test func eachSourceGetsTheBodyAfterTheAtSign() async {
    let log = BodyLog()

    _ = await Self.fixture("ask @cla", sources: [Self.source(log: log)]).query()

    #expect(log.bodies == ["cla"])
  }

  @Test func theRowsOfEachSourceFollowInSourceOrder() async {
    let second = ComposerMentionSource { _ in
      [ComposerMention(label: "planner", token: "planner", detail: nil, link: nil)]
    }

    let labels = await Self.fixture("@", files: false, sources: [Self.source(), second]).query()

    #expect(labels == ["claude-code", "reviewer", "planner"])
  }

  @Test func withNoFileRootTheMentionRowsShow() async {
    let labels = await Self.fixture("@", files: false, sources: [Self.source()]).query()

    #expect(labels == ["claude-code", "reviewer"])
  }

  @Test func anAcceptedMentionInsertsTheTokenAndASpace() async {
    let fixture = Self.fixture("ask @cla", files: false, sources: [Self.source()])
    _ = await fixture.query()

    #expect(fixture.accept("claude-code"))

    #expect(fixture.text == "ask @claude-code ")
  }

  @Test func aTokenThatIsNotAtTheCaretAsksNoSource() async {
    let log = BodyLog()

    let labels = await Self.fixture("plain text", files: false, sources: [Self.source(log: log)]).query()

    #expect(labels.isEmpty)
    #expect(log.bodies.isEmpty)
  }

  // MARK: - Engine of the composer

  @Test func aMentionSourceKeepsTheFileRowsOfTheKit() {
    let root = URL(filePath: "/tmp/project", directoryHint: .isDirectory)

    let sources = PromptEditorSession.sources(
      commands: nil, root: root, prefixes: PrefixCompletionSource(routes: []),
      mentions: ComposerMentionSources([Self.source()]))

    let at = sources.compactMap { $0 as? AtReferenceSource }
    #expect(at.count == 1)
    #expect(at.first?.files != nil)
    #expect(!sources.contains { $0 is FileReferenceSource })
  }

  @Test func withNoMentionSourceTheFileSourceIsAsBefore() {
    let root = URL(filePath: "/tmp/project", directoryHint: .isDirectory)

    let sources = PromptEditorSession.sources(
      commands: nil, root: root, prefixes: PrefixCompletionSource(routes: []),
      mentions: ComposerMentionSources([]))

    #expect(sources.contains { $0 is FileReferenceSource })
    #expect(!sources.contains { $0 is AtReferenceSource })
  }

  @Test func anAtSignIsATriggerWhenAMentionSourceIsSet() {
    #expect(EditorKitPromptEditor.isTrigger("ask @", reportsCommands: false, hasAtSource: true))
    #expect(!EditorKitPromptEditor.isTrigger("ask @", reportsCommands: false, hasAtSource: false))
  }
}

/// Tests for the chip and the link of an accepted mention row (AVK-15.2,
/// D199).
@Suite @MainActor struct ComposerMentionChipTests {
  /// The link of the mention of the tests.
  static let link = URL(string: "testudo-session://01ABC")!

  /// The file root of the tests.
  static let root = URL(filePath: "/tmp/project", directoryHint: .isDirectory)

  // MARK: - Offered rows

  @Test func anOfferedRowIsKnownByItsToken() async {
    let mentions = ComposerMentionSources([ComposerMentionsTests.source()])
    let fixture = CompletionFixture(
      "@", sources: [AtReferenceSource(files: nil, mentions: mentions)])

    _ = await fixture.query()

    #expect(mentions.offered("claude-code") == .some(ComposerMentionsTests.mentions[0].link))
    #expect(mentions.offered("reviewer") == .some(nil))
    #expect(mentions.offered("someone") == nil)
  }

  @Test func theAcceptedMentionIsTheRunBeforeTheSpace() {
    #expect(EditorKitPromptEditor.acceptedMentionToken(before: "ask @claude-code ") == "claude-code")
    #expect(EditorKitPromptEditor.acceptedMentionToken(before: "ask @claude-code") == nil)
    #expect(EditorKitPromptEditor.acceptedMentionToken(before: "ask claude ") == nil)
  }

  // MARK: - Chip

  @Test func theDetectorFindsOnlyTheAcceptedTokens() {
    let text = "ask @claude-code and @someone"

    let matches = MentionDetector.mentions(in: text, tokens: ["claude-code"])

    #expect(matches.map(\.text) == ["@claude-code"])
  }

  // MARK: - Link

  @Test func theLinkOfAMentionIsOnItsRun() throws {
    let text = EditorKitPromptEditor.attributedText(
      "ask @claude-code now", references: [], root: Self.root, mentions: ["claude-code": Self.link])

    let run = try #require(text.runs.first { $0.link != nil })
    #expect(String(text[run.range].characters) == "@claude-code")
    #expect(run.link == Self.link)
  }

  @Test func theMentionsOfAPromptTextRoundTrip() {
    let mentions: [String: URL?] = ["claude-code": Self.link]
    let text = EditorKitPromptEditor.attributedText(
      "@notes.txt and @claude-code", references: ["notes.txt"], root: Self.root, mentions: mentions)

    #expect(EditorKitPromptEditor.mentions(in: text, root: Self.root) == mentions)
    #expect(EditorKitPromptEditor.references(in: text, root: Self.root) == ["notes.txt"])
  }

  @Test func aMentionLinkIsNotAnAttachment() {
    let text = EditorKitPromptEditor.attributedText(
      "ask @claude-code", references: [], root: Self.root, mentions: ["claude-code": Self.link])

    #expect(PromptInputView<EditorKitPromptEditor, DefaultPromptAccessory>.attachmentURLs([], in: text).isEmpty)
  }

  @Test func aMentionWithNoLinkHasNoLinkInThePromptText() {
    let text = EditorKitPromptEditor.attributedText(
      "@reviewer", references: [], root: nil, mentions: ["reviewer": nil])

    #expect(text.runs.allSatisfy { $0.link == nil })
  }
}
