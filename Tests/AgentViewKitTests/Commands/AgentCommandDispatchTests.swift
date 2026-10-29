@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorCommands
import EditorCommandsUI
import Foundation
import Testing

/// Tests for ``AgentCommandDispatch``, the one dispatch call of the targets
/// of the agent scopes, with no window.
///
/// Each test registers the attachment commands with the fixture of
/// ``AgentAttachmentCommandsTests``, so a run goes to a
/// ``RecordingAttachmentFileService``.
@MainActor struct AgentCommandDispatchTests {
  /// The suite whose fixture the tests use.
  typealias Shared = AgentAttachmentCommandsTests

  /// Makes a command system that holds the registry of `fixture`.
  ///
  /// - Parameter fixture: The fixture of the registration.
  /// - Returns: The command system.
  static func system(of fixture: Shared.Fixture) -> CommandSystem {
    let system = CommandSystem()
    system.registry = fixture.registry
    return system
  }

  @Test func aDispatchRunsTheCommandAtThePath() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try AttachmentFixtures.attachment(named: "blob.bin", in: directory)
    let fixture = Shared.makeFixture(for: attachment)

    let ran = AgentCommandDispatch.perform(
      AgentAttachmentVerb.saveAttachment.id, in: Self.system(of: fixture), at: fixture.path)

    #expect(ran)
    #expect(fixture.service.calls == [.init(verb: .saveAttachment, attachment: attachment)])
  }

  @Test func aDispatchWithNoSystemRunsNothing() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let fixture = Shared.makeFixture(
      for: try AttachmentFixtures.attachment(named: "blob.bin", in: directory))

    let ran = AgentCommandDispatch.perform(AgentAttachmentVerb.saveAttachment.id, in: nil, at: fixture.path)

    #expect(!ran)
    #expect(fixture.service.calls.isEmpty)
  }

  @Test func aDispatchWithNoPathRunsNothing() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let fixture = Shared.makeFixture(
      for: try AttachmentFixtures.attachment(named: "blob.bin", in: directory))

    let ran = AgentCommandDispatch.perform(
      AgentAttachmentVerb.saveAttachment.id, in: Self.system(of: fixture), at: nil)

    #expect(!ran)
    #expect(fixture.service.calls.isEmpty)
  }
}
