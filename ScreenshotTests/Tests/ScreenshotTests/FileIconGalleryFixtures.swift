@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorStyle
import EditorTestSupport
import SwiftUI
import Testing
import UniformTypeIdentifiers

/// The files of the kit with the look of Finder (D196), for the review
/// gallery: the ``AttachmentChip`` of files of several types, and the
/// ``ArtifactView`` of a PDF file, each with the Quick Look thumbnail of its
/// file.
///
/// The fixtures write real files and load the thumbnail of each file into
/// the cache of ``FileThumbnails`` before the capture. So each view shows the
/// thumbnail at its first draw, and the capture waits for no load.
@MainActor
struct FileIconGalleryFixtures {
  /// The size of the image, in points.
  static let size = CGSize(width: SnapshotFixtures.narrowWidth, height: 520)

  /// The size of each thumbnail in the cache: larger than each view needs.
  static let thumbnailSize = CGSize(width: 64, height: 64)

  /// The scale of each thumbnail in the cache.
  static let thumbnailScale: CGFloat = 2

  /// The folder of the files.
  let folder: TemporaryFolder

  /// The files of the chips: an image, a PDF, a source file, a Markdown file
  /// and a file of a type that has no thumbnail.
  let files: [AgentViewKit.Attachment]

  /// The PDF file of the artifact.
  let pdf: AgentViewKit.Attachment

  /// Writes the files in a new temporary folder and loads their thumbnails.
  ///
  /// - Throws: The error of a write.
  init() async throws {
    let folder = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    self.folder = folder
    let image = AgentViewKit.Attachment(url: try folder.write("Sunset.png", contents: try Self.pngData()))
    let pdf = AgentViewKit.Attachment(url: try folder.write("Report.pdf", contents: Self.pdfData()))
    let source = try AttachmentFixtures.attachment(named: "Board.swift", in: folder)
    let markdown = AgentViewKit.Attachment(
      url: try folder.write("README.md", contents: Data("# Board\n\nA kanban board.\n".utf8)))
    let binary = try AttachmentFixtures.attachment(named: "notes.bin", in: folder)
    files = [image, pdf, source, markdown, binary]
    self.pdf = pdf
    for file in files {
      _ = await FileThumbnails.thumbnail(of: file.url, size: Self.thumbnailSize, scale: Self.thumbnailScale)
    }
  }

  /// Removes the folder and its files.
  func remove() {
    folder.remove()
  }

  /// The chips over the artifact.
  var gallery: some View {
    VStack(alignment: .leading, spacing: EditorStyle.default.tile.margin) {
      ForEach(files) { file in
        AttachmentChip(file)
      }
      ArtifactView(
        artifact: ArtifactPayload(id: "report", title: "Report", type: UTType.pdf.identifier, url: pdf.url))
    }
    .padding(EditorStyle.default.tile.margin)
  }

  /// A PNG image of a gradient.
  ///
  /// - Returns: The encoded image.
  /// - Throws: An error when the image cannot be encoded.
  static func pngData() throws -> Data {
    let side = 256
    let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
      NSGradient(starting: .systemOrange, ending: .systemPurple)?.draw(in: rect, angle: 90)
      return true
    }
    let representation = try #require(
      image.cgImage(forProposedRect: nil, context: nil, hints: nil).map(NSBitmapImageRep.init(cgImage:)))
    return try #require(representation.representation(using: .png, properties: [:]))
  }

  /// A PDF document of one page with a title and a line of text.
  ///
  /// - Returns: The document.
  static func pdfData() -> Data {
    let data = NSMutableData()
    var box = CGRect(x: 0, y: 0, width: 612, height: 792)
    guard let consumer = CGDataConsumer(data: data), let context = CGContext(consumer: consumer, mediaBox: &box, nil)
    else { return Data() }
    context.beginPDFPage(nil)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    ("Quarterly report" as NSString).draw(
      at: NSPoint(x: 72, y: 700), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 36)])
    ("Each invoice now shows the currency of the customer." as NSString).draw(
      at: NSPoint(x: 72, y: 650), withAttributes: [.font: NSFont.systemFont(ofSize: 14)])
    NSGraphicsContext.current = nil
    context.endPDFPage()
    context.closePDF()
    return data as Data
  }
}
