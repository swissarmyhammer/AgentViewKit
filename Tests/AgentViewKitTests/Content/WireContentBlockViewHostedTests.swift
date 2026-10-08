import AgentViewKitTestSupport
import AppKit
import Foundation
import FoundationModelsACP
import PackageFileSupport
import SwiftUI
import Testing

@testable import AgentViewKit

/// The content block views of the ACP `ContentBlock` values that a transcript
/// entry holds. Each block shows with the look of the default view of its
/// kind, and no kit content block is between the block and the view.
@Suite(.serialized, .hostedSerially) @MainActor struct WireContentBlockViewHostedTests {
  /// The size of a view that shows one block.
  static let hostSize = CGSize(width: 600, height: 400)

  /// The time that a test waits for a view change, in seconds.
  static let waitSeconds: TimeInterval = 2

  /// The id that each block view in the tests uses.
  static let blockID = "entry-1-0"

  /// The text of the text blocks in the tests.
  static let blockText = "Hello from the wire block"

  /// The name of the resource link in the tests.
  static let linkName = "Guide"

  /// The URI of the resource link in the tests.
  static let linkURI = "https://example.com/docs/guide.html"

  /// The URI of the image in the tests.
  static let imageURI = "https://example.com/chart.png"

  /// The file name of the image in the tests.
  static let imageName = "chart.png"

  /// The URI of the binary resource in the tests.
  static let archiveURI = "file:///data/archive.zip"

  /// The file name of the binary resource in the tests.
  static let archiveName = "archive.zip"

  /// The type name of the unknown block in the tests.
  static let unknownKind = "future_block"

  /// Data that is not valid base64 text.
  static let notBase64 = "not base64 !"

  /// Bytes that are valid base64 data but not an image.
  static let notImageBytes = Data("not an image".utf8)

  /// The bytes of the sound in the tests.
  static let audioBytes = Data([0, 1, 2, 3])

  /// The bytes of the binary resource in the tests.
  static let archiveBytes = Data([1, 2, 3])

  /// The bytes of the block file in the file tests.
  static let fileBytes = Data("block bytes".utf8)

  /// The name of the block file in the file tests.
  static let fileName = "clip.wav"

  /// The width and the height of the test image, in pixels.
  static let pngSide = 4

  /// The number of bits of each sample of the test image.
  static let pngBitsPerSample = 8

  /// The number of samples of each pixel of the test image: red, green,
  /// blue, and alpha.
  static let pngSamplesPerPixel = 4

  /// The accessibility identifier of the registered views in the tests.
  static let customIdentifier = "custom-wire-block"

  /// The `messageId` of the agent message of the entry test.
  static let entryMessageID = "registry-m"

  /// The kinds of the ACP blocks.
  nonisolated static let wireKinds = FoundationModelsACP.ContentBlock.Kind.allCases

  /// The kinds of the ACP blocks that hold annotations. An unknown block
  /// holds none.
  nonisolated static let annotatedKinds = wireKinds.filter { $0 != .unknown }

  // MARK: - Default views

  @Test(arguments: wireKinds)
  func eachWireBlockMountsTheDefaultViewOfItsKind(kind: FoundationModelsACP.ContentBlock.Kind) async throws {
    let block = try Self.makeWireBlock(of: kind)
    let harness = HostedViewHarness(ContentBlockView(block: block, id: Self.blockID), size: Self.hostSize)
    defer { harness.close() }
    let identifier = ContentBlockView.identifier(for: kind)
    await harness.pump(until: Self.waitSeconds) {
      harness.element(identifier: identifier) != nil
    }

    #expect(harness.element(identifier: identifier) != nil, "No element \(identifier).")
  }

  @Test func theIdentifierOfAWireKindHasThePrefixAndTheKindName() {
    #expect(ContentBlockView.identifier(for: .text) == "content-block-text")
    #expect(ContentBlockView.identifier(for: .resourceLink) == "content-block-resourceLink")
    #expect(ContentBlockView.identifier(for: .unknown) == "content-block-unknown")
  }

  @Test func theKindOfEachWireBlockIsTheKindItWasMadeFor() throws {
    let kinds = try Self.wireKinds.map { try Self.makeWireBlock(of: $0).kind }
    #expect(kinds == Self.wireKinds)
  }

  @Test func aWireTextBlockShowsItsText() {
    let harness = HostedViewHarness(
      ContentBlockView(block: .text(TextContent(text: Self.blockText)), id: Self.blockID), size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    #expect(Self.labels(in: harness).contains { $0.contains(Self.blockText) })
  }

  @Test func aWireUnknownBlockShowsItsKindInTheRawView() {
    let block = FoundationModelsACP.ContentBlock.unknown(Self.unknownKind, .object([:]))
    let harness = HostedViewHarness(ContentBlockView(block: block, id: Self.blockID), size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: UnknownItemView.identifier) != nil)
    #expect(Self.labels(in: harness).contains { $0.contains(Self.unknownKind) })
  }

  // MARK: - Image

  @Test func aPressOnAWireImageSelectsItsBytesInTheInspector() async throws {
    let selection = InspectorSelection()
    let png = try Self.pngData()
    let image = FoundationModelsACP.ImageContent(
      data: png.base64EncodedString(), mimeType: MediaType(rawValue: "image/png"), uri: Self.imageURI)
    let harness = HostedViewHarness(
      ContentBlockView(block: .image(image), id: Self.blockID)
        .environment(\.inspectorSelection, selection),
      size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: ImageView.imageIdentifier)?.label == Self.imageName)
    try harness.press(identifier: ImageView.imageIdentifier)
    await harness.pump(until: Self.waitSeconds) { selection.attachment != nil }

    let attachment = try #require(selection.attachment)
    #expect(attachment.name == Self.imageName)
    #expect(attachment.type.conforms(to: .png))
    #expect(try Data(contentsOf: attachment.url) == png)
  }

  @Test func aWireImageWithDataThatIsNotBase64ShowsThePlaceholder() {
    let image = FoundationModelsACP.ImageContent(data: Self.notBase64, mimeType: MediaType(rawValue: "image/png"))
    let harness = HostedViewHarness(
      ContentBlockView(block: .image(image), id: Self.blockID), size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: ImageView.placeholderIdentifier) != nil)
    #expect(harness.element(identifier: ImageView.imageIdentifier) == nil)
  }

  @Test func aWireImageWithBytesThatAreNotAnImageShowsThePlaceholder() {
    let image = FoundationModelsACP.ImageContent(
      data: Self.notImageBytes.base64EncodedString(), mimeType: MediaType(rawValue: "image/png"))
    let harness = HostedViewHarness(
      ContentBlockView(block: .image(image), id: Self.blockID), size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: ImageView.placeholderIdentifier) != nil)
    #expect(harness.element(identifier: ImageView.imageIdentifier) == nil)
  }

  // MARK: - Audio

  @Test func aWireSoundWithDataThatIsNotBase64ShowsTheFailureLabel() async {
    let audio = FoundationModelsACP.AudioContent(data: Self.notBase64, mimeType: MediaType(rawValue: "audio/wav"))
    let harness = HostedViewHarness(
      ContentBlockView(block: .audio(audio), id: Self.blockID), size: Self.hostSize)
    defer { harness.close() }
    await harness.pump(until: Self.waitSeconds) {
      harness.element(identifier: AudioPlayerView.failureIdentifier) != nil
    }

    #expect(harness.element(identifier: AudioPlayerView.failureIdentifier) != nil)
  }

  // MARK: - Link

  @Test func aPressOnTheWireLinkCardOpensTheLinkOfTheName() throws {
    let recorder = OpenedURLRecorder()
    let harness = HostedViewHarness(
      ContentBlockView(block: Self.makeLinkBlock(), id: Self.blockID)
        .environment(\.openURL, OpenURLAction(handler: recorder.open)),
      size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: LinkView.cardIdentifier)?.label == Self.linkName)
    try harness.press(identifier: LinkView.cardIdentifier)
    harness.pump()

    #expect(recorder.urls == [try #require(URL(string: Self.linkURI))])
  }

  // MARK: - Resource

  @Test func aWireBinaryResourceShowsAChipWithItsName() {
    let resource = FoundationModelsACP.EmbeddedResource(
      resource: .object([
        "uri": .string(Self.archiveURI), "mimeType": .string("application/zip"),
        "blob": .string(Self.archiveBytes.base64EncodedString()),
      ]))
    let harness = HostedViewHarness(
      ContentBlockView(block: .resource(resource), id: Self.blockID), size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    #expect(Self.labels(in: harness).contains { $0.contains(Self.archiveName) })
  }

  @Test func aWireResourceWithNoContentsShowsTheRawView() {
    let resource = FoundationModelsACP.EmbeddedResource(resource: .object(["uri": .string(Self.archiveURI)]))
    let harness = HostedViewHarness(
      ContentBlockView(block: .resource(resource), id: Self.blockID), size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: UnknownItemView.identifier) != nil)
  }

  // MARK: - Audience

  @Test(arguments: annotatedKinds)
  func aWireBlockForTheAssistantOnlyProducesNoElement(kind: FoundationModelsACP.ContentBlock.Kind) throws {
    let assistantOnly = FoundationModelsACP.Annotations(audience: [.assistant])
    let block = try Self.makeWireBlock(of: kind, annotations: assistantOnly)
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
    #expect(!elements.contains { ($0.identifier ?? "").hasPrefix(ContentBlockView.identifierPrefix) })
    #expect(elements.compactMap(\.label).allSatisfy { !$0.contains(Self.blockText) })
    #expect(harness.element(identifier: LinkView.cardIdentifier) == nil)
  }

  // MARK: - Registry

  @Test(arguments: wireKinds)
  func aRegisteredViewReplacesTheDefaultViewOfAWireBlockOfItsKind(
    kind: FoundationModelsACP.ContentBlock.Kind
  ) throws {
    let harness = HostedViewHarness(
      ContentBlockView(block: try Self.makeWireBlock(of: kind), id: Self.blockID)
        .contentBlockView(for: kind) { _ in marker(Self.customIdentifier) },
      size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: Self.customIdentifier) != nil)
    #expect(harness.element(identifier: ContentBlockView.identifier(for: kind)) == nil)
  }

  @Test func aRegisteredLinkViewGetsTheWireBlock() {
    let harness = HostedViewHarness(
      ContentBlockView(block: Self.makeLinkBlock(), id: Self.blockID)
        .contentBlockView(for: .resourceLink, Self.makeCustomLinkView(of:)),
      size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: Self.customIdentifier)?.label == Self.linkName)
    #expect(harness.element(identifier: LinkView.cardIdentifier) == nil)
  }

  @Test func aRegisteredLinkViewReplacesTheLinkCardInTheRowOfAnAgentMessageEntry() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    try await session.sendUpdate(
      WireBlockJSON.makeChunk(
        "agent_message_chunk", messageID: Self.entryMessageID,
        block: WireBlockJSON.makeResourceLink(name: Self.linkName, uri: Self.linkURI)))
    let model = session.model
    _ = await waitUntil { !model.transcript.isEmpty }
    let entry = try #require(model.transcript.first)

    let harness = HostedViewHarness(
      ItemRow(entry: entry).contentBlockView(for: .resourceLink, Self.makeCustomLinkView(of:)),
      size: Self.hostSize)
    defer { harness.close() }
    await harness.pump(until: Self.waitSeconds) {
      harness.element(identifier: Self.customIdentifier) != nil
    }

    #expect(harness.element(identifier: Self.customIdentifier)?.label == Self.linkName)
    #expect(harness.element(identifier: LinkView.cardIdentifier) == nil)
    #expect(harness.element(identifier: ItemRow.identifier(for: entry.rowKey)) != nil)
  }

  // MARK: - Files

  @Test func aWrittenBlockFileKeepsTheBytesAndTheName() async throws {
    let first = try #require(await ContentBlockFile.write(Self.fileBytes, named: Self.fileName))
    let second = try #require(await ContentBlockFile.write(Self.fileBytes, named: Self.fileName))

    #expect(first == second)
    #expect(first.lastPathComponent == Self.fileName)
    #expect(try Data(contentsOf: first) == Self.fileBytes)
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

  /// Makes the registered view of a resource link block in the tests: a text
  /// with the name of the link and the identifier ``customIdentifier``.
  ///
  /// - Parameter block: The ACP block that the registry gives.
  /// - Returns: The text, or no view for a block that is not a resource link.
  @ViewBuilder
  static func makeCustomLinkView(of block: FoundationModelsACP.ContentBlock) -> some View {
    if case .resourceLink(let link) = block {
      Text(link.name).accessibilityIdentifier(customIdentifier)
    }
  }

  /// The labels of the accessibility elements of `harness`.
  ///
  /// - Parameter harness: The harness that shows the block.
  /// - Returns: Each label.
  static func labels<Content: View>(in harness: HostedViewHarness<Content>) -> [String] {
    harness.accessibilityElements().compactMap(\.label)
  }

  /// Makes the bytes of a small PNG image.
  ///
  /// - Returns: The PNG data.
  /// - Throws: An error when AppKit cannot make the image.
  static func pngData() throws -> Data {
    let representation = try #require(
      NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pngSide, pixelsHigh: pngSide, bitsPerSample: pngBitsPerSample,
        samplesPerPixel: pngSamplesPerPixel, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0))
    return try #require(representation.representation(using: .png, properties: [:]))
  }

  /// Makes the resource link block of the tests.
  ///
  /// - Parameter annotations: The annotations of the block.
  /// - Returns: A link block named ``linkName``.
  static func makeLinkBlock(annotations: FoundationModelsACP.Annotations? = nil) -> FoundationModelsACP.ContentBlock {
    .resourceLink(
      FoundationModelsACP.ResourceLink(
        name: linkName, uri: linkURI, annotations: annotations, mimeType: MediaType(rawValue: "text/html")))
  }

  /// Makes one ACP block of a kind.
  ///
  /// - Parameters:
  ///   - kind: The kind of the block.
  ///   - annotations: The annotations of the block. An unknown block holds
  ///     none.
  /// - Returns: The block.
  /// - Throws: An error when AppKit cannot make the image.
  static func makeWireBlock(
    of kind: FoundationModelsACP.ContentBlock.Kind, annotations: FoundationModelsACP.Annotations? = nil
  ) throws -> FoundationModelsACP.ContentBlock {
    switch kind {
    case .text:
      .text(TextContent(text: blockText, annotations: annotations))
    case .image:
      .image(
        FoundationModelsACP.ImageContent(
          data: try pngData().base64EncodedString(),
          mimeType: MediaType(rawValue: "image/png"), annotations: annotations))
    case .audio:
      .audio(
        FoundationModelsACP.AudioContent(
          data: audioBytes.base64EncodedString(), mimeType: MediaType(rawValue: "audio/wav"),
          annotations: annotations))
    case .resourceLink:
      makeLinkBlock(annotations: annotations)
    case .resource:
      .resource(
        FoundationModelsACP.EmbeddedResource(
          resource: .object([
            "uri": .string("file:///notes.txt"), "mimeType": .string("text/plain"), "text": .string(blockText),
          ]),
          annotations: annotations))
    case .unknown:
      .unknown(unknownKind, .object(["note": .string(blockText)]))
    }
  }
}
