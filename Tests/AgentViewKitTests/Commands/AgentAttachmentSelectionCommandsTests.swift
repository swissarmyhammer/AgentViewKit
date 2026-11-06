@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorCommands
import Foundation
import Testing

/// Tests for the attachment commands over the file selection, with no
/// window (card ^zsr2pbf).
///
/// The scope of a selected file gives the selected files to the context of
/// its commands, as the board of KanbanViewKit gives its selected cards, and
/// each command reads them with `@FromSelection`. Each test registers the
/// commands of one file with ``AgentAttachmentRegistration`` and sets the
/// files that the selection of the target reads. A run goes to a
/// ``RecordingAttachmentFileService``.
@MainActor struct AgentAttachmentSelectionCommandsTests {
  /// The fixture of the commands tests.
  typealias Fixture = AgentAttachmentCommandsTests.Fixture

  /// The objects of one test: the files, in transcript order, and their
  /// folder.
  struct Files {
    /// The folder of the files.
    let directory: TemporaryFolder
    /// The files, in transcript order.
    let files: [AgentViewKit.Attachment]
  }

  /// Writes three files.
  ///
  /// - Returns: The files. The caller removes the folder.
  /// - Throws: The error of a write.
  static func makeFiles() throws -> Files {
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    let files = try ["first.bin", "second.txt", "third.swift"].map {
      try AttachmentFixtures.attachment(named: $0, in: directory)
    }
    return Files(directory: directory, files: files)
  }

  /// The commands of `file`, whose target reads `selected` as the files of
  /// the selection that a command at the scope acts on.
  ///
  /// - Parameters:
  ///   - file: The file of the scope.
  ///   - selected: The files that the selection gives the scope.
  /// - Returns: The fixture.
  static func makeFixture(for file: AgentViewKit.Attachment, selected: [AgentViewKit.Attachment]) -> Fixture {
    let fixture = AgentAttachmentCommandsTests.makeFixture(for: file)
    fixture.target.selection = { selected }
    return fixture
  }

  /// The calls of a run of `verb` on each file of `files`, in order.
  ///
  /// - Parameters:
  ///   - verb: The verb.
  ///   - files: The files.
  /// - Returns: The calls.
  static func calls(
    of verb: AgentAttachmentVerb, on files: [AgentViewKit.Attachment]
  ) -> [RecordingAttachmentFileService.Call] {
    files.map { .init(verb: verb, attachment: $0) }
  }

  /// A key, the menu bar or the palette runs a command at the focused path,
  /// with no click.
  @Test func aCommandOnASelectedFileRunsOnEverySelectedFile() throws {
    let files = try Self.makeFiles()
    defer { files.directory.remove() }
    let fixture = Self.makeFixture(for: files.files[1], selected: files.files)

    #expect(fixture.registry.perform(AgentAttachmentVerb.openAttachment.id, at: fixture.path))

    #expect(fixture.service.calls == Self.calls(of: .openAttachment, on: files.files))
  }

  /// A row of the context menu runs its command with the path of the menu as
  /// the clicked path.
  @Test func aContextMenuRowOnASelectedFileRunsOnEverySelectedFile() throws {
    let files = try Self.makeFiles()
    defer { files.directory.remove() }
    let fixture = Self.makeFixture(for: files.files[1], selected: files.files)

    #expect(
      fixture.registry.perform(AgentAttachmentVerb.revealAttachment.id, at: fixture.path, clicked: fixture.path))

    #expect(fixture.service.calls == Self.calls(of: .revealAttachment, on: files.files))
  }

  /// The selection gives no files to the scope of a file that it does not
  /// hold (``AttachmentCommandFiles``).
  @Test func aCommandOnAFileOutsideTheSelectionRunsOnThatFileAlone() throws {
    let files = try Self.makeFiles()
    defer { files.directory.remove() }
    let fixture = Self.makeFixture(for: files.files[1], selected: [])

    #expect(fixture.registry.perform(AgentAttachmentVerb.openAttachment.id, at: fixture.path))

    #expect(fixture.service.calls == Self.calls(of: .openAttachment, on: [files.files[1]]))
  }

  /// Reveal in Finder needs a local file, so a selection with a web URL
  /// cannot reveal. Open also works on a web URL.
  @Test func aVerbThatOneSelectedFileCannotRunIsUnavailable() throws {
    let files = try Self.makeFiles()
    defer { files.directory.remove() }
    let web = AgentViewKit.Attachment(url: try #require(AgentAttachmentCommandsTests.webURL))
    let fixture = Self.makeFixture(for: files.files[0], selected: [files.files[0], web])

    let enabled = fixture.registry.contextMenuMirror(at: fixture.path).filter(\.isEnabled).map(\.id)

    #expect(enabled == [AgentAttachmentVerb.openAttachment, .shareAttachment].map(\.id))
  }

  @Test func aCommandThatOneSelectedFileCannotRunRunsOnNoFile() throws {
    let files = try Self.makeFiles()
    defer { files.directory.remove() }
    try FileManager.default.removeItem(at: files.files[2].url)
    let fixture = Self.makeFixture(for: files.files[0], selected: files.files)

    #expect(!fixture.registry.perform(AgentAttachmentVerb.openAttachment.id, at: fixture.path))

    #expect(fixture.service.calls.isEmpty)
  }
}
