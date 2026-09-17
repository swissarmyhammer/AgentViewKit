import AppKit
import SwiftUI

/// The default view of an image block (plan.md §9 A2, §9 F).
///
/// The view shows the image, scaled to fit. A tap on the image writes its
/// bytes to a local file and selects that file in the
/// ``InspectorSelection`` of the environment. Then the inspector shows the
/// image. Bytes that are not an image show a placeholder label.
public struct ImageView: View {
  /// The accessibility identifier of the image.
  public static let imageIdentifier = "image-block"

  /// The accessibility identifier of a placeholder for bytes that are not
  /// an image.
  public static let placeholderIdentifier = "image-block-placeholder"

  /// The image to show.
  let image: ImageContent

  @Environment(\.inspectorSelection) private var selection

  /// Makes the view of an image.
  ///
  /// - Parameter image: The image to show.
  public init(image: ImageContent) {
    self.image = image
  }

  /// The file name of the image: the last part of its URI, or `image` with
  /// the extension of its MIME type.
  var name: String {
    ContentBlockFile.fileName(uri: image.uri, mimeType: image.mimeType, stem: "image")
  }

  public var body: some View {
    if let nsImage = NSImage(data: image.data) {
      Image(nsImage: nsImage)
        .resizable()
        .scaledToFit()
        .frame(maxHeight: PreviewLayout.maximumPreviewHeight)
        .accessibilityLabel(name)
        .modifier(SelectOnTap(action: select))
        .accessibilityIdentifier(Self.imageIdentifier)
    } else {
      Label(name, systemImage: "photo.badge.exclamationmark")
        .foregroundStyle(.secondary)
        .accessibilityIdentifier(Self.placeholderIdentifier)
    }
  }

  /// Writes the image to a file and selects the file in the inspector
  /// selection of the environment.
  private func select() {
    guard let selection else { return }
    let data = image.data
    let name = name
    Task {
      guard let url = await ContentBlockFile.write(data, named: name) else { return }
      selection.select(Attachment(url: url))
    }
  }
}
