import EditorInspector
import Foundation
import Testing
import UniformTypeIdentifiers

@testable import AgentViewKit

/// Checks what the inspection of an ``AttachmentInspector`` declares, with no
/// view.
@Suite @MainActor struct AttachmentInspectionTests {
  /// An attachment whose raw id holds a separator of the scheme (`/`) and a
  /// field separator (`.`), so its object id shows the escape of each.
  private static let draft = Attachment(
    id: AttachmentID("draft/notes.md"), url: URL(fileURLWithPath: "/tmp/notes.md"), type: .plainText,
    name: "notes.md")

  @Test func theInspectionShowsTheFileAsOnePreview() {
    let kinds = AttachmentInspector.inspection.groups.flatMap(\.fields).map(\.kind)

    #expect(kinds == [.preview])
  }

  @Test func theOneGroupHasTheKeyOfThePreviewRowID() {
    #expect(AttachmentInspector.inspection.groups.map(\.key) == [AttachmentInspector.groupIdentifier])
  }

  @Test func theInspectionHasTheExplicitIdAttachment() {
    #expect(AttachmentInspector.inspection.id == "attachment")
  }

  @Test func theObjectIdIsTheEscapedRawIdOfTheAttachment() {
    let objectID = InspectorScheme.objectID(
      of: [InspectedAttachment(Self.draft)], key: AttachmentInspector.viewIdentifier)

    #expect(objectID == "draft%2Fnotes%2Emd")
  }

  @Test func theNameIdentifierIsTheSchemeIdOfTheNameRow() {
    #expect(
      AttachmentInspector.nameIdentifier(of: [Self.draft])
        == "inspection:attachment/object:draft%2Fnotes%2Emd/name")
  }

  @Test func thePreviewIdentifierIsTheSchemeIdOfThePreviewRow() {
    #expect(
      AttachmentInspector.previewIdentifier(of: [Self.draft])
        == "inspection:attachment/object:draft%2Fnotes%2Emd/field:attachment.preview")
  }
}
