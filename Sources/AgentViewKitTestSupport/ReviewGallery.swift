import Foundation

/// The errors of ``ReviewGallery``.
public enum ReviewGalleryError: Error, Equatable {
  /// The render of the image gave no pixels.
  case noPixels(name: String)

  /// Each pixel of the image has the same color, so the render drew nothing.
  case emptyImage(name: String)

  /// Core Graphics or ImageIO did not make a PNG image of the pixels.
  case noImage(name: String)
}

/// One screen of the contact sheet of a ``ReviewGallery``: one row with an
/// image for each variant, and a note under the row.
public struct ReviewGalleryRow: Equatable, Sendable {
  /// The name of the screen in the image names, such as `thread`.
  public let screen: String

  /// The title of the screen in the contact sheet.
  public let title: String

  /// The note under the row: the judgement of a reviewer, with the id of
  /// each card that a finding made.
  public let note: String

  /// Makes a row.
  ///
  /// - Parameters:
  ///   - screen: The name of the screen in the image names.
  ///   - title: The title of the screen in the contact sheet.
  ///   - note: The note under the row.
  public init(screen: String, title: String, note: String) {
    self.screen = screen
    self.title = title
    self.note = note
  }
}

/// The review gallery of the full screens of the kit (^8q34yt8): a folder of
/// PNG images, one for each screen in each variant, and a contact sheet
/// `index.html` that shows them in a table, one row for each screen and one
/// column for each variant.
///
/// The gallery compares no image with a reference image. A person looks at
/// the images. The gallery checks only that each render gave an image with
/// more than one color, and that the files are written.
///
/// The gallery and ``SnapshotStore`` take the same input: the pixels of
/// ``ViewSnapshot``, and a name from ``SnapshotVariant/name(of:)``. To make
/// a screen of the gallery a snapshot test, give its pixels to
/// ``SnapshotStore/verify(_:named:sourceLocation:)`` in place of
/// ``write(_:screen:variant:)``.
public struct ReviewGallery: Sendable {
  /// The variants of each screen: light and dark.
  public static let variants: [SnapshotVariant] = [.light, .dark]

  /// The folder of the gallery: `AgentViewKit/screenshot-check` in the caches
  /// folder of the user. Each run writes over it.
  public static var defaultDirectory: URL {
    URL.cachesDirectory.appending(path: folderPath, directoryHint: .isDirectory)
  }

  /// The file name of the contact sheet.
  public static let contactSheetName = "index.html"

  /// The path of the gallery folder, below the caches folder.
  private static let folderPath = "AgentViewKit/screenshot-check"

  /// The text between the screen and the variant in an image name.
  private static let nameSeparator = "--"

  /// The file extension of each image.
  private static let imageExtension = "png"

  /// The folder of the images and the contact sheet.
  public let directory: URL

  /// Makes a gallery in `directory`.
  ///
  /// - Parameter directory: The folder of the images and the contact sheet.
  public init(directory: URL = defaultDirectory) {
    self.directory = directory
  }

  /// The name of the image of `screen` in `variant`, with no extension, such
  /// as `thread--dark`.
  ///
  /// - Parameters:
  ///   - screen: The name of the screen.
  ///   - variant: The variant.
  /// - Returns: `<screen>--<variant>`.
  public static func imageName(screen: String, variant: SnapshotVariant) -> String {
    screen + nameSeparator + variant.rawValue
  }

  /// The file name of the image of `screen` in `variant`, such as
  /// `thread--dark.png`.
  ///
  /// - Parameters:
  ///   - screen: The name of the screen.
  ///   - variant: The variant.
  /// - Returns: The file name.
  public static func fileName(screen: String, variant: SnapshotVariant) -> String {
    imageName(screen: screen, variant: variant) + "." + imageExtension
  }

  /// Removes the images and the contact sheet of an earlier run. Other files
  /// in the folder stay. A missing folder is not an error.
  ///
  /// - Throws: The error of the file manager.
  public func removeEarlierRun() throws {
    let manager = FileManager.default
    guard manager.fileExists(atPath: directory.path(percentEncoded: false)) else { return }
    let files = try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    for file in files where Self.isGalleryFile(file) {
      try manager.removeItem(at: file)
    }
  }

  /// Writes `pixels` as the image of `screen` in `variant`.
  ///
  /// - Parameters:
  ///   - pixels: The pixels of the screen, or `nil` when the render gave none.
  ///   - screen: The name of the screen.
  ///   - variant: The variant.
  /// - Returns: The URL of the image.
  /// - Throws: A ``ReviewGalleryError`` when the render gave no image or an
  ///   image of one color, or the error of the write.
  @discardableResult
  public func write(_ pixels: RenderedPixels?, screen: String, variant: SnapshotVariant) throws -> URL {
    let name = Self.imageName(screen: screen, variant: variant)
    guard let pixels else { throw ReviewGalleryError.noPixels(name: name) }
    guard pixels.hasMoreThanOneColor else { throw ReviewGalleryError.emptyImage(name: name) }
    guard let data = pixels.pngData() else { throw ReviewGalleryError.noImage(name: name) }
    let url = directory.appending(path: Self.fileName(screen: screen, variant: variant))
    try SnapshotStore.write(data, to: url)
    return url
  }

  /// Writes the contact sheet: one row for each of `rows`, in order, with one
  /// cell for each of ``variants``. A cell links its image to the full PNG.
  /// A cell whose image is not in the folder says so.
  ///
  /// - Parameter rows: The screens, in order.
  /// - Returns: The URL of the contact sheet.
  /// - Throws: The error of the write.
  @discardableResult
  public func writeContactSheet(_ rows: [ReviewGalleryRow]) throws -> URL {
    let url = directory.appending(path: Self.contactSheetName)
    try SnapshotStore.write(Data(ReviewGalleryPage.html(rows: rows.map(page(of:))).utf8), to: url)
    return url
  }

  /// The row of the page for `row`, with the image names that are in the
  /// folder.
  ///
  /// - Parameter row: The screen.
  /// - Returns: The row of the page.
  private func page(of row: ReviewGalleryRow) -> ReviewGalleryPage.Row {
    let cells = Self.variants.map { variant in
      let name = Self.fileName(screen: row.screen, variant: variant)
      let exists = FileManager.default.fileExists(
        atPath: directory.appending(path: name).path(percentEncoded: false))
      return ReviewGalleryPage.Cell(fileName: name, variant: variant.rawValue, exists: exists)
    }
    return ReviewGalleryPage.Row(title: row.title, note: row.note, cells: cells)
  }

  /// Whether `file` is an image or the contact sheet of the gallery.
  ///
  /// - Parameter file: A file in the folder.
  /// - Returns: `true` for a PNG image and for the contact sheet.
  private static func isGalleryFile(_ file: URL) -> Bool {
    file.pathExtension == imageExtension || file.lastPathComponent == contactSheetName
  }
}

extension RenderedPixels {
  /// Whether at least two pixels have different colors. A render that drew
  /// nothing gives one color only: the background.
  var hasMoreThanOneColor: Bool {
    let first = bytes.prefix(Self.bytesPerPixel)
    return pixelOffsets.contains { offset in
      bytes[offset..<offset + Self.bytesPerPixel] != first
    }
  }
}
