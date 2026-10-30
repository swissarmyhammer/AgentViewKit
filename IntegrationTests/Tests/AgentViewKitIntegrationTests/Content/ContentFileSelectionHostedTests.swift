import AgentViewKitTestSupport
import EditorCommands
import EditorCommandsUI
import EditorTestSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing
import UniformTypeIdentifiers

@testable import AgentViewKit

/// A file in tool call content or in message content selects into the
/// inspector, as a message attachment does: a blob resource, a resource link
/// to a `file:` URL, and each location of a tool call. Each one keeps the
/// attachment commands in its context menu.
@Suite(.serialized, .hostedSerially) @MainActor struct ContentFileSelectionHostedTests {
  /// The size of a view that shows one block or one tool call.
  static let hostSize = CGSize(width: 600, height: 600)

  /// The id that each block view in the tests uses.
  static let blockID = "file-block-0"

  /// The URI of the blob resource in the tests.
  static let blobURI = "file:///data/archive.zip"

  /// The file name of the blob resource in the tests.
  static let blobName = "archive.zip"

  /// The bytes of the blob resource in the tests.
  static let blobBytes = Data([4, 5, 6, 7])

  /// The name of the file that the link and the location tests make. Its
  /// type has no preview, so the attachment view shows the chip.
  static let fileName = "blob.bin"

  /// The `toolCallId` of the tool call in the location tests.
  static let toolCallID = "location-call"

  /// The session id of the thread in the host mode test.
  static let hostSessionID = SessionId(rawValue: "host-thread")

  /// The attachment of the kit. FoundationModelsACP has a type of the same
  /// name.
  typealias Attachment = AgentViewKit.Attachment

  /// The suite whose helpers the blob tests use.
  typealias Blocks = WireContentBlockViewHostedTests

  // MARK: - Blob resource

  /// The blob writes its file, then shows in an ``AttachmentView``. A press
  /// selects the block file in the inspector.
  @Test func aPressOnABlobResourceSelectsItsFileInTheInspector() async throws {
    let selection = InspectorSelection()
    let writes = ReportRecorder<PreviewLoadState<URL>>()
    let harness = HostedViewHarness(
      ContentBlockView(block: Self.makeBlobBlock(), id: Self.blockID)
        .environment(\.inspectorSelection, selection)
        .environment(\.resourceFileReport, writes.report),
      size: Self.hostSize)
    defer { harness.close() }
    await harness.render { writes.values.contains(where: Blocks.isLoaded) }

    try harness.press(identifier: AttachmentView.identifier(for: .chip))

    let attachment = try #require(selection.attachment)
    #expect(attachment == Self.blobAttachment)
    #expect(try Data(contentsOf: attachment.url) == Self.blobBytes)
  }

  @Test func aBlobResourceKeepsTheAttachmentCommandsInItsContextMenu() async throws {
    let writes = ReportRecorder<PreviewLoadState<URL>>()
    let block = ContentBlockView(block: Self.makeBlobBlock(), id: Self.blockID)
      .environment(\.resourceFileReport, writes.report)

    let menu = await Self.contextMenuIDs(of: block, at: Self.blobAttachment.id) {
      writes.values.contains(where: Blocks.isLoaded)
    }

    #expect(menu == AttachmentFixtures.verbIDs)
  }

  // MARK: - Resource link

  @Test func aPressOnAFileResourceLinkSelectsTheFileInTheInspector() throws {
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    defer { directory.remove() }
    let url = try directory.write(Self.fileName, contents: Self.blobBytes)
    let selection = InspectorSelection()
    let harness = HostedViewHarness(
      ContentBlockView(block: Self.makeLinkBlock(to: url), id: Self.blockID)
        .environment(\.inspectorSelection, selection),
      size: Self.hostSize)
    defer { harness.close() }
    harness.render()
    #expect(harness.element(identifier: LinkView.cardIdentifier) == nil)

    try harness.press(identifier: AttachmentView.identifier(for: .chip))

    #expect(selection.attachment == Attachment(url: url))
  }

  /// In the host mode of a thread view, a press on a `file:` link writes the
  /// file to the binding of the host, with the session id of the thread.
  @Test func aPressOnAFileResourceLinkSelectsTheFileInTheInspectorOfTheHost() throws {
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    defer { directory.remove() }
    let url = try directory.write(Self.fileName, contents: Self.blobBytes)
    let state = HostAttachmentState()
    let target = HostAttachmentTarget(
      selection: Binding(get: { state.selection }, set: { state.selection = $0 }), sessionId: Self.hostSessionID)
    let harness = HostedViewHarness(
      ContentBlockView(block: Self.makeLinkBlock(to: url), id: Self.blockID)
        .environment(\.hostAttachmentTarget, target),
      size: Self.hostSize)
    defer { harness.close() }
    harness.render()

    try harness.press(identifier: AttachmentView.identifier(for: .chip))

    #expect(state.selection == AgentAttachmentSelection(attachment: Attachment(url: url), sessionId: Self.hostSessionID))
  }

  @Test func aFileResourceLinkKeepsTheAttachmentCommandsInItsContextMenu() async throws {
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    defer { directory.remove() }
    let url = try directory.write(Self.fileName, contents: Self.blobBytes)

    let menu = await Self.contextMenuIDs(
      of: ContentBlockView(block: Self.makeLinkBlock(to: url), id: Self.blockID), at: Attachment(url: url).id)

    #expect(menu == AttachmentFixtures.verbIDs)
  }

  @Test func aResourceLinkThatIsNotAFileStaysALinkCard() throws {
    let link = FoundationModelsACP.ResourceLink(name: "Guide", uri: "https://example.com/guide.html")
    let harness = HostedViewHarness(
      ContentBlockView(block: .resourceLink(link), id: Self.blockID), size: Self.hostSize)
    defer { harness.close() }
    harness.render()

    #expect(harness.element(identifier: LinkView.cardIdentifier) != nil)
    #expect(harness.element(identifier: AttachmentView.identifier(for: .chip)) == nil)
  }

  // MARK: - Tool call locations

  @Test func aPressOnALocationOfAToolCallSelectsItsFileInTheInspector() async throws {
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    defer { directory.remove() }
    let url = try directory.write(Self.fileName, contents: Self.blobBytes)
    let (session, call) = try await Self.openLocationCall(path: url.path(percentEncoded: false))
    defer { session.close() }
    let selection = InspectorSelection()
    let harness = HostedViewHarness(
      Self.expandedView(of: call).environment(\.inspectorSelection, selection), size: Self.hostSize)
    defer { harness.close() }
    harness.render()

    try harness.press(identifier: ToolCallView.locationIdentifier(for: call.id.rowKey, index: 0))

    #expect(selection.attachment == Attachment(url: url))
  }

  @Test func aLocationOfAToolCallKeepsTheAttachmentCommandsInItsContextMenu() async throws {
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    defer { directory.remove() }
    let url = try directory.write(Self.fileName, contents: Self.blobBytes)
    let (session, call) = try await Self.openLocationCall(path: url.path(percentEncoded: false))
    defer { session.close() }

    let menu = await Self.contextMenuIDs(of: Self.expandedView(of: call), at: Attachment(url: url).id)

    #expect(menu == AttachmentFixtures.verbIDs)
  }

  // MARK: - Helpers

  /// The attachment of the block file of the blob resource of the tests.
  static var blobAttachment: Attachment {
    ContentBlockFile.attachment(of: blobBytes, named: blobName, type: .zip)
  }

  /// Makes the blob resource block of the tests.
  ///
  /// - Returns: A resource block with the bytes of ``blobBytes``.
  static func makeBlobBlock() -> FoundationModelsACP.ContentBlock {
    .resource(
      FoundationModelsACP.EmbeddedResource(
        resource: .object([
          "uri": .string(blobURI), "mimeType": .string("application/zip"),
          "blob": .string(blobBytes.base64EncodedString()),
        ])))
  }

  /// Makes a resource link block to a file.
  ///
  /// - Parameter url: The `file:` URL of the file.
  /// - Returns: The link block.
  static func makeLinkBlock(to url: URL) -> FoundationModelsACP.ContentBlock {
    .resourceLink(FoundationModelsACP.ResourceLink(name: url.lastPathComponent, uri: url.absoluteString))
  }

  /// Opens a scripted session and sends one tool call with one location.
  ///
  /// - Parameter path: The path of the location.
  /// - Returns: The session and the entry of the call.
  /// - Throws: The error of the transport.
  static func openLocationCall(path: String) async throws -> (ScriptedSession, ToolCallEntry) {
    let fields = #""title": "Read the file", "kind": "read", "status": "completed", "locations": [{"path": "\#(path)"}]"#
    return try await ScriptedSession.openWithEntry(
      update: WireBlockJSON.makeToolCallUpdate(id: toolCallID, fields: fields),
      lookingUp: { model in
        model.transcript.lazy.compactMap { entry in
          if case .toolCall(let call) = entry { call } else { nil }
        }.first
      })
  }

  /// The view of a tool call with its body expanded.
  ///
  /// - Parameter call: The tool call entry.
  /// - Returns: The view.
  static func expandedView(of call: ToolCallEntry) -> some View {
    let store = ExpandedBlocksStore()
    store.expand(entry: .toolCall(call))
    return ToolCallView(entry: call).environment(\.expandedBlocksStore, store)
  }

  /// Mounts `content` with a command system, waits for `condition`, and gives
  /// the ids of the context menu of the attachment scope of `id`.
  ///
  /// - Parameters:
  ///   - content: The view to mount.
  ///   - id: The id of the attachment of the scope.
  ///   - condition: The condition on observable values to wait for before
  ///     the ids are read. The default holds at once.
  /// - Returns: The ids of the context menu at `agentAttachment:<id>`.
  static func contextMenuIDs(
    of content: some View, at id: AttachmentID, when condition: @MainActor () -> Bool = { true }
  ) async -> [CommandID] {
    let system = CommandSystem()
    let harness = HostedViewHarness(content.commandSystem(system), size: hostSize)
    defer { harness.close() }
    await harness.render(when: condition)
    return system.registry.contextMenuMirror(at: FocusPath.root(AgentScopeKind.attachment(id))).map(\.id)
  }
}
