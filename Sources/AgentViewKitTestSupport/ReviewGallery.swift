import EditorTestSupport
import Foundation

/// The errors of ``ReviewGallery``.
public enum ReviewGalleryError: Error, Equatable {
  /// Each pixel of the image has the same color, so the capture shows
  /// nothing.
  case emptyImage(name: String)
}

/// One screen of the contact sheet of a ``ReviewGallery``: one row with an
/// image for each look, and a note under the row.
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
/// PNG images, one for each screen in each look, and a contact sheet
/// `index.html` that shows them in a table, one row for each screen and one
/// column for each look.
///
/// Each image is a capture of a real window from the window server
/// (EditorKit `CapturedImage`, `style.md` rule 9). The gallery compares no
/// image with a reference image. A person looks at the images. The gallery
/// checks only that each capture has more than one color, and that the files
/// are written.
public struct ReviewGallery: Sendable {
  /// The looks of each screen: Light and Dark, and no other (EditorKit
  /// `style.md`, rule 9).
  public static let looks = ReviewAppearance.allCases

  /// The folder of the gallery: `AgentViewKit/screenshot-check` in the caches
  /// folder of the user. Each run writes over it.
  public static var defaultDirectory: URL {
    URL.cachesDirectory.appending(path: folderPath, directoryHint: .isDirectory)
  }

  /// The file name of the contact sheet.
  public static let contactSheetName = "index.html"

  /// The path of the gallery folder, below the caches folder.
  private static let folderPath = "AgentViewKit/screenshot-check"

  /// The text between the screen and the look in an image name.
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

  /// The name of the image of `screen` in `look`, with no extension, such as
  /// `thread--dark`.
  ///
  /// - Parameters:
  ///   - screen: The name of the screen.
  ///   - look: The look.
  /// - Returns: `<screen>--<look>`.
  public static func imageName(screen: String, look: ReviewAppearance) -> String {
    screen + nameSeparator + look.rawValue
  }

  /// The file name of the image of `screen` in `look`, such as
  /// `thread--dark.png`.
  ///
  /// - Parameters:
  ///   - screen: The name of the screen.
  ///   - look: The look.
  /// - Returns: The file name.
  public static func fileName(screen: String, look: ReviewAppearance) -> String {
    imageName(screen: screen, look: look) + "." + imageExtension
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

  /// Writes `image` as the image of `screen` in `look`.
  ///
  /// - Parameters:
  ///   - image: The capture of the screen.
  ///   - screen: The name of the screen.
  ///   - look: The look.
  /// - Returns: The URL of the image.
  /// - Throws: ``ReviewGalleryError/emptyImage(name:)`` when the capture has
  ///   one color only, a `CapturedImageError` when the image cannot be
  ///   encoded, or the error of the write.
  @discardableResult
  public func write(_ image: CapturedImage, screen: String, look: ReviewAppearance) throws -> URL {
    let name = Self.imageName(screen: screen, look: look)
    guard image.hasMoreThanOneColor() else { throw ReviewGalleryError.emptyImage(name: name) }
    let url = directory.appending(path: Self.fileName(screen: screen, look: look))
    try write(image.pngData(), to: url)
    return url
  }

  /// Writes the contact sheet: one row for each of `rows`, in order, with one
  /// cell for each of ``looks``. A cell links its image to the full PNG. A
  /// cell whose image is not in the folder says so.
  ///
  /// - Parameter rows: The screens, in order.
  /// - Returns: The URL of the contact sheet.
  /// - Throws: The error of the write.
  @discardableResult
  public func writeContactSheet(_ rows: [ReviewGalleryRow]) throws -> URL {
    let url = directory.appending(path: Self.contactSheetName)
    try write(Data(ReviewGalleryPage.html(rows: rows.map(page(of:))).utf8), to: url)
    return url
  }

  /// Writes `data` to `url`, atomically, after it makes the gallery folder.
  ///
  /// - Parameters:
  ///   - data: The bytes of the file.
  ///   - url: The file URL, in ``directory``.
  /// - Throws: The error of the file manager or of the write.
  private func write(_ data: Data, to url: URL) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try data.write(to: url, options: .atomic)
  }

  /// The row of the page for `row`, with the image names that are in the
  /// folder.
  ///
  /// - Parameter row: The screen.
  /// - Returns: The row of the page.
  private func page(of row: ReviewGalleryRow) -> ReviewGalleryPage.Row {
    let cells = Self.looks.map { look in
      let name = Self.fileName(screen: row.screen, look: look)
      let exists = FileManager.default.fileExists(
        atPath: directory.appending(path: name).path(percentEncoded: false))
      return ReviewGalleryPage.Cell(fileName: name, variant: look.rawValue, exists: exists)
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
