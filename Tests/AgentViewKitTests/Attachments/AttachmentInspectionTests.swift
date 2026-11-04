import EditorInspector
import Foundation
import Testing
import UniformTypeIdentifiers

@testable import AgentViewKit

/// Checks what the inspection of an ``AttachmentInspector`` declares, with no
/// view.
@Suite @MainActor struct AttachmentInspectionTests {
  @Test func theInspectionShowsTheFileAsOnePreview() {
    let kinds = AttachmentInspector.inspection.groups.flatMap(\.fields).map(\.kind)

    #expect(kinds == [.preview])
  }

  @Test func theOneGroupHasTheKeyOfThePreviewRowID() {
    #expect(AttachmentInspector.inspection.groups.map(\.key) == [AttachmentInspector.groupIdentifier])
  }

  @Test func theInspectedFileIsNamedByTheIdOfItsAttachment() {
    let attachment = Attachment(url: URL(fileURLWithPath: "/tmp/notes.md"))

    #expect(InspectedAttachment(attachment).id == attachment.id)
  }
}
