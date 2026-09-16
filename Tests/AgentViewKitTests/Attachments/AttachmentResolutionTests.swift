import AgentViewKit
import Foundation
import PackageFileSupport
import Testing
import UniformTypeIdentifiers

/// The attachment of the kit. Swift Testing declares a type with the same
/// name.
private typealias Attachment = AgentViewKit.Attachment

/// Checks the type resolution of `Attachment` and the default renderer
/// table of `AttachmentView`, also against `Docs/decisions/attachment-types.md`.
@Suite struct AttachmentResolutionTests {
  /// The decision file, relative to the package root.
  private static let decisionPath = "Docs/decisions/attachment-types.md"

  /// The header row of the renderer table.
  private static let header = "| UTType | source support | default renderer |"

  /// The number of cells in one row of the renderer table.
  private static let columnCount = 3

  /// The text that each temporary file holds.
  private static let fileText = "let answer = 42\n"

  /// One parsed row of the renderer table.
  private struct Row {
    /// The type identifier, without backticks.
    let typeIdentifier: String
    /// The renderer name, without backticks.
    let renderer: String
  }

  /// The errors that the row mapping can report.
  private enum TableError: Error {
    /// A row does not have ``AttachmentResolutionTests/columnCount`` cells.
    case wrongCellCount([String])
  }

  /// Parses the rows of the renderer table.
  ///
  /// - Returns: The rows, in file order.
  /// - Throws: ``MarkdownTable/MissingTable`` when the file has no renderer
  ///   table, or ``TableError`` when a row is not in the expected form.
  private static func tableRows() throws -> [Row] {
    let text = try PackageFiles.text(of: decisionPath)
    return try MarkdownTable.rows(in: text, header: header).map { cells in
      guard cells.count == columnCount else {
        throw TableError.wrongCellCount(cells)
      }
      return Row(typeIdentifier: cells[0], renderer: cells[2])
    }
  }

  // MARK: - Decision table

  @Test func eachTableRowMatchesTheDefaultRenderer() throws {
    let rows = try Self.tableRows()
    #expect(!rows.isEmpty)
    for row in rows {
      let type = try #require(UTType(row.typeIdentifier), "Unknown type \(row.typeIdentifier).")
      #expect(
        AttachmentView.defaultRenderer(for: type) == row.renderer,
        "The row \(row.typeIdentifier) does not match the code.")
    }
  }

  @Test func theTableNamesEachRenderer() throws {
    let rows = try Self.tableRows()
    #expect(
      Set(rows.map(\.renderer)) == Set(AttachmentView.Renderer.allCases.map(\.rawValue)))
  }

  // MARK: - Conformance walk

  @Test(arguments: [
    ("Main.swift", AttachmentView.Renderer.code),
    ("script.py", .code),
    ("blob.bin", .chip),
    ("notes.md", .text),
    ("readme.txt", .text),
    ("photo.png", .image),
    ("paper.pdf", .pdf),
    ("song.mp3", .audio),
    ("clip.mov", .movie),
    ("data.json", .chip),
  ])
  func aTemporaryFileResolvesToItsRenderer(
    fileName: String, renderer: AttachmentView.Renderer
  ) throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let url = try directory.file(named: fileName, contents: Data(Self.fileText.utf8))

    let attachment = Attachment(url: url)

    #expect(AttachmentView.renderer(for: attachment.type) == renderer)
    #expect(AttachmentView.defaultRenderer(for: attachment.type) == renderer.rawValue)
  }

  @Test func aTemporaryFileGivesItsNameAndSize() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let contents = Data(Self.fileText.utf8)
    let url = try directory.file(named: "Main.swift", contents: contents)

    let attachment = Attachment(url: url)

    #expect(attachment.name == "Main.swift")
    #expect(attachment.size == contents.count)
    #expect(attachment.url == url)
    #expect(attachment.type.conforms(to: .swiftSource))
  }

  @Test func twoAttachmentsOfOneURLHaveTheSameID() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let url = try directory.file(named: "notes.md", contents: Data(Self.fileText.utf8))

    #expect(Attachment(url: url).id == Attachment(url: url).id)
  }

  @Test func aURLWithNoFileResolvesByItsExtension() throws {
    let url = try #require(URL(string: "https://example.com/files/paper.pdf"))

    let attachment = Attachment(url: url)

    #expect(attachment.type == .pdf)
    #expect(attachment.name == "paper.pdf")
    #expect(attachment.size == nil)
  }

  @Test func aURLWithNoFileAndAnUnknownExtensionIsData() throws {
    let url = try #require(URL(string: "https://example.com/files/archive.nosuchextension"))

    let attachment = Attachment(url: url)

    #expect(attachment.type == .data)
    #expect(AttachmentView.renderer(for: attachment.type) == .chip)
  }

  @Test func aSourceTypeWinsOverPlainText() {
    #expect(UTType.swiftSource.conforms(to: .plainText))
    #expect(AttachmentView.renderer(for: .swiftSource) == .code)
  }

  @Test func eachRendererHasADistinctIdentifier() {
    let identifiers = AttachmentView.Renderer.allCases.map(AttachmentView.identifier(for:))
    #expect(Set(identifiers).count == AttachmentView.Renderer.allCases.count)
    #expect(AttachmentView.identifier(for: .chip) == "attachment-chip")
  }

  @Test func theChipSizeTextIsEmptyForAnUnknownSize() {
    #expect(AttachmentChip.sizeText(nil) == nil)
    #expect(AttachmentChip.sizeText(Self.fileText.utf8.count) != nil)
  }
}
