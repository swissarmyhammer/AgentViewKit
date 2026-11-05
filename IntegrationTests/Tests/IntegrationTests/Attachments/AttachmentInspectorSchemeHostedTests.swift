@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorTestSupport
import Testing

/// The scheme ids that the rows of a shown ``AttachmentInspector`` carry, as
/// a test out of process reads them: through accessibility, with no mouse
/// and no focus.
///
/// The ids are the exact text of ``AttachmentInspector/nameIdentifier(of:)``
/// and ``AttachmentInspector/previewIdentifier(of:)``: the explicit
/// inspection id `attachment`, and the raw id of the attachment, escaped by
/// EditorKit's scheme.
@Suite(.serialized, .hostedSerially) @MainActor struct AttachmentInspectorSchemeHostedTests {
  /// The raw id of the attachment of the tests, with a separator of the
  /// scheme (`/`) and a field separator (`.`).
  static let rawID = "draft/notes.md"

  /// The scheme id of the name row of the inspector of the attachment.
  static let nameRowID = "inspection:attachment/object:draft%2Fnotes%2Emd/name"

  /// The scheme id of the preview row of the inspector of the attachment.
  static let previewRowID = "inspection:attachment/object:draft%2Fnotes%2Emd/field:attachment.preview"

  @Test func theNameRowShowsTheNameIdentifier() throws {
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    defer { directory.remove() }
    let attachment = try Self.attachment(in: directory)
    let harness = try AttachmentInspectorFormHostedTests.mountInspector(of: attachment)
    defer { harness.close() }

    #expect(harness.showsRow(Self.nameRowID))
    #expect(AttachmentInspector.nameIdentifier(of: [attachment]) == Self.nameRowID)
  }

  @Test func thePreviewRowShowsThePreviewIdentifier() throws {
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    defer { directory.remove() }
    let attachment = try Self.attachment(in: directory)
    let harness = try AttachmentInspectorFormHostedTests.mountInspector(of: attachment)
    defer { harness.close() }

    #expect(harness.showsRow(Self.previewRowID))
    #expect(AttachmentInspector.previewIdentifier(of: [attachment]) == Self.previewRowID)
  }

  /// Writes the file of the tests to `directory`, and makes its attachment
  /// with the known id ``rawID``.
  ///
  /// - Parameter directory: The directory of the file.
  /// - Returns: The attachment of the file.
  /// - Throws: The error of the write of the file.
  static func attachment(in directory: TemporaryFolder) throws -> AgentViewKit.Attachment {
    var attachment = try AttachmentFixtures.attachment(named: "notes.md", in: directory)
    attachment.id = AttachmentID(rawID)
    return attachment
  }
}
