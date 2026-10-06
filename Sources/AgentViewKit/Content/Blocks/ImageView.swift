import AppKit
import FoundationModelsACP
import SwiftUI

/// The default view of an image block (plan.md §9 A2, §9 F).
///
/// The view shows the image, scaled to fit. A tap on the image writes its
/// bytes to a local file and selects that file in the
/// ``InspectorSelection`` of the environment. Then the inspector shows the
/// image. Bytes that are not an image show a placeholder label.
///
/// The view shows a kit ``ImageContent``, or an ACP `ImageContent` that a
/// transcript entry holds. The view of an ACP image decodes the base64 data
/// of the ACP value when it shows it. Data that is not base64 shows the
/// placeholder label.
public struct ImageView: View {
  /// The accessibility identifier of the image.
  public static let imageIdentifier = "image-block"

  /// The accessibility identifier of a placeholder for bytes that are not
  /// an image.
  public static let placeholderIdentifier = "image-block-placeholder"

  /// The file name stem of an image with no file name in its URI.
  private static let fileStem = "image"

  /// The image to show: a kit image of a thread message, or an ACP image
  /// that a transcript entry holds.
  let source: BlockSource<ImageContent, FoundationModelsACP.ImageContent>

  @Environment(\.inspectorSelection) private var selection

  /// Makes the view of an image.
  ///
  /// - Parameter image: The image to show.
  public init(image: ImageContent) {
    self.source = .record(image)
  }

  /// Makes the view of an ACP image of a transcript entry.
  ///
  /// - Parameter image: The ACP image to show, as the entry holds it.
  public init(image: FoundationModelsACP.ImageContent) {
    self.source = .wire(image)
  }

  /// The file name of the image: the last part of its URI, or `image` with
  /// the extension of its MIME type.
  var name: String {
    switch source {
    case .record(let image):
      ContentBlockFile.fileName(uri: image.uri, mimeType: image.mimeType, stem: Self.fileStem)
    case .wire(let image):
      ContentBlockFile.fileName(uri: image.uri, mimeType: image.mimeType.rawValue, stem: Self.fileStem)
    }
  }

  /// The bytes of the image, or `nil` when the data of an ACP image is not
  /// base64.
  private var data: Data? {
    switch source {
    case .record(let image): image.data
    case .wire(let image): Data(base64Encoded: image.data)
    }
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
      Label(name, systemImage: "photo.badge.exclamationmark")
        .foregroundStyle(.secondary)
        .accessibilityIdentifier(Self.placeholderIdentifier)
    }
  }

  /// Writes the image to a file and selects the file in the inspector
  /// selection of the environment.
  ///
  /// - Parameter data: The bytes of the image.
  private func select(data: Data) {
    guard let selection else { return }
    let name = name
    Task {
      guard let url = await ContentBlockFile.write(data, named: name) else { return }
      selection.select(Attachment(url: url))
    }
  }
}
