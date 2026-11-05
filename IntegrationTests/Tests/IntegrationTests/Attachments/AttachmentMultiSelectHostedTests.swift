import AgentViewKitTestSupport
import AppKit
import EditorTestSupport
import Foundation
import SwiftUI
import Testing

@testable import AgentViewKit

/// The inspector of a test host that folds the selected files of its binding
/// into one ``AttachmentInspector``, as TestudoApp's inspector does.
struct FoldingHostInspector: View {
  /// The state of the host.
  let state: HostAttachmentState

  var body: some View {
    if !state.selection.isEmpty {
      AttachmentInspector(state.selection.map(\.attachment))
    }
  }
}

/// Hosted tests of the selection of several files in a thread view in the
/// host mode (card ^4138tmp).
///
/// The composer slot of the thread view shows the location chips of three
/// files in one row, so the transcript order of the files is the order of
/// the chips. Each test drives a chip through its named accessibility
/// actions, Select, Add to Selection and Extend Selection, which do what a
/// click, a Command-click and a Shift-click do. The window is never ordered
/// in and never key, and no test clicks.
@Suite(.serialized, .hostedSerially) @MainActor struct AttachmentMultiSelectHostedTests {
  /// The file names of the chips, in transcript order.
  static let names = ["first.bin", "second.txt", "third.swift"]

  /// The size of a host window with a thread and an inspector.
  static let hostSize = CGSize(width: 1_200, height: 700)

  /// The scripted session of the thread view.
  let session: ScriptedSession

  /// The folder of the files.
  let directory: TemporaryFolder

  /// The files of the chips, in transcript order.
  let files: [AgentViewKit.Attachment]

  /// The state of the host.
  let state = HostAttachmentState()

  init() async throws {
    directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    let directory = directory
    files = try Self.names.map { try AttachmentFixtures.attachment(named: $0, in: directory) }
    session = try await ScriptedSession.open()
  }

  /// The accessibility identifier of the chip of a file.
  ///
  /// - Parameter index: The position of the file in ``names``.
  /// - Returns: The identifier.
  static func chip(_ index: Int) -> String {
    "multi-select-chip-\(index)"
  }

  /// Mounts the thread view in the host mode, with the chips in its composer
  /// slot and ``FoldingHostInspector`` as the inspector of the host, and
  /// makes one render pass.
  ///
  /// - Returns: The harness. The caller closes it.
  func mount() -> HostedViewHarness<some View> {
    let locations = files.indices.map { index in
      ToolCallLocationChips.Location(
        path: files[index].url.path(percentEncoded: false), line: nil, identifier: Self.chip(index))
    }
    let state = state
    let harness = HostedViewHarness(
      AgentThreadView(session: session.model, connection: session.connection) {
        ToolCallLocationChips(locations: locations)
      }
      .inspector(isPresented: .constant(true)) { FoldingHostInspector(state: state) }
      .agentAttachmentInspector(.host(Bindable(state).selection)),
      size: Self.hostSize)
    harness.render()
    return harness
  }

  /// Runs the named accessibility action of `change` on the chip of a file.
  ///
  /// - Parameters:
  ///   - change: The kind of the press.
  ///   - index: The position of the file.
  ///   - harness: The harness of the mounted view.
  /// - Throws: The error of the action.
  func perform(_ change: AttachmentSelectionChange, on index: Int, in harness: HostedViewHarness<some View>)
    throws
  {
    try harness.perform(.custom(change.actionName), on: Self.chip(index))
  }

  /// The selections of the files at `indices`, with the session id of the
  /// thread.
  ///
  /// - Parameter indices: The positions of the files.
  /// - Returns: The selections, in the order of `indices`.
  func selections(_ indices: Int...) -> [AgentAttachmentSelection] {
    indices.map { AgentAttachmentSelection(attachment: files[$0], sessionId: session.model.sessionId) }
  }

  /// Closes the session and removes the files.
  func close() {
    session.close()
    directory.remove()
  }

  @Test func theSelectActionSelectsOneFile() throws {
    defer { close() }
    let harness = mount()
    defer { harness.close() }

    try perform(.select, on: 1, in: harness)

    #expect(state.selection == selections(1))
  }

  @Test func theAddActionAddsAFileToTheSelection() throws {
    defer { close() }
    let harness = mount()
    defer { harness.close() }
    try perform(.select, on: 2, in: harness)

    try perform(.toggle, on: 0, in: harness)

    #expect(state.selection == selections(2, 0))
  }

  @Test func theAddActionOnASelectedFileTakesItOut() throws {
    defer { close() }
    let harness = mount()
    defer { harness.close() }
    try perform(.select, on: 2, in: harness)
    try perform(.toggle, on: 0, in: harness)

    try perform(.toggle, on: 2, in: harness)

    #expect(state.selection == selections(0))
  }

  @Test func theExtendActionSelectsTheRangeInTranscriptOrder() throws {
    defer { close() }
    let harness = mount()
    defer { harness.close() }
    try perform(.select, on: 0, in: harness)

    try perform(.extend, on: 2, in: harness)

    #expect(state.selection == selections(0, 1, 2))
  }

  @Test func theSelectActionReplacesASelectionOfSeveralFiles() throws {
    defer { close() }
    let harness = mount()
    defer { harness.close() }
    try perform(.select, on: 0, in: harness)
    try perform(.extend, on: 2, in: harness)

    try perform(.select, on: 1, in: harness)

    #expect(state.selection == selections(1))
  }

  /// The inspector of the host folds the selected files into one form: the
  /// preview row of the files reads "Mixed".
  @Test func theHostInspectorFoldsTheSelectedFilesWithMixedRows() throws {
    defer { close() }
    let harness = mount()
    defer { harness.close() }
    try perform(.select, on: 0, in: harness)
    try perform(.toggle, on: 2, in: harness)

    harness.render()

    #expect(harness.inspectorDriver.isMixed(AttachmentInspector.previewIdentifier(of: [files[0], files[2]])))
  }
}
