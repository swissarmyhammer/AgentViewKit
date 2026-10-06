import AgentViewKitTestSupport
import AppKit
import Foundation
import FoundationModelsACP
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

  /// The bytes of the sound in the tests.
  static let audioBytes = Data([0, 1, 2, 3])

  /// The bytes of the binary resource in the tests.
  static let archiveBytes = Data([1, 2, 3])

  /// The kinds of the kit default views that an ACP block can show. ACP
  /// defines no attachment block.
  nonisolated static let wireKinds = AgentViewKit.ContentBlock.Kind.allCases.filter { $0 != .attachment }

  /// The kinds of the ACP blocks that hold annotations. An unknown block
  /// holds none.
  nonisolated static let annotatedKinds = wireKinds.filter { $0 != .unknown }

  // MARK: - Default views

  @Test(arguments: wireKinds)
  func eachWireBlockMountsTheDefaultViewOfItsKind(kind: AgentViewKit.ContentBlock.Kind) async throws {
    let block = try #require(try Self.makeWireBlock(of: kind))
    let harness = HostedViewHarness(ContentBlockView(block: block, id: Self.blockID), size: Self.hostSize)
    defer { harness.close() }
    let identifier = ContentBlockView.identifier(for: kind)
    await harness.pump(until: Self.waitSeconds) {
      harness.element(identifier: identifier) != nil
    }

    #expect(harness.element(identifier: identifier) != nil, "No element \(identifier).")
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
    let png = try ContentBlockViewHostedTests.pngData()
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
  func aWireBlockForTheAssistantOnlyProducesNoElement(kind: AgentViewKit.ContentBlock.Kind) throws {
    let assistantOnly = FoundationModelsACP.Annotations(audience: [.assistant])
    let block = try #require(try Self.makeWireBlock(of: kind, annotations: assistantOnly))
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

  // MARK: - Helpers

  /// The labels of the accessibility elements of `harness`.
  ///
  /// - Parameter harness: The harness that shows the block.
  /// - Returns: Each label.
  static func labels<Content: View>(in harness: HostedViewHarness<Content>) -> [String] {
    harness.accessibilityElements().compactMap(\.label)
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

  /// Makes one ACP block that shows the default view of a kit kind.
  ///
  /// - Parameters:
  ///   - kind: The kind of the default view.
  ///   - annotations: The annotations of the block. An unknown block holds
  ///     none.
  /// - Returns: The block, or `nil` for the attachment kind, which ACP does
  ///   not define.
  /// - Throws: An error when AppKit cannot make the image.
  static func makeWireBlock(
    of kind: AgentViewKit.ContentBlock.Kind, annotations: FoundationModelsACP.Annotations? = nil
  ) throws -> FoundationModelsACP.ContentBlock? {
    switch kind {
    case .text:
      .text(TextContent(text: blockText, annotations: annotations))
    case .image:
      .image(
        FoundationModelsACP.ImageContent(
          data: try ContentBlockViewHostedTests.pngData().base64EncodedString(),
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
    case .attachment:
      nil
    }
  }
}
