import AgentViewKit
import AgentViewKitFoundationModels
import AgentViewKitTestSupport
import Foundation
import FoundationModels
import Testing

@testable import DemoSupport

/// Tests of ``FoundationModelsDemoSession``, of the launch arguments of the
/// FoundationModels tab, and of the two demo tools.
///
/// The fake model of `--fake-language-model` answers each prompt, so the
/// tests run on a machine without the system model.
@Suite @MainActor struct FoundationModelsDemoSessionTests {
  /// The launch options that bind the fake model.
  private static let fakeOptions = DemoLaunchOptions(arguments: ["app", DemoLaunchOptions.fakeLanguageModelArgument])

  /// The launch options that make the model unavailable.
  private static let forcedOptions = DemoLaunchOptions(arguments: ["app", DemoLaunchOptions.forceModelUnavailableArgument])

  /// The time that the fixed clock of the clock tool gives.
  nonisolated private static let fixedTime = Date(timeIntervalSince1970: 0)

  /// The actions of a session whose model is available, or `nil`.
  ///
  /// - Parameter session: The session.
  /// - Returns: The actions.
  private static func actions(of session: FoundationModelsDemoSession) -> SessionThreadActions? {
    if case .available(let actions) = session.state { actions } else { nil }
  }

  /// The reason of a session whose model is not available, or `nil`.
  ///
  /// - Parameter session: The session.
  /// - Returns: The reason.
  private static func unavailableReason(of session: FoundationModelsDemoSession) -> String? {
    if case .unavailable(let reason) = session.state { reason } else { nil }
  }

  /// Whether an item is a user message.
  ///
  /// - Parameter item: The item.
  /// - Returns: `true` for a user message.
  private static func isUserMessage(_ item: ThreadItem) -> Bool {
    if case .userMessage = item { true } else { false }
  }

  // MARK: - Launch options

  @Test func theFakeModelArgumentOpensTheFoundationModelsTab() {
    #expect(Self.fakeOptions.languageModel == .fake)
    #expect(Self.fakeOptions.initialTab == .foundationModels)
  }

  @Test func theForceUnavailableArgumentOpensTheFoundationModelsTab() {
    #expect(Self.forcedOptions.languageModel == .forcedUnavailable)
    #expect(Self.forcedOptions.initialTab == .foundationModels)
  }

  @Test func withNoFoundationModelsArgumentTheAppOpensTheACPTabOnTheSystemModel() {
    let options = DemoLaunchOptions(arguments: ["app", InMemoryDemoAgent.launchArgument])
    #expect(options.languageModel == .system)
    #expect(options.initialTab == .acp)
  }

  // MARK: - Session

  @Test func theForcedUnavailableOptionGivesTheReasonAndNoActions() {
    let session = FoundationModelsDemoSession(options: Self.forcedOptions)

    #expect(Self.unavailableReason(of: session) == FoundationModelsDemoSession.forcedUnavailableReason)
    #expect(FoundationModelsDemoSession.forcedUnavailableReason.contains(DemoLaunchOptions.forceModelUnavailableArgument))
    #expect(Self.actions(of: session) == nil)
  }

  @Test func withTheFakeModelASendGivesTheScriptedReply() async throws {
    let session = FoundationModelsDemoSession(options: Self.fakeOptions)
    let actions = try #require(Self.actions(of: session))
    let thread = actions.source.thread

    await actions.send(UserInput(text: "hello"))

    let reply = try #require(SourceSamples.assistantMessage(thread.items.last))
    #expect(reply.blocks.first?.content == .text(FoundationModelsDemoSession.fakeReply))
    #expect(thread.items.contains(where: Self.isUserMessage))
    #expect(thread.state == .idle(nil))
  }

  @Test func aSecondSendToTheFakeModelGivesASecondReply() async throws {
    let session = FoundationModelsDemoSession(options: Self.fakeOptions)
    let actions = try #require(Self.actions(of: session))
    let thread = actions.source.thread

    await actions.send(UserInput(text: "hello"))
    await actions.send(UserInput(text: "hello again"))

    let replies = thread.items.compactMap(SourceSamples.assistantMessage)
    #expect(replies.count == 2)
    #expect(Set(replies.map(\.id)).count == 2)
  }

  @Test func theFakeSessionMeasuresTheContextWindow() async throws {
    let session = FoundationModelsDemoSession(options: Self.fakeOptions)
    let actions = try #require(Self.actions(of: session))
    let thread = actions.source.thread

    await actions.send(UserInput(text: "hello"))

    let entryCount = actions.source.session.transcript.count
    #expect(
      await waitUntil {
        thread.usage?.size == FoundationModelsDemoSession.fakeContextSize && thread.usage?.used == entryCount
      })
  }

  // MARK: - Tools

  @Test func theClockToolGivesTheTimeInTheZoneOfTheArguments() async throws {
    let tool = ClockTool(clock: { Self.fixedTime })
    let arguments = try ClockTool.Arguments(GeneratedContent(json: #"{"timeZone": "GMT"}"#))

    #expect(await tool.call(arguments: arguments) == "The time in GMT is 1970-01-01T00:00:00Z.")
  }

  @Test func theClockToolUsesTheFallbackZoneForAnIdentifierItDoesNotKnow() async throws {
    let tool = ClockTool(clock: { Self.fixedTime })
    let arguments = try ClockTool.Arguments(GeneratedContent(json: #"{"timeZone": "Mars/Olympus"}"#))

    #expect(await tool.call(arguments: arguments) == "The time in GMT is 1970-01-01T00:00:00Z.")
  }

  @Test func theWordCountToolCountsTheWordsOfTheText() async throws {
    let arguments = try WordCountTool.Arguments(GeneratedContent(json: #"{"text": "one two\n  three"}"#))

    #expect(await WordCountTool().call(arguments: arguments) == "The text has 3 words.")
  }

  @Test func theWordCountToolSaysOneWordInTheSingular() async throws {
    let arguments = try WordCountTool.Arguments(GeneratedContent(json: #"{"text": "one"}"#))

    #expect(await WordCountTool().call(arguments: arguments) == "The text has 1 word.")
  }
}
