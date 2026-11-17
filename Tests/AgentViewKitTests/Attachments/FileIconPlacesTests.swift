@testable import AgentViewKit
import Foundation
import Testing
import UniformTypeIdentifiers

/// Each place that shows a file as an item shows the ``FileIcon`` of the
/// file, not a type icon of the kit (D196).
///
/// The unit tests mount no view, so each test reads the type of the body.
@MainActor @Suite struct FileIconPlacesTests {
  /// The name of the type of the image of a file.
  static let fileIcon = String(describing: FileIcon.self)

  @Test func theChipShowsTheFileIcon() {
    let chip = AttachmentChip(Attachment(url: URL(filePath: "/tmp/notes.txt")))

    #expect(String(describing: type(of: chip.body)).contains(Self.fileIcon))
  }

  @Test func theArtifactHeaderShowsTheFileIcon() {
    let artifact = ArtifactView(
      artifact: ArtifactPayload(
        id: "notes", title: "Notes", type: UTType.plainText.identifier, url: URL(filePath: "/tmp/notes.txt")))

    #expect(String(describing: type(of: artifact.body)).contains(Self.fileIcon))
  }
}
