@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorTestSupport
import Foundation
import QuickLookThumbnailing
import Testing
import UniformTypeIdentifiers

/// Counts the requests of a fake generator and gives one image for each.
@MainActor private final class GenerateLog {
  /// The requests, in order.
  private(set) var requests: [QLThumbnailGenerator.Request] = []

  /// The image that the generator gives, or `nil` for no thumbnail.
  let image: NSImage?

  init(image: NSImage? = NSImage(size: NSSize(width: 1, height: 1))) {
    self.image = image
  }

  /// Records `request` and gives ``image``.
  func generate(_ request: QLThumbnailGenerator.Request) async -> NSImage? {
    requests.append(request)
    return image
  }
}

/// The Finder look of a file (D196): the Quick Look thumbnail, with the
/// `NSWorkspace` icon as the placeholder and the fallback.
@MainActor @Suite struct FileThumbnailsTests {
  /// The size of each thumbnail of the tests, in points.
  static let size = CGSize(width: 28, height: 28)

  /// The scale of the screen of the tests.
  static let scale: CGFloat = 2

  /// Writes one file in a new temporary folder.
  static func file(named name: String = "notes.txt") throws -> (TemporaryFolder, AgentViewKit.Attachment) {
    let folder = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    return (folder, try AttachmentFixtures.attachment(named: name, in: folder))
  }

  // MARK: - Request

  @Test func theRequestAsksForTheThumbnailAndThenTheIconInIconMode() {
    let url = URL(filePath: "/tmp/notes.txt")

    let request = FileThumbnails.request(for: url, size: Self.size, scale: Self.scale)

    #expect(request.representationTypes == [.thumbnail, .icon])
    #expect(request.iconMode)
  }

  @Test func theRequestHasTheSizeAndTheScaleOfTheScreen() {
    let request = FileThumbnails.request(for: URL(filePath: "/tmp/notes.txt"), size: Self.size, scale: Self.scale)

    #expect(request.size == Self.size)
    #expect(request.scale == Self.scale)
  }

  // MARK: - Load and cache

  @Test func aFileGetsTheImageOfTheGenerator() async throws {
    let (folder, file) = try Self.file()
    defer { folder.remove() }
    let log = GenerateLog()

    let image = await FileThumbnails.thumbnail(of: file.url, size: Self.size, scale: Self.scale, generate: log.generate)

    #expect(image === log.image)
    #expect(log.requests.map(\.scale) == [Self.scale])
  }

  @Test func aSecondLoadOfTheFileUsesTheCache() async throws {
    let (folder, file) = try Self.file()
    defer { folder.remove() }
    let log = GenerateLog()
    _ = await FileThumbnails.thumbnail(of: file.url, size: Self.size, scale: Self.scale, generate: log.generate)

    let image = await FileThumbnails.thumbnail(of: file.url, size: Self.size, scale: Self.scale, generate: log.generate)

    #expect(image === log.image)
    #expect(log.requests.count == 1)
    #expect(FileThumbnails.cached(file.url) === log.image)
  }

  @Test func aLargerSizeMakesANewThumbnail() async throws {
    let (folder, file) = try Self.file()
    defer { folder.remove() }
    let log = GenerateLog()
    _ = await FileThumbnails.thumbnail(of: file.url, size: Self.size, scale: 1, generate: log.generate)

    _ = await FileThumbnails.thumbnail(of: file.url, size: Self.size, scale: Self.scale, generate: log.generate)

    #expect(log.requests.map(\.scale) == [1, Self.scale])
  }

  @Test func aChangedFileMakesANewThumbnail() async throws {
    let (folder, file) = try Self.file()
    defer { folder.remove() }
    let log = GenerateLog()
    _ = await FileThumbnails.thumbnail(of: file.url, size: Self.size, scale: Self.scale, generate: log.generate)
    try FileManager.default.setAttributes(
      [.modificationDate: Date(timeIntervalSinceReferenceDate: 0)], ofItemAtPath: file.url.path(percentEncoded: false))

    _ = await FileThumbnails.thumbnail(of: file.url, size: Self.size, scale: Self.scale, generate: log.generate)

    #expect(log.requests.count == 2)
  }

  @Test func noThumbnailGivesNilAndCachesNothing() async throws {
    let (folder, file) = try Self.file()
    defer { folder.remove() }
    let log = GenerateLog(image: nil)

    let image = await FileThumbnails.thumbnail(of: file.url, size: Self.size, scale: Self.scale, generate: log.generate)

    #expect(image == nil)
    #expect(FileThumbnails.cached(file.url) == nil)
  }

  @Test func aURLThatIsNotAFileAsksForNoThumbnail() async throws {
    let log = GenerateLog()
    let url = try #require(URL(string: "https://example.com/notes.txt"))

    let image = await FileThumbnails.thumbnail(of: url, size: Self.size, scale: Self.scale, generate: log.generate)

    #expect(image == nil)
    #expect(log.requests.isEmpty)
  }

  @Test func aMissingFileAsksForNoThumbnail() async {
    let log = GenerateLog()
    let url = URL(filePath: "/nonexistent-\(UUID().uuidString)/notes.txt")

    let image = await FileThumbnails.thumbnail(of: url, size: Self.size, scale: Self.scale, generate: log.generate)

    #expect(image == nil)
    #expect(log.requests.isEmpty)
  }

  // MARK: - Placeholder and fallback

  @Test func thePlaceholderOfAFileIsTheIconOfTheFile() throws {
    let (folder, file) = try Self.file()
    defer { folder.remove() }

    #expect(
      FileThumbnails.placeholderSource(url: file.url, type: file.type) == .file(file.url.path(percentEncoded: false)))
  }

  @Test func thePlaceholderOfAMissingFileIsTheIconOfItsType() {
    let url = URL(filePath: "/nonexistent-\(UUID().uuidString)/notes.txt")

    #expect(FileThumbnails.placeholderSource(url: url, type: .plainText) == .type(.plainText))
  }

  @Test func thePlaceholderOfContentWithNoFileIsTheIconOfItsType() {
    #expect(FileThumbnails.placeholderSource(url: nil, type: .pdf) == .type(.pdf))
  }

  @Test func theIconShowsTheLoadedThumbnail() {
    let thumbnail = NSImage(size: NSSize(width: 1, height: 1))

    #expect(FileIcon.image(url: nil, type: .plainText, thumbnail: thumbnail) === thumbnail)
  }

  @Test func theIconShowsTheCachedThumbnailBeforeTheLoad() async throws {
    let (folder, file) = try Self.file()
    defer { folder.remove() }
    let log = GenerateLog()
    _ = await FileThumbnails.thumbnail(of: file.url, size: Self.size, scale: Self.scale, generate: log.generate)

    #expect(FileIcon.image(url: file.url, type: file.type, thumbnail: nil) === log.image)
  }

  @Test func theIconWithNoThumbnailShowsAnImage() {
    let image = FileIcon.image(url: nil, type: .pdf, thumbnail: nil)

    #expect(image.size != .zero)
  }

  // MARK: - Quick Look

  @Test func quickLookMakesAnImageOfAFile() async throws {
    let (folder, file) = try Self.file(named: "Board.swift")
    defer { folder.remove() }

    let image = await FileThumbnails.generate(
      FileThumbnails.request(for: file.url, size: Self.size, scale: Self.scale))

    #expect(image != nil)
  }
}
