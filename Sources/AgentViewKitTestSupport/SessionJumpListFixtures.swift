import FoundationModelsACP
import FoundationModelsACPClient

/// A tree of eight child sessions with long titles, for the list of Jump to
/// Session (^vkcj2qh).
///
/// Each path of the tree is long: a narrow list wraps it to more than one
/// line. The unit test of the row frames and the review gallery read the same
/// tree.
public enum SessionJumpListFixtures {
  /// One child session of the tree.
  public struct Child: Sendable {
    /// The id of the session.
    public let id: SessionId

    /// The title of the session.
    public let title: String

    /// The parent of the session, or `nil` for a child of the scripted
    /// session.
    public let parent: SessionId?
  }

  /// The name of the agent, the first name of each path.
  public static let agent = "Code Review Agent of the Board"

  /// The id of the planner, a child of the scripted session.
  static let planner = SessionId(rawValue: "planner")

  /// The id of the reviewer, a child of the planner.
  static let reviewer = SessionId(rawValue: "reviewer")

  /// The id of the linter, a child of the reviewer.
  static let linter = SessionId(rawValue: "linter")

  /// The id of the test runner, a child of the scripted session.
  static let tester = SessionId(rawValue: "tester")

  /// The id of the translator, a child of the scripted session.
  static let translator = SessionId(rawValue: "translator")

  /// The children of the tree, each after its parent: three chains under
  /// the scripted session, the longest four levels deep.
  public static let children = [
    Child(id: planner, title: "Planner of the release notes for the next version", parent: nil),
    Child(id: reviewer, title: "Reviewer of the changes to the session tree", parent: planner),
    Child(id: linter, title: "Linter of the Swift sources of the kit", parent: reviewer),
    Child(
      id: SessionId(rawValue: "formatter"), title: "Formatter of the Markdown documents", parent: linter),
    Child(id: tester, title: "Runner of the hosted test suites of the kit", parent: nil),
    Child(
      id: SessionId(rawValue: "gallery"), title: "Recorder of the images of the review gallery",
      parent: tester),
    Child(id: translator, title: "Translator of the string catalog of the kit", parent: nil),
    Child(
      id: SessionId(rawValue: "auditor"), title: "Auditor of the focus look of each control",
      parent: translator),
  ]

  /// Opens a scripted session, and announces each child of ``children`` in
  /// the stream of its parent.
  ///
  /// - Returns: The scripted session. The caller closes it.
  /// - Throws: The error of the open or of an announcement. When an
  ///   announcement fails, the session is closed before the throw.
  @MainActor
  public static func openSession() async throws -> ScriptedSession {
    let session = try await ScriptedSession.open()
    do {
      for child in children {
        try await session.announceChild(child.id, title: child.title, in: child.parent)
      }
    } catch {
      session.close()
      throw error
    }
    return session
  }
}
