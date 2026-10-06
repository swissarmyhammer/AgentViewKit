import Foundation
import FoundationModelsACP
import Testing

@testable import AgentViewKit

/// The attached files of one test, in a new temporary directory.
private struct AttachedFiles {
  /// The first byte of the PNG signature. It is not an ASCII byte.
  static let pngSignatureFirstByte: UInt8 = 0x89

  /// The ASCII letters that follow the first byte of the PNG signature.
  static let pngSignatureLetters = "PNG"

  /// The ASCII letters that start the local file header of a ZIP file.
  static let zipHeaderLetters = "PK"

  /// The third byte of the local file header signature of a ZIP file.
  static let zipHeaderThirdByte: UInt8 = 0x03

  /// The fourth byte of the local file header signature of a ZIP file.
  static let zipHeaderFourthByte: UInt8 = 0x04

  /// A byte that is not valid in UTF-8 text. It makes the content build send
  /// the archive file as a `blob`, not as `text`.
  static let notUTF8Byte: UInt8 = 0xFF

  /// The bytes of the image file. The content build reads the type from the
  /// file name extension, so the bytes do not have to be a full image.
  static let imageBytes = Data([pngSignatureFirstByte] + Array(pngSignatureLetters.utf8))

  /// The text of the text file.
  static let notesText = "Line one\nLine two\n"

  /// The bytes of the file that is not text and not an image.
  static let archiveBytes = Data(
    Array(zipHeaderLetters.utf8) + [zipHeaderThirdByte, zipHeaderFourthByte, notUTF8Byte])

  /// The directory that holds the files.
  let directory: URL

  /// An image file.
  let image: URL

  /// A text file.
  let notes: URL

  /// A file that is not text and not an image.
  let archive: URL

  /// A text file that does not exist, so the content build cannot read it.
  let missing: URL

  /// Writes the files to a new temporary directory.
  ///
  /// - Throws: The file system error when a write fails.
  init() throws {
    directory = FileManager.default.temporaryDirectory
      .appending(path: "PromptCapabilitiesTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    image = directory.appending(path: "shot.png")
    notes = directory.appending(path: "notes.txt")
    archive = directory.appending(path: "bundle.zip")
    missing = directory.appending(path: "missing.txt")
    try Self.imageBytes.write(to: image)
    try Data(Self.notesText.utf8).write(to: notes)
    try Self.archiveBytes.write(to: archive)
  }

  /// Removes the directory and its files.
  func remove() {
    try? FileManager.default.removeItem(at: directory)
  }
}

/// The prompt capabilities of one test row.
enum CapabilityCase: String, CaseIterable, CustomTestStringConvertible {
  /// The agent advertises no prompt capability.
  case none
  /// The agent advertises `image` only.
  case image
  /// The agent advertises `embeddedContext` only.
  case embeddedContext
  /// The agent advertises `image` and `embeddedContext`.
  case both

  /// The capabilities of the case, or `nil` when the agent sends no
  /// `prompt` member.
  var capabilities: PromptCapabilities? {
    switch self {
    case .none: nil
    case .image: PromptCapabilities(image: PromptImageCapabilities())
    case .embeddedContext: PromptCapabilities(embeddedContext: PromptEmbeddedContextCapabilities())
    case .both:
      PromptCapabilities(embeddedContext: PromptEmbeddedContextCapabilities(), image: PromptImageCapabilities())
    }
  }

  /// The block types of a prompt with an image file and a text file.
  var expectedTypes: [String] {
    switch self {
    case .none: ["text", "resource_link"]
    case .image: ["text", "image", "resource_link"]
    case .embeddedContext: ["text", "resource"]
    case .both: ["text", "image", "resource"]
    }
  }

  var testDescription: String { rawValue }
}

/// The content build of the composer for each set of prompt capabilities
/// (update.md §9.4).
@Suite struct PromptCapabilitiesTests {
  /// The text of each prompt.
  static let message = "Look"

  /// The wire type of a block.
  ///
  /// - Parameter block: The block.
  /// - Returns: The `type` value of the block on the wire.
  static func wireType(of block: FoundationModelsACP.ContentBlock) -> String {
    switch block {
    case .text: "text"
    case .image: "image"
    case .audio: "audio"
    case .resourceLink: "resource_link"
    case .resource: "resource"
    case .unknown(let type, _): type
    }
  }

  /// The embedded resource value of a block.
  ///
  /// - Parameter block: The block.
  /// - Returns: The `resource` value, or `nil` when the block is not an
  ///   embedded resource.
  static func embeddedResource(of block: FoundationModelsACP.ContentBlock) -> FoundationModelsACP.JSONValue? {
    if case .resource(let resource) = block { resource.resource } else { nil }
  }

  @Test(arguments: CapabilityCase.allCases)
  func eachCapabilityCombinationGivesItsBlockTypes(_ capabilityCase: CapabilityCase) throws {
    let files = try AttachedFiles()
    defer { files.remove() }
    let input = UserInput(text: Self.message, attachments: [files.image, files.notes])

    let blocks = PromptContent.makeBlocks(for: input, accepting: capabilityCase.capabilities)

    #expect(blocks.map(Self.wireType(of:)) == capabilityCase.expectedTypes)
    #expect(blocks.first == .text(FoundationModelsACP.TextContent(text: Self.message)))
  }

  @Test func anAcceptedImageIsAnImageBlockWithBase64Data() throws {
    let files = try AttachedFiles()
    defer { files.remove() }
    let input = UserInput(text: Self.message, attachments: [files.image])

    let blocks = PromptContent.makeBlocks(for: input, accepting: CapabilityCase.image.capabilities)

    let expected = FoundationModelsACP.ImageContent(
      data: AttachedFiles.imageBytes.base64EncodedString(), mimeType: MediaType(rawValue: "image/png"),
      uri: files.image.absoluteString)
    #expect(blocks.last == .image(expected))
  }

  @Test func withEmbeddedContextATextFileIsAnEmbeddedTextResource() throws {
    let files = try AttachedFiles()
    defer { files.remove() }
    let input = UserInput(text: Self.message, attachments: [files.notes])

    let blocks = PromptContent.makeBlocks(for: input, accepting: CapabilityCase.embeddedContext.capabilities)

    let resource = try #require(blocks.last.flatMap(Self.embeddedResource(of:)))
    #expect(
      resource
        == .object([
          "uri": .string(files.notes.absoluteString), "mimeType": .string("text/plain"),
          "text": .string(AttachedFiles.notesText),
        ]))
  }

  @Test func withEmbeddedContextAFileThatIsNotTextIsAnEmbeddedBlobResource() throws {
    let files = try AttachedFiles()
    defer { files.remove() }
    let input = UserInput(text: Self.message, attachments: [files.archive])

    let blocks = PromptContent.makeBlocks(for: input, accepting: CapabilityCase.embeddedContext.capabilities)

    let resource = try #require(blocks.last.flatMap(Self.embeddedResource(of:)))
    #expect(
      resource
        == .object([
          "uri": .string(files.archive.absoluteString), "mimeType": .string("application/zip"),
          "blob": .string(AttachedFiles.archiveBytes.base64EncodedString()),
        ]))
  }

  @Test func withoutEmbeddedContextATextFileIsAResourceLink() throws {
    let files = try AttachedFiles()
    defer { files.remove() }
    let input = UserInput(text: Self.message, attachments: [files.notes])

    let blocks = PromptContent.makeBlocks(for: input, accepting: CapabilityCase.image.capabilities)

    let expected = FoundationModelsACP.ResourceLink(
      name: "notes.txt", uri: files.notes.absoluteString, mimeType: MediaType(rawValue: "text/plain"))
    #expect(blocks.last == .resourceLink(expected))
  }

  @Test func withEmbeddedContextAFileThatCannotBeReadIsAResourceLink() throws {
    let files = try AttachedFiles()
    defer { files.remove() }
    let input = UserInput(text: Self.message, attachments: [files.missing])

    let blocks = PromptContent.makeBlocks(for: input, accepting: CapabilityCase.both.capabilities)

    #expect(blocks.map(Self.wireType(of:)) == ["text", "resource_link"])
  }

  @Test(arguments: CapabilityCase.allCases)
  func anImageIsAcceptedOnlyWhenTheAgentAdvertisesImage(_ capabilityCase: CapabilityCase) throws {
    let files = try AttachedFiles()
    defer { files.remove() }
    let advertisesImage = [.image, .both].contains(capabilityCase)

    #expect(PromptContent.isAccepted(attachmentAt: files.image, by: capabilityCase.capabilities) == advertisesImage)
  }

  @Test(arguments: CapabilityCase.allCases)
  func aFileThatIsNotAnImageIsAlwaysAccepted(_ capabilityCase: CapabilityCase) throws {
    let files = try AttachedFiles()
    defer { files.remove() }

    #expect(PromptContent.isAccepted(attachmentAt: files.notes, by: capabilityCase.capabilities))
    #expect(PromptContent.isAccepted(attachmentAt: files.archive, by: capabilityCase.capabilities))
  }
}
