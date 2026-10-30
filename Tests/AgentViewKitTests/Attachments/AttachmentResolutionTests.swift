import AgentViewKit
import AgentViewKitTestSupport
import EditorTestSupport
import Foundation
import Testing
import UniformTypeIdentifiers

/// The attachment of the kit. Swift Testing declares a type with the same
/// name.
private typealias Attachment = AgentViewKit.Attachment

/// Checks the type resolution of `Attachment` and the default renderer of
/// `AttachmentView`.
@Suite struct AttachmentResolutionTests {
  /// The text that each temporary file holds.
  private static let fileText = "let answer = 42\n"

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
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    defer { directory.remove() }
    let url = try directory.write(fileName, contents: Data(Self.fileText.utf8))

    let attachment = Attachment(url: url)

    #expect(AttachmentView.renderer(for: attachment.type) == renderer)
    #expect(AttachmentView.defaultRenderer(for: attachment.type) == renderer.rawValue)
  }

  @Test func aTemporaryFileGivesItsNameAndSize() throws {
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    defer { directory.remove() }
    let contents = Data(Self.fileText.utf8)
    let url = try directory.write("Main.swift", contents: contents)

    let attachment = Attachment(url: url)

    #expect(attachment.name == "Main.swift")
    #expect(attachment.size == contents.count)
    #expect(attachment.url == url)
    #expect(attachment.type.conforms(to: .swiftSource))
  }

  @Test func twoAttachmentsOfOneURLHaveTheSameID() throws {
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    defer { directory.remove() }
    let url = try directory.write("notes.md", contents: Data(Self.fileText.utf8))

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
    NameChecks.expectDistinctNames(identifiers)
    #expect(AttachmentView.identifier(for: .chip) == "attachment-chip")
  }

  @Test func theChipSizeTextIsEmptyForAnUnknownSize() {
    #expect(AttachmentChip.sizeText(nil) == nil)
    #expect(AttachmentChip.sizeText(Self.fileText.utf8.count) != nil)
  }
}
