import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import EditorTestSupport
import Foundation
import SwiftUI
import Testing
import UniformTypeIdentifiers

@testable import AgentViewKit

/// A host of TestudoApp in the host inspector mode: a thread view with a chip
/// in its composer slot, and the inspector of the host, which shows the
/// selected file in an ``AttachmentInspector``.
struct HostInspectorWithAttachmentActions: View {
  /// The scripted session that the thread view shows.
  let session: ScriptedSession

  /// The attachment of the chip.
  let attachment: AgentViewKit.Attachment

  /// The state of the host.
  @Bindable var state: HostAttachmentState

  var body: some View {
    AgentThreadView(session: session.model, connection: session.connection) {
      AttachmentView(attachment)
    }
    .inspector(isPresented: .constant(true)) {
      if let selection = state.selection {
        AttachmentInspector(selection.attachment)
      }
    }
    .agentAttachmentInspector(.host($state.selection))
  }
}

/// Hosted tests of the attachment commands in the real views (AVK-11).
///
/// Each view gets a ``RecordingAttachmentFileService`` through the
/// environment, so a press runs the command and opens no system UI. A press
/// on a button runs the command in the same step, so the test reads the
/// recorder at once.
///
/// The built-in inspector test uses the order of
/// ``AttachmentInspectorHostedTests/aPressOnAChipShowsTheInspectorItemOfTheSplitView()``:
/// the press, the fence of the run loop blocks, and one render pass. The
/// inspector of the host is open from the mount, so one render pass after
/// the press shows the new content.
@Suite(.serialized, .hostedSerially) @MainActor struct AttachmentCommandsHostedTests {
  /// The suite whose helpers the tests use.
  typealias Shared = AttachmentInspectorHostedTests

  /// The suite that holds the one definition of the verb ids.
  typealias Commands = AgentAttachmentCommandsTests

  /// The size of a view with one attachment.
  static let viewSize = CGSize(width: 600, height: 400)

  /// The calls that a press on each button gives, in the order of the
  /// buttons.
  ///
  /// - Parameter attachment: The attachment of the buttons.
  /// - Returns: One call for each verb.
  static func callsOfEachVerb(on attachment: AgentViewKit.Attachment) -> [RecordingAttachmentFileService.Call] {
    AgentAttachmentVerb.allCases.map { .init(verb: $0, attachment: attachment) }
  }

  /// Presses each button whose identifier is in `identifiers`, in order.
  ///
  /// - Parameters:
  ///   - identifiers: The accessibility identifiers of the buttons.
  ///   - harness: The harness that shows the buttons.
  /// - Throws: The error of a press.
  static func pressEach(_ identifiers: [String], in harness: HostedViewHarness<some View>) throws {
    for identifier in identifiers {
      try harness.press(identifier: identifier)
    }
  }

  // MARK: - Inspector modes

  /// In the built-in mode, a press on each button of the inspector of a
  /// thread view runs the command of the button on the selected file.
  @Test func eachButtonOfTheBuiltInInspectorRunsItsCommand() async throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try Shared.attachment(named: "blob.bin", in: directory)
    let service = RecordingAttachmentFileService()
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = Shared.mountThreadView(of: session) {
      AttachmentView(attachment)
    } modifier: {
      $0.environment(\.attachmentFileService, service)
    }
    defer { harness.close() }
    try Shared.withoutAnimation {
      try harness.press(identifier: AttachmentView.identifier(for: .chip))
    }
    await RunLoopBlockFence.afterPendingBlocks()
    harness.render()
    try Shared.requireInspectorItem(in: harness, showsTheNameOf: "blob.bin")

    try Self.pressEach(AttachmentInspector.actionIdentifiers, in: harness)

    #expect(service.calls == Self.callsOfEachVerb(on: attachment))
  }

  /// In the host mode, the host shows the selected file in its own
  /// inspector with ``AttachmentInspector``. A press on each button runs the
  /// command of the button on that file.
  @Test func eachButtonOfTheInspectorOfTheHostRunsItsCommand() async throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try Shared.attachment(named: "blob.bin", in: directory)
    let service = RecordingAttachmentFileService()
    let state = HostAttachmentState()
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = HostedViewHarness(
      HostInspectorWithAttachmentActions(session: session, attachment: attachment, state: state)
        .environment(\.attachmentFileService, service),
      size: Shared.hostSize)
    defer { harness.close() }
    harness.render()
    try harness.press(identifier: AttachmentView.identifier(for: .chip))
    try #require(state.selection?.attachment == attachment)
    harness.render()
    try #require(harness.element(identifier: AttachmentInspector.nameIdentifier)?.label == "blob.bin")

    try Self.pressEach(AttachmentInspector.actionIdentifiers, in: harness)

    #expect(service.calls == Self.callsOfEachVerb(on: attachment))
  }

  // MARK: - Artifact

  @Test func eachButtonOfAnArtifactRunsItsCommand() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let url = try directory.file(named: "plan.txt", contents: Data(Shared.fileText.utf8))
    let artifact = ArtifactPayload(
      id: "artifact-1", title: "The plan", type: UTType.plainText.identifier, url: url)
    let service = RecordingAttachmentFileService()
    let harness = HostedViewHarness(
      ArtifactView(artifact: artifact).environment(\.attachmentFileService, service), size: Self.viewSize)
    defer { harness.close() }
    harness.render()

    try Self.pressEach(ArtifactView.actionIdentifiers, in: harness)

    #expect(service.calls.map(\.verb) == AgentAttachmentVerb.allCases)
    #expect(service.calls.allSatisfy { $0.attachment.url == url })
  }

  // MARK: - Scopes

  /// Mounts `content` with a command system and one render pass, and gives
  /// the ids of the commands at the root path of the scope of `id`.
  ///
  /// The scope is the root of the window, so EditorKit also registers the
  /// window undo commands there. The call expects them registered and
  /// unavailable, and leaves them out of the ids it gives.
  ///
  /// - Parameters:
  ///   - content: The view to mount.
  ///   - id: The id of the attachment of the scope.
  /// - Returns: The ids of the definitions of the kit at
  ///   `agentAttachment:<id>`, and the ids of its context menu.
  /// - Throws: The error of `#require` when the root has no undo stack.
  static func commandIDs(
    of content: some View, at id: AttachmentID
  ) throws -> (definitions: Set<CommandID>, contextMenu: [CommandID]) {
    let system = CommandSystem()
    let harness = HostedViewHarness(content.commandSystem(system), size: viewSize)
    defer { harness.close() }
    harness.render()
    let path = FocusPath.root(AgentScopeKind.attachment(id))
    try WindowUndoChecks.expectUnavailableOnAnEmptyStack(at: path, in: system)
    return (
      WindowUndoChecks.kitCommandIDs(at: path, in: system),
      system.registry.contextMenuMirror(at: path).map(\.id)
    )
  }

  @Test func aChipRegistersTheFiveCommandsAtItsScope() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try Shared.attachment(named: "blob.bin", in: directory)

    let ids = try Self.commandIDs(of: AttachmentView(attachment), at: attachment.id)

    #expect(ids.definitions == Set(Commands.verbIDs))
    #expect(ids.contextMenu == Commands.verbIDs)
  }

  @Test func aChipOfTheComposerRegistersTheFiveCommandsAtItsScope() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try Shared.attachment(named: "blob.bin", in: directory)

    let ids = try Self.commandIDs(of: AttachmentChip(attachment), at: attachment.id)

    #expect(ids.definitions == Set(Commands.verbIDs))
  }

  @Test func theInspectorRegistersTheFiveCommandsAtItsScope() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try Shared.attachment(named: "blob.bin", in: directory)

    let ids = try Self.commandIDs(of: AttachmentInspector(attachment), at: attachment.id)

    #expect(ids.definitions == Set(Commands.verbIDs))
  }

  /// An image is the scope of its block file. The id is the id of the
  /// attachment that ``ContentBlockFile`` gives to the bytes of the image.
  @Test func anImageRegistersTheFiveCommandsAtTheScopeOfItsFile() throws {
    let (png, image) = try TestImage.makePNGContent(uri: WireContentBlockViewHostedTests.imageURI)
    let file = ContentBlockFile.attachment(of: png, named: WireContentBlockViewHostedTests.imageName, type: .png)

    let ids = try Self.commandIDs(of: ImageView(image: image), at: file.id)

    #expect(ids.definitions == Set(Commands.verbIDs))
  }

  /// The chip of an ``AttachmentView`` is in the scope of the view, and makes
  /// no second scope for the same attachment.
  @Test func theChipOfAnAttachmentViewMakesNoSecondScope() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try Shared.attachment(named: "blob.bin", in: directory)
    let system = CommandSystem()
    let harness = HostedViewHarness(AttachmentView(attachment).commandSystem(system), size: Self.viewSize)
    defer { harness.close() }
    harness.render()

    let attachmentPaths = system.registry.tree.nodes.map(\.path).filter { path in
      path.segments.contains { $0.kind == AgentScopeKind.attachment }
    }

    #expect(attachmentPaths == [.root(AgentScopeKind.attachment(attachment.id))])
  }

  /// Two windows show the scope of one attachment, so both register at the
  /// same path, each with its own service. While both are open, a run goes to
  /// the service of the newer window. When the newer window closes, the path
  /// goes back to the older window on the next pass of the main run loop,
  /// with no update of the older window, and a run goes to the service of the
  /// older window.
  ///
  /// Each window shows the bare scope and no chip. The buttons of a chip
  /// read the registry, so a change of the registry updates the chip and its
  /// scope, and that update would register the older window again by itself.
  @Test func closingTheNewerOfTwoWindowsAtOnePathHandsTheCommandsBackToTheOlderWindow() async throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try Shared.attachment(named: "blob.bin", in: directory)
    let system = CommandSystem()
    let olderService = RecordingAttachmentFileService()
    let newerService = RecordingAttachmentFileService()
    let older = SwitchedWindow(
      Color.clear.agentAttachmentScope(attachment).environment(\.attachmentFileService, olderService),
      system: system, size: Self.viewSize)
    defer { older.harness.close() }
    let newer = SwitchedWindow(
      Color.clear.agentAttachmentScope(attachment).environment(\.attachmentFileService, newerService),
      system: system, size: Self.viewSize)
    let path = FocusPath.root(AgentScopeKind.attachment(attachment.id))
    let open = AgentAttachmentVerb.openAttachment
    let call = RecordingAttachmentFileService.Call(verb: open, attachment: attachment)
    try #require(system.registry.perform(open.id, at: path, clicked: path))
    try #require(newerService.calls == [call])

    await newer.close()

    #expect(WindowUndoChecks.kitCommandIDs(at: path, in: system) == Set(Commands.verbIDs))
    #expect(system.registry.perform(open.id, at: path, clicked: path))
    #expect(olderService.calls == [call])
    #expect(newerService.calls == [call])
  }

  /// With the attachment group off, the inspector shows no button and its
  /// scope registers no command of the kit. The scope is the root of the
  /// window, so the window undo commands of EditorKit stay there.
  @Test func theAttachmentGroupOffRemovesTheButtonsAndTheCommands() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try Shared.attachment(named: "blob.bin", in: directory)
    let system = CommandSystem()
    let harness = HostedViewHarness(
      AttachmentInspector(attachment).agentCommandGroups(off: [.attachment]).commandSystem(system),
      size: Self.viewSize)
    defer { harness.close() }
    harness.render()

    let path = FocusPath.root(AgentScopeKind.attachment(attachment.id))
    #expect(WindowUndoChecks.kitCommandIDs(at: path, in: system).isEmpty)
    try WindowUndoChecks.expectUnavailableOnAnEmptyStack(at: path, in: system)
    for identifier in AttachmentInspector.actionIdentifiers {
      #expect(harness.element(identifier: identifier) == nil, "\(identifier)")
    }
  }
}
