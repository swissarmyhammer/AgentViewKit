import AgentViewKitTestSupport
import EditorCommands
import EditorCommandsUI
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// Tests for the composer focus of a thread with no transcript entry
/// (``AgentCommandTarget/focusComposerInEmptyThread(after:)``, Testudo,
/// 2026-11-20).
///
/// When an empty thread shows, or its scope gets the focus, the composer
/// takes the first responder.
@MainActor struct EmptyThreadComposerFocusTests {
  /// A fixture whose target knows its path and has a composer hook that
  /// counts its focus calls in `log`.
  ///
  /// - Parameters:
  ///   - session: The session model of the scope.
  ///   - log: The log of the composer hook.
  /// - Returns: The fixture.
  static func fixture(session: SessionModel, log: InsertMentionCommandTests.ComposerLog)
    -> AgentCommandsTests.Fixture
  {
    let fixture = InsertMentionCommandTests.fixture(session: session, log: log)
    fixture.target.path = fixture.path
    return fixture
  }

  /// A click on the scope at `path`.
  ///
  /// - Parameter path: The path of the scope that got the focus.
  /// - Returns: The focus move.
  static func click(at path: FocusPath) -> FocusMove {
    FocusMove(path: path, cause: .click, number: 1)
  }

  @Test func theShowOfAnEmptyThreadFocusesTheComposer() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let log = InsertMentionCommandTests.ComposerLog()
    let fixture = Self.fixture(session: session.model, log: log)

    fixture.target.focusComposerInEmptyThread(after: nil)

    #expect(log.focuses == 1)
  }

  @Test func aFocusMoveToTheScopeOfAnEmptyThreadFocusesTheComposer() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let log = InsertMentionCommandTests.ComposerLog()
    let fixture = Self.fixture(session: session.model, log: log)

    fixture.target.focusComposerInEmptyThread(after: Self.click(at: fixture.path))

    #expect(log.focuses == 1)
  }

  @Test func aFocusMoveToAScopeInTheThreadDoesNotFocusTheComposer() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let log = InsertMentionCommandTests.ComposerLog()
    let fixture = Self.fixture(session: session.model, log: log)
    let nested = fixture.path.appending(ConversationEmptyLayout.textSegment)

    fixture.target.focusComposerInEmptyThread(after: Self.click(at: nested))

    #expect(log.focuses == 0)
  }

  @Test func aFocusMoveToTheScopeOfAThreadWithMessagesDoesNotFocusTheComposer() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let log = InsertMentionCommandTests.ComposerLog()
    let fixture = Self.fixture(session: session.model, log: log)
    _ = try await AgentCommandsTests.sendTurns(to: session)

    fixture.target.focusComposerInEmptyThread(after: Self.click(at: fixture.path))

    #expect(log.focuses == 0)
  }

  @Test func theShowOfAThreadWithMessagesDoesNotFocusTheComposer() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let log = InsertMentionCommandTests.ComposerLog()
    let fixture = Self.fixture(session: session.model, log: log)
    _ = try await AgentCommandsTests.sendTurns(to: session)

    fixture.target.focusComposerInEmptyThread(after: nil)

    #expect(log.focuses == 0)
  }
}
