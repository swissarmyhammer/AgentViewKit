import AppKit
import QuickLookThumbnailing
import SwiftUI
import UniformTypeIdentifiers

/// The image of a file, as Finder shows it (D196).
///
/// The view shows the Quick Look thumbnail of the content of the file, which
/// `QLThumbnailGenerator` makes at the scale of the screen. Until the
/// thumbnail is ready, and when Quick Look makes no thumbnail, the view shows
/// the icon of the file from `NSWorkspace`. The system makes each image, so
/// the kit draws no type icons of its own.
///
/// ``AttachmentChip`` and the header of ``ArtifactView`` show it.
public struct FileIcon: View {
  /// The location of the file, or `nil` for content that has no file.
  let url: URL?

  /// The type of the content. The placeholder shows the icon of this type
  /// when no file is at ``url``.
  let type: UTType

  /// The width and the height of the image, in points.
  let side: CGFloat

  @Environment(\.displayScale) private var displayScale
  @Environment(\.fileThumbnailLoader) private var loader
  @State private var thumbnail: NSImage?

  /// Makes the image of an attached file.
  ///
  /// - Parameters:
  ///   - attachment: The file.
  ///   - side: The width and the height of the image, in points.
  public init(_ attachment: Attachment, side: CGFloat) {
    self.init(url: attachment.url, type: attachment.type, side: side)
  }

  /// Makes the image of content that has no file: the icon of its type.
  ///
  /// - Parameters:
  ///   - type: The type of the content.
  ///   - side: The width and the height of the image, in points.
  public init(type: UTType, side: CGFloat) {
    self.init(url: nil, type: type, side: side)
  }

  private init(url: URL?, type: UTType, side: CGFloat) {
    self.url = url
    self.type = type
    self.side = side
  }

  public var body: some View {
    Image(nsImage: Self.image(url: url, type: type, thumbnail: thumbnail))
      .resizable()
      .scaledToFit()
      .frame(width: side, height: side)
      .accessibilityHidden(true)
      // A new file starts with no thumbnail, so the image of the last file
      // does not show for the new file.
      .id(url)
      .task(id: FileThumbnails.Size(url: url, side: side, scale: displayScale)) {
        guard let url else { return }
        thumbnail = await loader.thumbnail(url, CGSize(width: side, height: side), displayScale)
      }
  }

  /// The image that the view shows.
  ///
  /// - Parameters:
  ///   - url: The location of the file, or `nil`.
  ///   - type: The type of the content.
  ///   - thumbnail: The thumbnail that the view loaded, or `nil`.
  /// - Returns: `thumbnail`, else the thumbnail of the file in the cache of
  ///   ``FileThumbnails``, else the placeholder.
  static func image(url: URL?, type: UTType, thumbnail: NSImage?) -> NSImage {
    if let thumbnail { return thumbnail }
    if let url, let cached = FileThumbnails.cached(url) { return cached }
    return FileThumbnails.placeholder(for: FileThumbnails.placeholderSource(url: url, type: type))
  }
}

/// Makes the thumbnail of a file for a ``FileIcon``.
///
/// The default loader, ``quickLook``, asks Quick Look. A test or a
/// `#Preview` gives a loader of its own.
struct FileThumbnailLoader {
  /// Makes the thumbnail of the file at a URL, at a size in points and a
  /// scale. The result is `nil` when there is no thumbnail.
  let thumbnail: @MainActor (URL, CGSize, CGFloat) async -> NSImage?

  /// The loader that asks Quick Look, through the cache of
  /// ``FileThumbnails``.
  static let quickLook = FileThumbnailLoader { url, size, scale in
    await FileThumbnails.thumbnail(of: url, size: size, scale: scale)
  }
}

extension EnvironmentValues {
  /// The loader that each ``FileIcon`` gets its thumbnail from.
  @Entry var fileThumbnailLoader = FileThumbnailLoader.quickLook
}

/// The Quick Look thumbnails of files, as Finder shows them, and their
/// placeholders (D196).
///
/// A cache holds each thumbnail by the location and the modification date of
/// its file. So a view that shows the file again shows the thumbnail at
/// once, and a changed file gets a new thumbnail.
enum FileThumbnails {
  /// The representation types of each request: the thumbnail of the
  /// content, and the icon of the file when Quick Look has no thumbnail.
  static let representationTypes: QLThumbnailGenerator.Request.RepresentationTypes = [.thumbnail, .icon]

  /// The size of a thumbnail that a view asks for, as the key of its load.
  struct Size: Hashable {
    /// The location of the file.
    let url: URL?
    /// The width and the height, in points.
    let side: CGFloat
    /// The scale of the screen.
    let scale: CGFloat
  }

  /// The source of the placeholder of a file.
  enum PlaceholderSource: Equatable {
    /// The icon of the file at this path.
    case file(String)
    /// The icon of this type, for content that has no file on disk.
    case type(UTType)
  }

  /// A thumbnail in the cache, with its size in pixels.
  private final class Entry {
    /// The thumbnail.
    let image: NSImage
    /// The larger side of the bitmap that Quick Look made, in pixels.
    let pixels: CGFloat

    init(image: NSImage, pixels: CGFloat) {
      self.image = image
      self.pixels = pixels
    }
  }

  /// The thumbnails, by ``key(of:)``.
  private static let cache = NSCache<NSString, Entry>()

  /// The request of the thumbnail of a file.
  ///
  /// - Parameters:
  ///   - url: The location of the file.
  ///   - size: The size of the thumbnail, in points.
  ///   - scale: The scale of the screen.
  /// - Returns: A request for ``representationTypes`` in icon mode, so that
  ///   the thumbnail has the look of the icon that Finder shows.
  static func request(for url: URL, size: CGSize, scale: CGFloat) -> QLThumbnailGenerator.Request {
    let request = QLThumbnailGenerator.Request(
      fileAt: url, size: size, scale: scale, representationTypes: representationTypes)
    request.iconMode = true
    return request
  }

  /// Makes the thumbnail of a file, or gives it from the cache.
  ///
  /// - Parameters:
  ///   - url: The location of the file.
  ///   - size: The size of the thumbnail, in points.
  ///   - scale: The scale of the screen.
  ///   - generate: Makes the image of a request. The default asks Quick
  ///     Look.
  /// - Returns: The thumbnail, or `nil` when the URL is not a file URL or
  ///   `generate` gives no image.
  static func thumbnail(
    of url: URL, size: CGSize, scale: CGFloat,
    generate: @MainActor (QLThumbnailGenerator.Request) async -> NSImage? = generate(_:)
  ) async -> NSImage? {
    guard url.isFileURL, let key = key(of: url) else { return nil }
    let pixels = max(size.width, size.height) * scale
    if let entry = cache.object(forKey: key), entry.pixels >= pixels {
      return entry.image
    }
    guard let image = await generate(request(for: url, size: size, scale: scale)) else { return nil }
    cache.setObject(Entry(image: image, pixels: pixels), forKey: key)
    return image
  }

  /// The thumbnail of a file in the cache.
  ///
  /// - Parameter url: The location of the file.
  /// - Returns: The thumbnail of the file as it is now, or `nil`.
  static func cached(_ url: URL) -> NSImage? {
    key(of: url).flatMap { cache.object(forKey: $0)?.image }
  }

  /// Asks Quick Look for the best image of a request.
  ///
  /// - Parameter request: The request.
  /// - Returns: The image, or `nil` when Quick Look makes none, such as for
  ///   a missing file.
  static func generate(_ request: QLThumbnailGenerator.Request) async -> NSImage? {
    try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).nsImage
  }

  /// The source of the placeholder of content.
  ///
  /// - Parameters:
  ///   - url: The location of the file, or `nil`.
  ///   - type: The type of the content.
  /// - Returns: The file, when a file is at `url`, else the type.
  static func placeholderSource(url: URL?, type: UTType) -> PlaceholderSource {
    guard let url, url.isFileURL, FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    else { return .type(type) }
    return .file(url.path(percentEncoded: false))
  }

  /// The placeholder of content: the icon that `NSWorkspace` gives.
  ///
  /// - Parameter source: The source of the placeholder.
  /// - Returns: The icon of the file, or of the type.
  static func placeholder(for source: PlaceholderSource) -> NSImage {
    switch source {
    case .file(let path): NSWorkspace.shared.icon(forFile: path)
    case .type(let type): NSWorkspace.shared.icon(for: type)
    }
  }

  /// The key of a file in the cache: its path and its modification date.
  ///
  /// - Parameter url: The location of the file.
  /// - Returns: The key, or `nil` when the file has no modification date,
  ///   such as a missing file.
  private static func key(of url: URL) -> NSString? {
    // The attributes of the file manager have no cache, as the resource
    // values of a URL have, so a changed file gives a new key.
    let path = url.path(percentEncoded: false)
    guard let date = (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
    else { return nil }
    return "\(path)|\(date.timeIntervalSinceReferenceDate)" as NSString
  }
}
