import SwiftUI
import UniformTypeIdentifiers

/// The default view of an embedded resource block (plan.md §9 A2).
///
/// Text contents show through ``AttachmentTextContent``: a source type shows
/// in a ``CodeBlockView``, and other text shows through Textual. Binary
/// contents show as an ``AttachmentChip`` with the name, the type icon, and
/// the size of the resource.
struct ResourceBlockView: View {
  /// The resource to show.
  let resource: EmbeddedResource

  var body: some View {
    switch resource.contents {
    case .text(let text):
      AttachmentTextContent(
        text: text,
        type: ContentBlockFile.type(mimeType: resource.mimeType, fallback: .plainText),
        filename: name)
    case .blob(let data):
      AttachmentChip(
        Attachment(
          id: AttachmentID(resource.uri),
          url: URL(string: resource.uri) ?? URL(filePath: name),
          type: ContentBlockFile.type(mimeType: resource.mimeType, fallback: .data),
          name: name,
          size: data.count))
    }
  }

  /// The file name of the resource: the last part of its URI, or
  /// `resource` with the extension of its MIME type.
  private var name: String {
    ContentBlockFile.fileName(uri: resource.uri, mimeType: resource.mimeType, stem: "resource")
  }
}
