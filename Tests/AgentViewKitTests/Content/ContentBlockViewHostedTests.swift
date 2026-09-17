import AgentViewKitTestSupport
import AppKit
import Foundation
import PackageFileSupport
import SwiftUI
import Synchronization
import Testing

@testable import AgentViewKit

/// Records each URL that an `OpenURLAction` gets.
///
/// The action handler can run off the main actor, so the list uses a lock.
/// Other hosted suites, such as `SourcesViewHostedTests`, use it too.
nonisolated final class OpenedURLRecorder: Sendable {
  /// The opened URLs, in order, behind a lock.
  private let storage = Mutex<[URL]>([])

  /// The opened URLs, in order.
  var urls: [URL] { storage.withLock { $0 } }

  /// Records a URL and tells SwiftUI that the action handled it.
  ///
  /// - Parameter url: The URL to open.
  /// - Returns: `.handled`.
  func open(_ url: URL) -> OpenURLAction.Result {
    storage.withLock { $0.append(url) }
    return .handled
  }
}

@Suite(.serialized, .hostedSerially) @MainActor struct ContentBlockViewHostedTests {
  /// The size of a view that shows one block.
  static let hostSize = CGSize(width: 600, height: 400)

  /// The time that a test waits for a view change, in seconds.
  static let waitSeconds: TimeInterval = 2

  /// The id that each block view in the tests uses.
  static let blockID = "message-1-0"

  /// The URI of the resource link in the tests.
  static let linkURI = "https://example.com/docs/guide.html"

  /// The accessibility identifier of the registered link view.
  static let customLinkIdentifier = "custom-link-card"

  /// The text of the text block in the tests.
  static let blockText = "Hello from the block"

  // MARK: - Default views

  @Test(arguments: ContentBlock.Kind.allCases)
  func eachKindMountsItsDefaultView(kind: ContentBlock.Kind) async throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let block = try Self.block(of: kind, in: directory)
    let harness = HostedViewHarness(
      ContentBlockView(block: block, id: Self.blockID), size: Self.hostSize)
    defer { harness.close() }
    let identifier = ContentBlockView.identifier(for: kind)
    await harness.pump(until: Self.waitSeconds) {
      harness.element(identifier: identifier) != nil
    }

    #expect(harness.element(identifier: identifier) != nil, "No element \(identifier).")
  }

  @Test func theIdentifierOfAKindHasThePrefixAndTheKindName() {
    #expect(ContentBlockView.identifier(for: .text) == "content-block-text")
    #expect(ContentBlockView.identifier(for: .resourceLink) == "content-block-resourceLink")
    #expect(ContentBlockView.identifier(for: .unknown) == "content-block-unknown")
  }

  @Test func aTextBlockShowsItsText() {
    let harness = HostedViewHarness(
      ContentBlockView(block: ContentBlock(text: Self.blockText), id: Self.blockID),
      size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    let labels = harness.accessibilityElements().compactMap(\.label)
    #expect(labels.contains { $0.contains(Self.blockText) })
  }

  @Test func aStructuredBlockWithARegisteredSchemaNameShowsTheRegistration() {
    let block = ContentBlock(
      content: .structured(schemaName: "Demo.Chart", payload: .object(["title": .string("Sales")])))
    let harness = HostedViewHarness(
      ContentBlockView(block: block, id: Self.blockID)
        .structuredItem("Demo.Chart") { content in
          Text("Chart \(content.payload["title"]?.stringValue ?? "")")
            .accessibilityIdentifier(Self.customLinkIdentifier)
        },
      size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: Self.customLinkIdentifier)?.label == "Chart Sales")
    #expect(harness.element(identifier: StructuredItemView.identifier(for: "Demo.Chart")) == nil)
  }

  @Test func anUnknownBlockShowsItsKindInTheRawView() {
    let block = ContentBlock(content: .unknown(kind: "future_block", raw: .object([:])))
    let harness = HostedViewHarness(
      ContentBlockView(block: block, id: Self.blockID), size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: UnknownItemView.identifier) != nil)
    let labels = harness.accessibilityElements().compactMap(\.label)
    #expect(labels.contains { $0.contains("future_block") })
  }

  @Test func aPressOnAnImageSelectsItInTheInspector() async throws {
    let selection = InspectorSelection()
    let image = ImageContent(
      data: try Self.pngData(), mimeType: "image/png", uri: "https://example.com/chart.png")
    let harness = HostedViewHarness(
      ContentBlockView(block: ContentBlock(content: .image(image)), id: Self.blockID)
        .environment(\.inspectorSelection, selection),
      size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: ImageView.imageIdentifier)?.label == "chart.png")
    try harness.press(identifier: ImageView.imageIdentifier)
    await harness.pump(until: Self.waitSeconds) { selection.attachment != nil }

    let attachment = try #require(selection.attachment)
    #expect(attachment.name == "chart.png")
    #expect(attachment.type.conforms(to: .png))
    #expect(try Data(contentsOf: attachment.url) == image.data)
  }

  @Test func bytesThatAreNotAnImageShowThePlaceholder() {
    let image = ImageContent(data: Data("not an image".utf8), mimeType: "image/png")
    let harness = HostedViewHarness(
      ContentBlockView(block: ContentBlock(content: .image(image)), id: Self.blockID),
      size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: ImageView.placeholderIdentifier) != nil)
    #expect(harness.element(identifier: ImageView.imageIdentifier) == nil)
  }

  @Test func aBinaryResourceShowsAChipWithItsName() {
    let resource = EmbeddedResource(
      uri: "file:///data/archive.zip", mimeType: "application/zip", contents: .blob(Data([1, 2, 3])))
    let harness = HostedViewHarness(
      ContentBlockView(block: ContentBlock(content: .resource(resource)), id: Self.blockID),
      size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    let labels = harness.accessibilityElements().compactMap(\.label)
    #expect(labels.contains { $0.contains("archive.zip") })
  }

  // MARK: - Registry

  @Test func aRegisteredResourceLinkViewReplacesTheDefault() {
    let harness = HostedViewHarness(
      ContentBlockView(block: Self.linkBlock(), id: Self.blockID)
        .contentBlockView(for: .resourceLink) { block in
          if case .resourceLink(let link) = block.content {
            Text("Custom \(link.name)")
              .accessibilityIdentifier(Self.customLinkIdentifier)
          }
        },
      size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: Self.customLinkIdentifier)?.label == "Custom Guide")
    #expect(harness.element(identifier: ContentBlockView.identifier(for: .resourceLink)) == nil)
    #expect(harness.element(identifier: LinkView.cardIdentifier) == nil)
  }

  // MARK: - Link

  @Test func aPressOnTheLinkCardOpensTheLink() throws {
    let recorder = OpenedURLRecorder()
    let harness = HostedViewHarness(
      ContentBlockView(block: Self.linkBlock(), id: Self.blockID)
        .environment(\.openURL, OpenURLAction(handler: recorder.open)),
      size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: LinkView.cardIdentifier)
    harness.pump()

    #expect(recorder.urls == [try #require(URL(string: Self.linkURI))])
  }

  @Test func theLinkCardIsLabeledWithTheName() {
    let harness = HostedViewHarness(
      ContentBlockView(block: Self.linkBlock(), id: Self.blockID), size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: LinkView.cardIdentifier)?.label == "Guide")
  }

  // MARK: - Audience

  @Test(arguments: ContentBlock.Kind.allCases)
  func aBlockForTheAssistantOnlyProducesNoElement(kind: ContentBlock.Kind) throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    var block = try Self.block(of: kind, in: directory)
    block.annotations = Annotations(audience: [.assistant])
    let harness = HostedViewHarness(
      VStack {
        Text("host")
        ContentBlockView(block: block, id: Self.blockID)
      },
      size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    let elements = harness.accessibilityElements()
    #expect(elements.contains { $0.label == "host" })
    #expect(
      !elements.contains { ($0.identifier ?? "").hasPrefix(ContentBlockView.identifierPrefix) })
    #expect(elements.compactMap(\.label).allSatisfy { !$0.contains(Self.blockText) })
    #expect(harness.element(identifier: LinkView.cardIdentifier) == nil)
  }

  // MARK: - Files

  @Test func aWrittenBlockFileKeepsTheBytesAndTheName() async throws {
    let data = Data("block bytes".utf8)
    let first = try #require(await ContentBlockFile.write(data, named: "clip.wav"))
    let second = try #require(await ContentBlockFile.write(data, named: "clip.wav"))

    #expect(first == second)
    #expect(first.lastPathComponent == "clip.wav")
    #expect(try Data(contentsOf: first) == data)
  }

  @Test func theFileNameComesFromTheURIOrTheMIMEType() {
    #expect(
      ContentBlockFile.fileName(uri: "https://example.com/a/chart.png", mimeType: "image/png", stem: "image")
        == "chart.png")
    #expect(ContentBlockFile.fileName(uri: nil, mimeType: "image/png", stem: "image") == "image.png")
    #expect(ContentBlockFile.fileName(uri: "https://example.com/", mimeType: "audio/wav", stem: "audio") == "audio.wav")
    #expect(ContentBlockFile.fileName(uri: nil, mimeType: "no/such-type", stem: "audio") == "audio")
  }

  // MARK: - Web views

  @Test func noSourceFileUsesAWebView() throws {
    let files = try PackageFiles.swiftFiles(in: PackageFiles.file("Sources"))
    for file in files {
      let text = try String(contentsOf: file, encoding: .utf8)
      #expect(!text.contains("import WebKit"), "\(file.lastPathComponent) imports WebKit.")
      #expect(!text.contains("WKWebView"), "\(file.lastPathComponent) uses WKWebView.")
    }
  }

  // MARK: - Helpers

  /// Makes the resource link block of the tests.
  ///
  /// - Returns: A link block named `Guide`.
  static func linkBlock() -> ContentBlock {
    ContentBlock(content: .resourceLink(ResourceLink(name: "Guide", uri: linkURI, mimeType: "text/html")))
  }

  /// Makes one block of a kind.
  ///
  /// - Parameters:
  ///   - kind: The kind of the block.
  ///   - directory: The directory for the file of an attachment block.
  /// - Returns: The block.
  /// - Throws: The error of a file write.
  static func block(of kind: ContentBlock.Kind, in directory: TemporaryDirectory) throws -> ContentBlock {
    switch kind {
    case .text:
      ContentBlock(text: blockText)
    case .image:
      ContentBlock(content: .image(ImageContent(data: try pngData(), mimeType: "image/png")))
    case .audio:
      ContentBlock(content: .audio(AudioContent(data: Data([0, 1, 2, 3]), mimeType: "audio/wav")))
    case .resourceLink:
      linkBlock()
    case .resource:
      ContentBlock(
        content: .resource(
          EmbeddedResource(uri: "file:///notes.txt", mimeType: "text/plain", contents: .text(blockText))))
    case .attachment:
      ContentBlock(
        content: .attachment(try directory.file(named: "blob.bin", contents: Data(blockText.utf8))))
    case .structured:
      ContentBlock(content: .structured(schemaName: "Demo.Chart", payload: .object(["title": .string("Sales")])))
    case .unknown:
      ContentBlock(content: .unknown(kind: "future_block", raw: .string(blockText)))
    }
  }

  /// Makes the bytes of a small PNG image.
  ///
  /// - Returns: The PNG data.
  /// - Throws: An error when AppKit cannot make the image.
  static func pngData() throws -> Data {
    let representation = try #require(
      NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: 4, pixelsHigh: 4, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
    return try #require(representation.representation(using: .png, properties: [:]))
  }
}
