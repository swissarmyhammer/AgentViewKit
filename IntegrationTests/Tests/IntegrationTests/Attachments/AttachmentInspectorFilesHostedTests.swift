@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorInspectorTestSupport
import EditorTestSupport
import SwiftUI
import Testing

/// Hosted tests of an ``AttachmentInspector`` of several files (card
/// ^xbhtytm): its Files row lists the files, and each action of its action
/// row acts on every file.
///
/// The inspector gets a ``RecordingAttachmentFileService`` through the
/// environment, so a press opens no system UI. Each test drives the
/// inspector through accessibility with EditorKit's `InspectorDriver`: it
/// reads the chips of the Files row, opens a chip as VoiceOver's press does,
/// and presses an action by its title. No test clicks.
@Suite(.serialized, .hostedSerially) @MainActor struct AttachmentInspectorFilesHostedTests {
  /// The temporary files of the tests.
  let fileSet: AttachmentFileSet

  /// The service that records each run.
  let service = RecordingAttachmentFileService()

  init() throws {
    fileSet = try AttachmentFileSet()
  }

  /// The files of the inspector, in a selection order that is not the order
  /// of their names, so a row in name order fails.
  var selection: [AgentViewKit.Attachment] {
    let files = fileSet.files
    return [files[2], files[0], files[1]]
  }

  /// Mounts the inspector of `files` with the recording service, and makes
  /// one render pass.
  ///
  /// - Parameter files: The files of the inspector, in selection order.
  /// - Returns: The harness. The caller closes it.
  func mount(_ files: [AgentViewKit.Attachment]) -> HostedViewHarness<some View> {
    AttachmentInspectorRowsHostedTests.mount(AttachmentInspector(files).environment(\.attachmentFileService, service))
  }

  @Test func theFilesRowShowsAChipForEachFileInSelectionOrder() {
    defer { fileSet.remove() }
    let harness = mount(selection)
    defer { harness.close() }

    let chips = harness.inspectorDriver.pathChips(in: AttachmentInspector.filesIdentifier(of: selection))

    #expect(chips.compactMap(accessibilityValue(of:)) == selection.map { $0.url.path(percentEncoded: false) })
  }

  @Test func oneFileShowsNoFilesRow() throws {
    defer { fileSet.remove() }
    let file = try #require(selection.first)
    let harness = mount([file])
    defer { harness.close() }

    #expect(!harness.showsRow(AttachmentInspector.filesIdentifier(of: [file])))
  }

  @Test func openingAChipOpensItsFile() throws {
    defer { fileSet.remove() }
    let harness = mount(selection)
    defer { harness.close() }
    let index = selection.count - 1

    try harness.inspectorDriver.openPath(at: index, in: AttachmentInspector.filesIdentifier(of: selection))

    #expect(service.calls == AttachmentFixtures.calls(of: .openAttachment, on: [selection[index]]))
  }

  @Test(arguments: AgentAttachmentVerb.allCases)
  func eachActionRunsOnEveryFileInInspectorOrder(_ verb: AgentAttachmentVerb) throws {
    defer { fileSet.remove() }
    let harness = mount(selection)
    defer { harness.close() }

    try harness.inspectorDriver.pressAction(verb.buttonTitle ?? verb.title)

    #expect(service.calls == AttachmentFixtures.calls(of: verb, on: selection))
  }

  /// The availability of an action reads every file: with the last file of
  /// the inspector gone, the Open button is disabled, so its press does not
  /// take, and Open runs on no file, not on the files that are still there.
  @Test func anActionThatOneFileCannotRunIsDisabled() throws {
    defer { fileSet.remove() }
    let missing = try #require(selection.last)
    try FileManager.default.removeItem(at: missing.url)
    let harness = mount(selection)
    defer { harness.close() }

    #expect(throws: (any Error).self) {
      try harness.inspectorDriver.pressAction(AgentAttachmentVerb.openAttachment.title)
    }
    #expect(service.calls.isEmpty)
  }
}
