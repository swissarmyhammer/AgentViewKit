import AgentViewKit
import AgentViewKitFoundationModels
import Foundation
import FoundationModels

/// The FoundationModels session of the demo app's FoundationModels tab.
///
/// The model makes a `LanguageModelSession` with the two demo tools
/// (``ClockTool`` and ``WordCountTool``) and the ``SessionProfileHooks``
/// that stamp the host times, and binds a ``SessionThreadSource`` and a
/// ``SessionThreadActions`` to one ``AgentThread``.
///
/// The language model comes from ``DemoLaunchOptions/languageModel``:
///
/// - ``DemoLaunchOptions/LanguageModelChoice/system``: the model reads
///   `SystemLanguageModel.default.availability`. When the model is
///   available, the session runs on it. Otherwise ``state`` holds the reason.
/// - ``DemoLaunchOptions/LanguageModelChoice/fake``: the session runs on
///   ``FakeLanguageModel`` with ``fakeRounds``, and reads no availability.
///   Thus the end-to-end test runs on a machine without the system model.
/// - ``DemoLaunchOptions/LanguageModelChoice/forcedUnavailable``: ``state``
///   holds ``forcedUnavailableReason``.
public final class FoundationModelsDemoSession {
  /// The state of the tab.
  public enum State {
    /// The model is available. The actions drive the bound thread.
    case available(SessionThreadActions)

    /// The model is not available, with the text that says why.
    case unavailable(reason: String)
  }

  /// The instructions of the session.
  nonisolated public static let instructions = """
    You are the assistant of the AgentViewKit demo. Use the clock tool for \
    the current time, and the wordCount tool to count the words of a text.
    """

  /// The reply of the fake model to each prompt.
  nonisolated public static let fakeReply =
    "Hello from the fake model. The clock and the word count tools are ready."

  /// The number of tokens of the context window of the fake model.
  nonisolated public static let fakeContextSize = 4096

  /// The reason that ``state`` holds with
  /// ``DemoLaunchOptions/LanguageModelChoice/forcedUnavailable``.
  public static let forcedUnavailableReason =
    "The launch argument \(DemoLaunchOptions.forceModelUnavailableArgument) makes the model unavailable."

  /// The events of each model call of a turn of the fake model: one text
  /// reply.
  ///
  /// The reply has no entry id, so the SDK gives each reply a new id, and a
  /// second prompt does not repeat an id.
  static let fakeRounds: [[FakeEvent]] = [[.text(entryID: nil, text: fakeReply)]]

  /// The context window of the fake model: ``fakeContextSize`` tokens, and
  /// one token for each transcript entry.
  static let fakeContextWindow = ContextWindow(
    size: { fakeContextSize }, tokenCount: { transcript in transcript.count })

  /// The state of the tab.
  public let state: State

  /// Makes the session of `options`.
  ///
  /// - Parameter options: The launch options of the demo app.
  public init(options: DemoLaunchOptions) {
    state = Self.makeState(for: options.languageModel)
  }

  /// The state for a model choice.
  ///
  /// - Parameter choice: The language model of the launch options.
  /// - Returns: The state, with the actions of a bound session when the
  ///   model is available.
  private static func makeState(for choice: DemoLaunchOptions.LanguageModelChoice) -> State {
    switch choice {
    case .forcedUnavailable:
      return .unavailable(reason: forcedUnavailableReason)
    case .fake:
      return .available(bind(FakeLanguageModel(rounds: fakeRounds), contextWindow: fakeContextWindow))
    case .system:
      let model = SystemLanguageModel.default
      switch model.availability {
      case .available:
        return .available(bind(model, contextWindow: .system(model)))
      case .unavailable(let reason):
        return .unavailable(reason: text(for: reason))
      }
    }
  }

  /// Makes a session on `model` with the demo tools and the hooks, and binds
  /// a source and the actions to a new thread.
  ///
  /// - Parameters:
  ///   - model: The language model of the session.
  ///   - contextWindow: The measure of the context window of the model.
  /// - Returns: The actions of the bound session.
  private static func bind(_ model: some LanguageModel, contextWindow: ContextWindow) -> SessionThreadActions {
    let hooks = SessionProfileHooks()
    let session = LanguageModelSession(profile: makeProfile(model: model, hooks: hooks))
    let source = SessionThreadSource(session: session, contextWindow: contextWindow, hooks: hooks)
    source.start()
    return SessionThreadActions(source: source)
  }

  /// Makes the profile of the session: the instructions, the two demo tools,
  /// `model`, and the hooks.
  ///
  /// The profile is built outside the main actor, so that the session can
  /// take it as a `sending` value.
  ///
  /// - Parameters:
  ///   - model: The language model of the session.
  ///   - hooks: The hooks that stamp the host times.
  /// - Returns: The profile.
  nonisolated private static func makeProfile(
    model: some LanguageModel,
    hooks: SessionProfileHooks
  ) -> some LanguageModelSession.DynamicProfile {
    hooks.install(
      on: LanguageModelSession.Profile {
        Instructions(instructions)
        ClockTool()
        WordCountTool()
      }
      .model(model))
  }

  /// The text that the tab shows for a system model that is not available.
  ///
  /// - Parameter reason: The reason of the SDK.
  /// - Returns: The text.
  static func text(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
    switch reason {
    case .deviceNotEligible:
      "This device cannot run the on-device model."
    case .appleIntelligenceNotEnabled:
      "Apple Intelligence is not enabled. Enable it in System Settings, and then start the demo again."
    case .modelNotReady:
      "The model is not ready. Start the demo again later."
    @unknown default:
      "The model is not available."
    }
  }
}
