import AppKit
import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// A working folder with one image file, and the answers that show the
/// image (card ^9ync5h3).
///
/// The image is taller than one row of text, so its view after the load
/// is taller than the one row that the view shows while the load runs.
struct TranscriptImageFixtures {
  /// The width of the image, in pixels.
  static let pixelWidth = 40

  /// The height of the image, in pixels: more rows of text than one.
  static let pixelHeight = 120

  /// The name of the image file in the folder.
  static let fileName = "tall.png"

  /// The bits of one color sample.
  static let bitsPerSample = 8

  /// The color samples of one pixel: red, green, blue and alpha.
  static let samplesPerPixel = 4

  /// The folder.
  let folder: TemporaryFolder

  /// Makes a folder with the image file.
  init() throws {
    folder = try TemporaryFolder(prefix: "transcript-image")
    try folder.write(Self.fileName, contents: try Self.pngData())
  }

  /// The PNG data of an image of ``pixelWidth`` by ``pixelHeight`` pixels.
  ///
  /// - Returns: The data.
  static func pngData() throws -> Data {
    let image = try #require(
      NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixelWidth, pixelsHigh: pixelHeight, bitsPerSample: bitsPerSample,
        samplesPerPixel: samplesPerPixel, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: .zero, bitsPerPixel: .zero))
    return try #require(image.representation(using: .png, properties: [:]))
  }

  /// The Markdown text of an answer that shows the image.
  static let markdown = "The parser draws this chart.\n\n![Tall chart](\(fileName))\n\nIt has one bar."

  /// The Markdown text of an answer that shows an image that is not in the
  /// folder.
  static let missingMarkdown = "The parser draws this chart.\n\n![Missing chart](missing.png)"

  /// The name of a symbolic link to the image file in the folder.
  static let linkName = "link.png"

  /// The Markdown text of an answer that shows the image through the
  /// symbolic link.
  static let linkMarkdown = "The parser draws this chart.\n\n![Linked chart](\(linkName))"

  /// The name of a folder in the fixture folder. The image file is out of
  /// this folder.
  static let subfolderName = "inner"

  /// The Markdown text of an answer that shows the image file from
  /// ``subfolderName``: a file out of that folder.
  static let outsideMarkdown = "The parser draws this chart.\n\n![Outside chart](../\(fileName))"

  /// The session of an answer that shows the image, with the folder as its
  /// working folder.
  ///
  /// - Returns: The session.
  func session() -> SessionModel {
    .preview(cwd: AbsolutePath(rawValue: folder.url.path), transcript: [.agent(Self.markdown)])
  }
}
