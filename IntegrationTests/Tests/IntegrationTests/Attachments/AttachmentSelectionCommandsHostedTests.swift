import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import EditorTestSupport
import Foundation
import SwiftUI
import Testing

@testable import AgentViewKit

/// Hosted tests of the attachment commands over the selection of several
/// files in a thread view (card ^zsr2pbf).
///
/// The composer slot of the thread view shows the location chips of three
/// files in one row, so the transcript order of the files is the order of
/// the chips. Each test selects files through the named accessibility
/// actions of the chips, Select, Add to Selection and Extend Selection, then
/// runs a command on one chip, as a row of its context menu or a key runs
/// it. A row of the context menu runs its command at the path of the chip
/// with that path as the clicked path, and a key runs its command at the
/// focused path with no click. The view gives each run to a
/// ``RecordingAttachmentFileService``, the hook of a host, so no system UI
/// opens. The window is never ordered in and never key, and no test clicks.
@Suite(.serialized, .hostedSerially) @MainActor struct AttachmentSelectionCommandsHostedTests {
  /// The size of a host window with a thread and an inspector.
  static let hostSize = CGSize(width: 1_200, height: 700)

  /// The key that the keyboard tests bind to the command under test.
  static let key = KeyChord.return

  /// The scripted session of the thread view.
  let session: ScriptedSession

  /// The files of the chips, in transcript order, and their folder.
  let fileSet: AttachmentFileSet

  /// The state of the host.
  let state = HostAttachmentState()

  /// The hook of the host that records each run of a command.
  let service = RecordingAttachmentFileService()

  /// The command system of the window.
  let system = CommandSystem()

  init() async throws {
    fileSet = try AttachmentFileSet()
    session = try await ScriptedSession.open()
  }

  /// The files of the chips, in transcript order.
  var files: [AgentViewKit.Attachment] {
    fileSet.files
  }

  /// The accessibility identifier of the chip of a file.
  ///
  /// - Parameter index: The position of the file in
  ///   ``AttachmentFileSet/selectionNames``.
  /// - Returns: The identifier.
  static func chip(_ index: Int) -> String {
    "selection-command-chip-\(index)"
  }

  /// Mounts the thread view in the host mode, with the chips in its composer
  /// slot, and makes one render pass.
  ///
  /// - Returns: The harness. The caller closes it.
  func mount() -> HostedViewHarness<some View> {
    mount { $0.agentAttachmentInspector(.host(Bindable(state).selection)) }
  }

  /// Mounts the thread view with the chips in its composer slot, the
  /// recording hook and the command system of the test, applies `mode` to
  /// the thread view, and makes one render pass.
  ///
  /// - Parameter mode: The function that gives the inspector mode to the
  ///   thread view.
  /// - Returns: The harness. The caller closes it.
  func mount<Mounted: View>(
    @ViewBuilder mode: (AgentThreadView<ToolCallLocationChips>) -> Mounted
  ) -> HostedViewHarness<some View> {
    let locations = files.indices.map { index in
      ToolCallLocationChips.Location(
        path: files[index].url.path(percentEncoded: false), line: nil, identifier: Self.chip(index))
    }
    let harness = HostedViewHarness(
      mode(
        AgentThreadView(session: session.model, connection: session.connection) {
          ToolCallLocationChips(locations: locations)
        }
      )
      .environment(\.attachmentFileService, service)
      .commandSystem(system),
      size: Self.hostSize)
    harness.render()
    return harness
  }

  /// The path of the attachment scope of the chip of a file.
  ///
  /// - Parameter index: The position of the file.
  /// - Returns: The path.
  /// - Throws: The error of `#require` when no scope of the file is in the
  ///   registry.
  func path(of index: Int) throws -> FocusPath {
    let segment = AgentScopeKind.attachment(files[index].id)
    return try #require(system.registry.tree.nodes.map(\.path).first { $0.segments.last == segment })
  }

  /// Runs `verb` as the row of the context menu of the chip of a file runs
  /// it, after it requires that the menu shows the row enabled.
  ///
  /// - Parameters:
  ///   - verb: The verb of the row.
  ///   - index: The position of the file.
  ///   - harness: The harness of the mounted view.
  /// - Throws: The error of the read of the menu, or of `#require`.
  func runContextMenuRow(
    _ verb: AgentAttachmentVerb, on index: Int, in harness: HostedViewHarness<some View>
  ) throws {
    let rows = try harness.contextMenuItems(of: Self.chip(index))
    try #require(rows.contains { $0.commandID == verb.id && $0.isEnabled })
    let path = try path(of: index)
    try #require(system.registry.perform(verb.id, at: path, clicked: path))
  }

  /// Runs `verb` as a key bound to it at the chip of a file runs it, with
  /// the chip as the focused place.
  ///
  /// - Parameters:
  ///   - verb: The verb of the key.
  ///   - index: The position of the file.
  /// - Throws: The error of `#require`.
  func runKey(_ verb: AgentAttachmentVerb, on index: Int) throws {
    let path = try path(of: index)
    system.registry.bindKey(Self.key.asSequence, to: .command(verb.id), mode: .cua, at: path)
    try #require(system.registry.performKey(Self.key.asSequence, mode: .cua, at: path))
  }

  /// Closes the session and removes the files.
  func close() {
    session.close()
    fileSet.remove()
  }

  @Test func theOpenRowOfASelectedFileOpensEverySelectedFileInTranscriptOrder() throws {
    defer { close() }
    let harness = mount()
    defer { harness.close() }
    try harness.performSelection(.select, on: Self.chip(2))
    try harness.performSelection(.toggle, on: Self.chip(0))
    try harness.performSelection(.toggle, on: Self.chip(1))

    try runContextMenuRow(.openAttachment, on: 2, in: harness)

    #expect(service.calls == AttachmentFixtures.calls(of: .openAttachment, on: files))
  }

  @Test func aKeyOnASelectedFileRevealsEverySelectedFile() throws {
    defer { close() }
    let harness = mount()
    defer { harness.close() }
    try harness.performSelection(.select, on: Self.chip(0))
    try harness.performSelection(.extend, on: Self.chip(2))

    try runKey(.revealAttachment, on: 1)

    #expect(service.calls == AttachmentFixtures.calls(of: .revealAttachment, on: files))
  }

  @Test func theOpenRowOfAFileOutsideTheSelectionOpensThatFileAlone() throws {
    defer { close() }
    let harness = mount()
    defer { harness.close() }
    try harness.performSelection(.select, on: Self.chip(0))
    try harness.performSelection(.toggle, on: Self.chip(2))

    try runContextMenuRow(.openAttachment, on: 1, in: harness)

    #expect(service.calls == AttachmentFixtures.calls(of: .openAttachment, on: [files[1]]))
  }

  @Test func aKeyOnAFileOutsideTheSelectionRunsOnThatFileAlone() throws {
    defer { close() }
    let harness = mount()
    defer { harness.close() }
    try harness.performSelection(.select, on: Self.chip(0))
    try harness.performSelection(.toggle, on: Self.chip(2))

    try runKey(.quickLookAttachment, on: 1)

    #expect(service.calls == AttachmentFixtures.calls(of: .quickLookAttachment, on: [files[1]]))
  }

  /// The context menu of an item leaves out a command that is not available
  /// (``ContextMenuUnavailablePolicy/agentItem``). On a selected file, Open
  /// is not available when one of the selected files is gone.
  @Test func theContextMenuOfASelectedFileLeavesOutARowThatOneSelectedFileCannotRun() throws {
    defer { close() }
    let harness = mount()
    defer { harness.close() }
    let open = AgentAttachmentVerb.openAttachment.id
    try harness.performSelection(.select, on: Self.chip(0))
    try harness.performSelection(.extend, on: Self.chip(2))
    try #require(try harness.contextMenuItems(of: Self.chip(0)).contains { $0.commandID == open })
    try FileManager.default.removeItem(at: files[2].url)

    let rows = try harness.contextMenuItems(of: Self.chip(0))

    #expect(!rows.contains { $0.commandID == open })
  }

  /// In the built-in mode, the inspector selection of the thread view holds
  /// the selected files.
  @Test func theOpenRowOfASelectedFileInTheBuiltInModeOpensEverySelectedFile() throws {
    defer { close() }
    let selection = InspectorSelection()
    let harness = mount { $0.environment(\.inspectorSelection, selection) }
    defer { harness.close() }
    try harness.performSelection(.select, on: Self.chip(1))
    try harness.performSelection(.extend, on: Self.chip(2))
    try #require(selection.attachments == [files[1], files[2]])

    try runContextMenuRow(.openAttachment, on: 1, in: harness)

    #expect(service.calls == AttachmentFixtures.calls(of: .openAttachment, on: Array(files[1...2])))
  }
}
