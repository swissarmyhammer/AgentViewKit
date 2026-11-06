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

  /// The file of the second chip of the Files row of an inspector of
  /// several files.
  private static let plan = Attachment(
    id: AttachmentID("plan"), url: URL(fileURLWithPath: "/tmp/plan.txt"), type: .plainText, name: "plan.txt")

  @Test func theInspectionShowsTheFilesAsPathsThenThePreview() {
    let kinds = AttachmentInspector.inspection.groups.flatMap(\.fields).map(\.kind)

    #expect(kinds == [.paths, .preview])
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

  @Test func theFilesIdentifierIsTheSchemeIdOfTheFilesRow() {
    #expect(
      AttachmentInspector.filesIdentifier(of: [Self.draft, Self.plan])
        == "inspection:attachment/object:draft%2Fnotes%2Emd+plan/field:attachment.files")
  }

  @Test func openingAChipRunsTheOpenVerbOfTheFileServiceOnItsFile() {
    let service = RecordingAttachmentFileService()
    let files = [Self.draft, Self.plan]

    InspectedAttachment(Self.draft, files: files, fileService: service).open(Self.plan.url)

    #expect(service.calls == [RecordingAttachmentFileService.Call(verb: .openAttachment, attachment: Self.plan)])
  }

  @Test func thePreviewIdentifierIsTheSchemeIdOfThePreviewRow() {
    #expect(
      AttachmentInspector.previewIdentifier(of: [Self.draft])
        == "inspection:attachment/object:draft%2Fnotes%2Emd/field:attachment.preview")
  }
}
