@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorCommands
import EditorCommandsUI
import Foundation
import FoundationModelsACPClient
import Testing

/// Tests for the attachment verbs as EditorKit commands, with no window
/// (AVK-11, D108).
///
/// Each test registers the commands with ``AgentAttachmentRegistration``, as
/// the mount of an attachment scope does, in a registry with no window. The
/// scope node at the path of the attachment gives the attachment as its
/// subject, as `.commandScope(segment:subject:)` does. A run goes to a
/// ``RecordingAttachmentFileService``, so no system service opens.
@MainActor struct AgentAttachmentCommandsTests {
  /// The raw session id of the thread scope of the tests.
  static let sessionID = "attachment-thread"

  /// The row key of the message scope of the tests.
  static let messageRowKey = "message-1"

  /// The URL of an attachment that is not a local file.
  static let webURL = URL(string: "https://example.com/report.pdf")

  /// The objects of one registration test.
  struct Fixture {
    /// The target of the scope.
    let target: AgentAttachmentTarget
    /// The service that records each run.
    let service: RecordingAttachmentFileService
    /// The registry with the scope.
    var registry: CommandRegistry
    /// The path of the attachment scope.
    let path: FocusPath
  }

  /// The path of the thread scope that holds the attachment scope.
  static var threadPath: FocusPath {
    .root(FocusSegment(kind: AgentScopeKind.thread, id: sessionID))
  }

  /// Registers the attachment commands of `attachment` at a path in the scope
  /// of a message of a thread.
  ///
  /// - Parameters:
  ///   - attachment: The subject of the attachment scope.
  ///   - groupsOff: The groups that the registration does not register.
  /// - Returns: The fixture.
  static func makeFixture(
    for attachment: AgentViewKit.Attachment, groupsOff: Set<AgentCommandGroup> = []
  ) -> Fixture {
    let service = RecordingAttachmentFileService()
    let target = AgentAttachmentTarget()
    target.service = service
    let segment = AgentScopeKind.attachment(attachment.id)
    let path = threadPath.appending(AgentScopeKind.message(rowKey: messageRowKey)).appending(segment)
    var registry = CommandRegistry()
    registry.tree = registry.tree.merging({ $0.contributeSubject(segment, attachment) }, by: .scope, at: path)
    AgentAttachmentRegistration.register(target, at: path, into: &registry, groupsOff: groupsOff)
    return Fixture(target: target, service: service, registry: registry, path: path)
  }

  /// The text of a static title.
  ///
  /// - Parameter title: The title of a definition.
  /// - Returns: The text, or `nil` when the title is not static.
  static func staticText(of title: CommandTitle) -> String? {
    if case .static(let text) = title { text } else { nil }
  }

  // MARK: - Verbs

  @Test func eachVerbHasTheKitPrefixAndATitle() {
    for verb in AgentAttachmentVerb.allCases {
      #expect(verb.id.rawValue == "agent.\(verb.rawValue)")
      #expect(!verb.title.isEmpty, "\(verb)")
    }
  }

  @Test func eachVerbIsInTheAttachmentGroup() {
    for verb in AgentAttachmentVerb.allCases {
      #expect(verb.group == .attachment, "\(verb)")
    }
    #expect(AgentCommandGroup.attachment.id == "agent.attachment")
    #expect(AgentCommandGroup.attachment.attachmentVerbs == AgentAttachmentVerb.allCases)
  }

  /// The verbs are in the File menu and in the context menu, in the order of
  /// the buttons.
  @Test func eachVerbIsInTheFileMenuAndTheContextMenuInButtonOrder() {
    let verbs = AgentAttachmentVerb.allCases
    for verb in verbs {
      #expect(verb.menu.path == .file, "\(verb)")
    }
    #expect(verbs.map(\.menu.order) == verbs.indices.map(Double.init))
    #expect(verbs.map(\.contextMenu.order) == verbs.indices.map(Double.init))
  }

  // MARK: - Registration

  @Test func eachVerbIsInTheDefinitionsAtTheAttachmentPath() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let fixture = Self.makeFixture(for: try AttachmentFixtures.attachment(named: "blob.bin", in: directory))

    let ids = fixture.registry.definitions(at: fixture.path).map(\.id)

    #expect(Set(ids) == Set(AttachmentFixtures.verbIDs))
    #expect(ids.count == AgentAttachmentVerb.allCases.count)
  }

  @Test func theDefinitionsCarryThePlacesAndTheIcons() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let fixture = Self.makeFixture(for: try AttachmentFixtures.attachment(named: "blob.bin", in: directory))

    for verb in AgentAttachmentVerb.allCases {
      let definition = try #require(fixture.registry.definition(for: verb.id, at: fixture.path))
      #expect(Self.staticText(of: definition.title) == verb.title, "\(verb)")
      #expect(definition.icon == verb.icon, "\(verb)")
      #expect(definition.menu == verb.menu, "\(verb)")
      #expect(definition.contextMenu == verb.contextMenu, "\(verb)")
    }
  }

  @Test func noVerbIsAvailableAtAPathOutsideTheAttachmentScope() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let fixture = Self.makeFixture(for: try AttachmentFixtures.attachment(named: "blob.bin", in: directory))
    let messagePath = Self.threadPath.appending(AgentScopeKind.message(rowKey: Self.messageRowKey))

    for path in [Self.threadPath, messagePath] {
      let eligibleIDs = Set(fixture.registry.eligible(path: path).map(\.id))
      #expect(fixture.registry.definitions(at: path).isEmpty, "\(path)")
      #expect(eligibleIDs.isDisjoint(with: AttachmentFixtures.verbIDs), "\(path)")
      for verb in AgentAttachmentVerb.allCases {
        #expect(!fixture.registry.perform(verb.id, at: path), "\(verb) at \(path)")
      }
    }
    #expect(fixture.service.calls.isEmpty)
  }

  @Test func theContextMenuOfAnAttachmentShowsTheFiveVerbs() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let fixture = Self.makeFixture(for: try AttachmentFixtures.attachment(named: "blob.bin", in: directory))

    let items = fixture.registry.contextMenuMirror(at: fixture.path)

    #expect(items.map(\.id) == AttachmentFixtures.verbIDs)
    #expect(items.allSatisfy { $0.isEnabled })
  }

  /// The thread verbs of a message, such as Copy Message, do not show in the
  /// context menu of an attachment in that message.
  @Test func theContextMenuOfAnAttachmentInAThreadShowsNoMessageVerb() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    var fixture = Self.makeFixture(for: try AttachmentFixtures.attachment(named: "blob.bin", in: directory))
    let session = SessionModel.preview(requestSender: PreviewSessionRequestSender())
    let threadTarget = AgentCommandTarget()
    threadTarget.session = session
    AgentCommandRegistration.register(threadTarget, at: Self.threadPath, into: &fixture.registry)

    let ids = fixture.registry.contextMenuMirror(at: fixture.path).map(\.id)

    #expect(ids == AttachmentFixtures.verbIDs)
  }

  @Test func aGroupThatIsOffRegistersNoAttachmentVerb() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let fixture = Self.makeFixture(
      for: try AttachmentFixtures.attachment(named: "blob.bin", in: directory), groupsOff: [.attachment])

    #expect(fixture.registry.definitions(at: fixture.path).isEmpty)
    #expect(fixture.registry.contextMenuMirror(at: fixture.path).isEmpty)
  }

  @Test func theDeregistrationRemovesEachVerb() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    var fixture = Self.makeFixture(for: try AttachmentFixtures.attachment(named: "blob.bin", in: directory))

    AgentAttachmentRegistration.deregister(at: fixture.path, from: &fixture.registry)

    #expect(fixture.registry.definitions(at: fixture.path).isEmpty)
    #expect(!fixture.registry.perform(AgentAttachmentVerb.openAttachment.id, at: fixture.path))
  }

  // MARK: - Runs

  @Test func aRunOfEachVerbGivesTheAttachmentOfTheScopeToTheService() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try AttachmentFixtures.attachment(named: "blob.bin", in: directory)
    let fixture = Self.makeFixture(for: attachment)

    for verb in AgentAttachmentVerb.allCases {
      #expect(fixture.registry.perform(verb.id, at: fixture.path, clicked: fixture.path), "\(verb)")
    }

    #expect(
      fixture.service.calls
        == AgentAttachmentVerb.allCases.map { RecordingAttachmentFileService.Call(verb: $0, attachment: attachment) })
  }

  /// A button dispatches through the target, which runs the command at the
  /// path of its scope.
  @Test func theTargetRunsAVerbThroughTheRegistryOfItsScope() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try AttachmentFixtures.attachment(named: "blob.bin", in: directory)
    let fixture = Self.makeFixture(for: attachment)
    let system = CommandSystem()
    system.registry = fixture.registry
    fixture.target.system = system
    fixture.target.path = fixture.path

    #expect(fixture.target.perform(.revealAttachment))

    #expect(fixture.service.calls == [.init(verb: .revealAttachment, attachment: attachment)])
  }

  // MARK: - Availability

  /// Reveal in Finder, Save and Quick Look need a local file. Open and Share
  /// also work on a web URL.
  @Test func onlyOpenAndShareAreAvailableForAURLThatIsNotAFile() throws {
    let url = try #require(Self.webURL)
    let fixture = Self.makeFixture(for: AgentViewKit.Attachment(url: url))

    let enabled = fixture.registry.contextMenuMirror(at: fixture.path).filter(\.isEnabled).map(\.id)

    #expect(enabled == [AgentAttachmentVerb.openAttachment, .shareAttachment].map(\.id))
    #expect(!fixture.registry.perform(AgentAttachmentVerb.revealAttachment.id, at: fixture.path))
    #expect(fixture.service.calls.isEmpty)
  }

  @Test func noVerbIsAvailableForAFileThatDoesNotExist() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try AttachmentFixtures.attachment(named: "gone.bin", in: directory)
    try FileManager.default.removeItem(at: attachment.url)
    let fixture = Self.makeFixture(for: attachment)

    let items = fixture.registry.contextMenuMirror(at: fixture.path)

    #expect(items.map(\.id) == AttachmentFixtures.verbIDs)
    #expect(!items.contains { $0.isEnabled })
  }

  @Test func noVerbIsAvailableWithNoService() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let fixture = Self.makeFixture(for: try AttachmentFixtures.attachment(named: "blob.bin", in: directory))
    fixture.target.service = nil

    #expect(!fixture.registry.contextMenuMirror(at: fixture.path).contains { $0.isEnabled })
  }
}
