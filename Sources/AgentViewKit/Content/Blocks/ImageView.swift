import AppKit
import EditorCommandsUI
import EditorStyle
import FoundationModelsACP
import OSLog
import SwiftUI

/// The default view of an image block (plan.md §9 A2, §9 F).
///
/// The view shows the image, scaled to fit. A tap on the image writes its
/// bytes to a local file and selects that file in the
/// ``InspectorSelection`` of the environment. Then the inspector shows the
/// image. In an ``AgentThreadView`` in the host mode
/// (``SwiftUI/View/agentAttachmentInspector(_:)``), the tap writes an
/// ``AgentAttachmentSelection`` of the file to the binding of the host. Bytes
/// that are not an image show a placeholder label.
///
/// The image is the scope of its file (`agentAttachment:<id>`, AVK-11). The
/// view writes the file when it shows, so the ``AgentAttachmentVerb``
/// commands of its context menu and of the command palette can run on it.
/// The image has square corners, so the focus ring of the scope is a
/// rectangle. While the inspector shows the block file of the image, the
/// image sits on the shared selection surface, in the same rectangle.
///
/// The view shows an ACP `ImageContent` that a transcript entry holds. The
/// view decodes the base64 data of the ACP value when it shows it. Data that
/// is not base64 shows the placeholder label.
public struct ImageView: View {
  /// The accessibility identifier of the image.
  public static let imageIdentifier = "image-block"

  /// The accessibility identifier of a placeholder for bytes that are not
  /// an image.
  public static let placeholderIdentifier = "image-block-placeholder"

  /// The corners of the image: square. The selection surface and the focus
  /// ring of the scope of the image both have them.
  static let corners = SurfaceCorners.square

  /// The file name stem of an image with no file name in its URI.
  private static let fileStem = "image"

  /// The log of a block file that the view cannot write.
  private static let logger = Logger(subsystem: "AgentViewKit", category: "ImageView")

  /// The ACP image to show, as the transcript entry holds it.
  let image: FoundationModelsACP.ImageContent

  @Environment(\.attachmentSelect) private var selectForInspector
  @Environment(\.themeSecondary) private var themeSecondary

  /// The report that gets the file name of each image that a tap starts to
  /// write, or `nil`.
  @Environment(\.imageSelectReport) private var reportSelect

  /// Makes the view of an ACP image of a transcript entry.
  ///
  /// - Parameter image: The ACP image to show, as the entry holds it.
  public init(image: FoundationModelsACP.ImageContent) {
    self.image = image
  }

  /// The file name of the image: the last part of its URI, or `image` with
  /// the extension of its MIME type.
  var name: String {
    ContentBlockFile.fileName(uri: image.uri, mimeType: image.mimeType.rawValue, stem: Self.fileStem)
  }

  /// The bytes of the image, or `nil` when the data is not base64.
  private var data: Data? {
    Data(base64Encoded: image.data)
  }

  public var body: some View {
    if let data, let nsImage = NSImage(data: data) {
      let file = file(of: data)
      Image(nsImage: nsImage)
        .resizable()
        .scaledToFit()
        .frame(maxHeight: PreviewLayout.maximumPreviewHeight)
        .accessibilityLabel(name)
        .modifier(InspectorSelectable(file: file, corners: Self.corners) { select(data: data) })
        .accessibilityIdentifier(Self.imageIdentifier)
        .agentAttachmentScope(file, focusRingCorners: Self.corners)
        .task(id: file.url) { await Self.writeFile(of: data, named: file.name) }
    } else {
      Label(name, systemImage: SharedSymbol.imageFailure)
        .foregroundStyle(themeSecondary)
        .accessibilityIdentifier(Self.placeholderIdentifier)
    }
  }

  /// The attachment of the block file of the image: the file that
  /// ``ContentBlockFile/write(_:named:)`` writes for these bytes.
  ///
  /// - Parameter data: The bytes of the image.
  /// - Returns: The attachment, also before the file exists.
  private func file(of data: Data) -> Attachment {
    ContentBlockFile.attachment(
      of: data, named: name,
      type: ContentBlockFile.type(mimeType: image.mimeType.rawValue, fallback: .image))
  }

  /// Writes the block file of the image, so that the attachment commands of
  /// the image can run on it. A second write of the same bytes writes
  /// nothing.
  ///
  /// - Parameters:
  ///   - data: The bytes of the image.
  ///   - name: The file name.
  private static func writeFile(of data: Data, named name: String) async {
    let url = await ContentBlockFile.write(data, named: name)
    if url == nil {
      logger.error("The image \(name, privacy: .private) has no file for its commands.")
    }
  }

  /// Writes the image to a file and selects the file for the inspector of
  /// the environment: the inspector of the host in the host mode of a thread
  /// view, otherwise the inspector selection. With no inspector, the view
  /// writes no file.
  ///
  /// The view gives the file name to
  /// ``SwiftUI/EnvironmentValues/imageSelectReport`` in the same step, before
  /// it starts the task that writes the file.
  ///
  /// - Parameter data: The bytes of the image.
  private func select(data: Data) {
    guard selectForInspector.hasInspector else { return }
    let name = name
    reportSelect?(name)
    Task {
      guard let url = await ContentBlockFile.write(data, named: name) else { return }
      selectForInspector(Attachment(url: url))
    }
  }
}

extension EnvironmentValues {
  /// The ``ObservationReport`` that gets the file name of each image that the
  /// nearest ``ImageView`` starts to write for the inspector selection, or
  /// `nil`.
  ///
  /// The view calls the report in the same step as the tap, before it starts
  /// the task that writes the file.
  @Entry var imageSelectReport: ObservationReport<String>? = nil
}

#Preview("Image") {
  // A PNG image of one pixel, as base64.
  let onePixelPNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
  ImageView(image: ImageContent(data: onePixelPNG, mimeType: MediaType(rawValue: "image/png")))
}
