import AppKit
import FoundationModelsACP
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
/// The view shows an ACP `ImageContent` that a transcript entry holds. The
/// view decodes the base64 data of the ACP value when it shows it. Data that
/// is not base64 shows the placeholder label.
public struct ImageView: View {
  /// The accessibility identifier of the image.
  public static let imageIdentifier = "image-block"

  /// The accessibility identifier of a placeholder for bytes that are not
  /// an image.
  public static let placeholderIdentifier = "image-block-placeholder"

  /// The file name stem of an image with no file name in its URI.
  private static let fileStem = "image"

  /// The ACP image to show, as the transcript entry holds it.
  let image: FoundationModelsACP.ImageContent

  @Environment(\.attachmentSelect) private var selectForInspector

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
      Image(nsImage: nsImage)
        .resizable()
        .scaledToFit()
        .frame(maxHeight: PreviewLayout.maximumPreviewHeight)
        .accessibilityLabel(name)
        .modifier(SelectOnTap { select(data: data) })
        .accessibilityIdentifier(Self.imageIdentifier)
    } else {
      Label(name, systemImage: SharedSymbol.imageFailure)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier(Self.placeholderIdentifier)
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
