@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorInspectorTestSupport
import EditorTestSupport
import SwiftUI
import Testing

/// Hosted tests of an ``AttachmentInspector`` of several files: it shows one
/// full block for each file, in selection order, and the action row of each
/// block acts on the file of that block only.
///
/// The inspector gets a ``RecordingAttachmentFileService`` through the
/// environment, so a press opens no system UI. Each test drives the
/// inspector through accessibility with EditorKit's `InspectorDriver`: it
/// reads the name row of each block by its scheme id, and presses the button
/// of an action in one block as VoiceOver's press does. No test clicks.
@Suite(.serialized, .hostedSerially) @MainActor struct AttachmentInspectorFilesHostedTests {
  /// The names of the two files of the tests, each of another type.
  static let names = ["first.bin", "second.txt"]

  /// The height of a window that shows each row of the two blocks, in
  /// points: each block holds a preview at the preview height of the style.
  static let windowHeight: CGFloat = 1_000

  /// The size of the window of the tests.
  static let windowSize = CGSize(width: AttachmentInspectorHostedTests.hostSize.width, height: windowHeight)

  /// The temporary files of the tests.
  let fileSet: AttachmentFileSet

  /// The service that records each run.
  let service = RecordingAttachmentFileService()

  init() throws {
    fileSet = try AttachmentFileSet(named: Self.names)
  }

  /// The files of the inspector, in a selection order that is not the order
  /// of their names, so blocks in name order fail.
  var selection: [AgentViewKit.Attachment] {
    fileSet.files.reversed()
  }

  /// Mounts the inspector of ``selection`` with the recording service, and
  /// makes one render pass.
  ///
  /// - Returns: The harness. The caller closes it.
  func mount() -> HostedViewHarness<some View> {
    AttachmentInspectorRowsHostedTests.mount(
      AttachmentInspector(selection).environment(\.attachmentFileService, service), size: Self.windowSize)
  }

  /// The button of `verb` in each block of the inspector in `harness`, in
  /// the order of the blocks.
  ///
  /// - Parameters:
  ///   - verb: The verb of the buttons.
  ///   - harness: The harness that shows the inspector.
  /// - Returns: The live accessibility element of each button.
  static func buttons<Content: View>(of verb: AgentAttachmentVerb, in harness: HostedViewHarness<Content>)
    -> [NSObject]
  {
    harness.inspectorDriver.elements(verb.identifier(prefix: AttachmentInspector.identifierPrefix))
  }

  /// Presses the button of `verb` in the block at `index`, as VoiceOver's
  /// press does, then makes one render pass.
  ///
  /// - Parameters:
  ///   - verb: The verb of the button.
  ///   - index: The position of the block.
  ///   - harness: The harness that shows the inspector.
  /// - Throws: An issue when the inspector has no block at `index`, or the
  ///   error of a press that does not take.
  static func press<Content: View>(_ verb: AgentAttachmentVerb, inBlock index: Int, of harness: HostedViewHarness<Content>)
    throws
  {
    let buttons = buttons(of: verb, in: harness)
    try #require(buttons.indices.contains(index), "The inspector has \(buttons.count) buttons of \(verb).")
    try AccessibilityAction.press.perform(
      on: buttons[index], identifiedAs: verb.identifier(prefix: AttachmentInspector.identifierPrefix))
    harness.render()
  }

  @Test func eachBlockHasTheNameRowOfItsFile() {
    defer { fileSet.remove() }
    let harness = mount()
    defer { harness.close() }

    let names = selection.map { harness.rowValue(AttachmentInspector.nameIdentifier(of: $0)) }

    #expect(names == selection.map(\.name))
  }

  @Test(arguments: AgentAttachmentVerb.allCases)
  func theActionOfEachBlockRunsOnTheFileOfThatBlockOnly(_ verb: AgentAttachmentVerb) throws {
    defer { fileSet.remove() }
    let harness = mount()
    defer { harness.close() }

    for index in selection.indices {
      try Self.press(verb, inBlock: index, of: harness)
    }

    #expect(service.calls == selection.flatMap { AttachmentFixtures.calls(of: verb, on: [$0]) })
  }

  /// The availability of an action reads the file of its block only: with
  /// the file of the last block gone, the Open button of that block is
  /// disabled, so its press does not take, and the Open button of the first
  /// block still opens its file.
  @Test func anActionThatTheFileOfABlockCannotRunIsDisabledInThatBlockOnly() throws {
    defer { fileSet.remove() }
    let missing = try #require(selection.last)
    try FileManager.default.removeItem(at: missing.url)
    let harness = mount()
    defer { harness.close() }

    try Self.press(.openAttachment, inBlock: 0, of: harness)
    #expect(throws: (any Error).self) {
      try Self.press(.openAttachment, inBlock: selection.count - 1, of: harness)
    }

    #expect(service.calls == AttachmentFixtures.calls(of: .openAttachment, on: [selection[0]]))
  }
}
