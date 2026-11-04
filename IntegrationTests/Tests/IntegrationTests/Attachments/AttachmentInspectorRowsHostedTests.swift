@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorInspector
import EditorInspectorTestSupport
import EditorTestSupport
import SwiftUI
import Testing

/// The rows of ``AttachmentInspector``, an EditorKit `InspectorView` of its
/// files, read with EditorKit's `InspectorDriver` by their scheme ids.
///
/// One file shows its name, its actions and the EditorKit preview of the
/// file. Several files fold into one form: the header counts them, the
/// preview reads "Mixed", and no action shows, because each action runs on
/// one file.
@Suite(.serialized, .hostedSerially) @MainActor struct AttachmentInspectorRowsHostedTests {
  /// The width of a narrow docked panel, in points.
  static let narrowWidth: CGFloat = 240

  /// The height of the window, in points.
  static let height: CGFloat = 600

  /// The size of a narrow docked panel.
  static let narrowPanel = CGSize(width: narrowWidth, height: height)

  /// The names of the files of the tests.
  static let names = ["first.bin", "second.bin"]

  /// Mounts `view` in a window of `size`, and makes one render pass.
  ///
  /// - Parameters:
  ///   - view: The view to show.
  ///   - size: The size of the window.
  /// - Returns: The harness. The caller closes it.
  static func mount(_ view: some View, size: CGSize = AttachmentInspectorHostedTests.hostSize)
    -> HostedViewHarness<some View>
  {
    let harness = HostedViewHarness(view, size: size)
    harness.render()
    return harness
  }

  /// Writes a file of each of ``names`` to `directory`.
  ///
  /// - Parameter directory: The directory of the files.
  /// - Returns: The attachments of the files.
  /// - Throws: The error of a write.
  static func attachments(in directory: TemporaryFolder) throws -> [AgentViewKit.Attachment] {
    try names.map { try AttachmentFixtures.attachment(named: $0, in: directory) }
  }

  @Test func thePreviewRowOfOneFileShowsTheFile() throws {
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    defer { directory.remove() }
    let attachment = try AttachmentFixtures.attachment(named: "blob.bin", in: directory)
    let harness = Self.mount(AttachmentInspector(attachment))
    defer { harness.close() }

    #expect(harness.rowValue(AttachmentInspector.previewIdentifier(of: [attachment])) == "blob.bin")
  }

  @Test func theNameRowOfOneFileIsTheNameOfTheFile() throws {
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    defer { directory.remove() }
    let attachment = try AttachmentFixtures.attachment(named: "blob.bin", in: directory)
    let harness = Self.mount(AttachmentInspector(attachment))
    defer { harness.close() }

    #expect(harness.rowValue(AttachmentInspector.nameIdentifier(of: [attachment])) == "blob.bin")
  }

  @Test func thePreviewRowOfSeveralFilesIsMixed() throws {
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    defer { directory.remove() }
    let attachments = try Self.attachments(in: directory)
    let harness = Self.mount(AttachmentInspector(attachments))
    defer { harness.close() }

    #expect(harness.inspectorDriver.isMixed(AttachmentInspector.previewIdentifier(of: attachments)))
  }

  @Test func theHeaderOfSeveralFilesCountsThem() throws {
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    defer { directory.remove() }
    let attachments = try Self.attachments(in: directory)
    let harness = Self.mount(AttachmentInspector(attachments))
    defer { harness.close() }

    let header = EditorInspectorStrings.blockHeader(
      title: AttachmentInspector.inspection.title, count: attachments.count)
    #expect(harness.rowValue(AttachmentInspector.nameIdentifier(of: attachments)) == header)
  }

  @Test func severalFilesShowNoAction() throws {
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    defer { directory.remove() }
    let harness = Self.mount(AttachmentInspector(try Self.attachments(in: directory)))
    defer { harness.close() }

    for identifier in AttachmentInspector.actionIdentifiers {
      #expect(harness.element(identifier: identifier) == nil, "Unexpected action \(identifier).")
    }
  }

  /// The inspector as the content of a narrow host panel, which owns the
  /// one scroll view, still shows the preview row of its file.
  @Test func aNarrowHostPanelShowsThePreviewRow() throws {
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    defer { directory.remove() }
    let attachment = try AttachmentFixtures.attachment(named: "blob.bin", in: directory)
    let panel = ScrollView {
      AttachmentInspector(attachment)
    }
    .inspectorScrolling(.host)
    let harness = Self.mount(panel, size: Self.narrowPanel)
    defer { harness.close() }

    #expect(harness.showsRow(AttachmentInspector.previewIdentifier(of: [attachment])))
  }
}
