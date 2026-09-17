import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import Foundation
import SwiftUI
import Testing
import UniformTypeIdentifiers

/// The attachment of the kit. Swift Testing declares a type with the same
/// name.
private typealias Attachment = AgentViewKit.Attachment

/// The text and the attachments of a hosted composer.
@Observable private final class AttachmentChipsTestModel {
  /// The text of the composer.
  var text: AttributedString

  /// The attachments of the composer.
  var attachments: [Attachment]

  /// Makes a model.
  ///
  /// - Parameters:
  ///   - text: The first text of the composer.
  ///   - attachments: The first attachments of the composer.
  init(text: String = "", attachments: [Attachment]) {
    self.text = AttributedString(text)
    self.attachments = attachments
  }
}

/// A host view that owns the text and the attachments of a stock composer.
private struct AttachmentComposerHost: View {
  /// The model that holds the text and the attachments.
  @Bindable var model: AttachmentChipsTestModel

  var body: some View {
    PromptInputView(text: $model.text, attachments: $model.attachments, onSubmit: {})
  }
}

@Suite(.serialized, .hostedSerially) @MainActor struct AttachmentChipsHostedTests {
  /// The text that the submit test sends.
  static let message = "Look at these"

  /// The size of a window that shows the full composer.
  static let composerSize = CGSize(width: 480, height: 240)

  /// The size of a window that shows the chip row.
  static let rowSize = CGSize(width: 480, height: 80)

  /// The longest time that a test waits for a change, in seconds.
  static let waitTimeout: TimeInterval = 5

  /// The side of the image that the image tests write, in pixels.
  static let imageSide = 1

  /// A source file. The file does not have to exist.
  static let sourceURL = URL(filePath: "/tmp/attachment-chips/Main.swift")

  /// A PDF file. The file does not have to exist.
  static let pdfURL = URL(filePath: "/tmp/attachment-chips/Report.pdf")

  /// The attachments of the render tests.
  private static let twoAttachments = [Attachment(url: sourceURL), Attachment(url: pdfURL)]

  /// Makes a new empty directory for the files that a test writes.
  ///
  /// - Returns: The location of the directory.
  static func makeDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appending(path: "AttachmentChipsHostedTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  /// The PNG data of a small image.
  ///
  /// - Returns: The encoded image.
  static func pngData() throws -> Data {
    let bitmap = try #require(
      NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: imageSide, pixelsHigh: imageSide, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0))
    return try #require(bitmap.representation(using: .png, properties: [:]))
  }

  // MARK: - Render and remove

  @Test func twoAttachmentsRenderTwoChipsAndARemoveLeavesOne() async throws {
    let model = AttachmentChipsTestModel(attachments: Self.twoAttachments)
    let harness = threadViewHarness(size: Self.rowSize, actions: NoopThreadActions()) {
      AttachmentChips(attachments: Bindable(model).attachments)
    }
    defer { harness.close() }
    harness.pump()

    let first = Self.twoAttachments[0].id
    let second = Self.twoAttachments[1].id
    #expect(harness.element(identifier: AttachmentChips.chipIdentifier(for: first)) != nil)
    #expect(harness.element(identifier: AttachmentChips.chipIdentifier(for: second)) != nil)

    try harness.press(identifier: AttachmentChips.removeIdentifier(for: first))
    await harness.pump(until: Self.waitTimeout) { model.attachments.count == 1 }

    #expect(model.attachments.map(\.id) == [second])
    #expect(harness.element(identifier: AttachmentChips.chipIdentifier(for: first)) == nil)
    #expect(harness.element(identifier: AttachmentChips.chipIdentifier(for: second)) != nil)
  }

  @Test func theIdentifiersHoldTheAttachmentIdentifier() {
    let id = AttachmentID("file:///tmp/a.txt")
    #expect(AttachmentChips.chipIdentifier(for: id) == "attachment-chip-file:///tmp/a.txt")
    #expect(AttachmentChips.removeIdentifier(for: id) == "attachment-remove-file:///tmp/a.txt")
  }

  // MARK: - Drop

  @Test func aDropOfTwoFileURLsAddsTwoAttachmentsWithTheResolvedTypes() throws {
    var attachments: [Attachment] = []
    let directory = try Self.makeDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let added = AttachmentChips.add(
      [.file(Self.sourceURL), .file(Self.pdfURL)], to: &attachments, directory: directory)

    #expect(added)
    #expect(attachments.map(\.url) == [Self.sourceURL, Self.pdfURL])
    #expect(attachments.map(\.type) == [.swiftSource, .pdf])
  }

  @Test func aDropAddsAFileOneTimeOnly() throws {
    var attachments = [Attachment(url: Self.sourceURL)]
    let directory = try Self.makeDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let added = AttachmentChips.add([.file(Self.sourceURL)], to: &attachments, directory: directory)

    #expect(!added)
    #expect(attachments.map(\.url) == [Self.sourceURL])
  }

  @Test func aDropOfAWebURLAddsNothing() throws {
    var attachments: [Attachment] = []
    let directory = try Self.makeDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let webURL = try #require(URL(string: "https://example.com/page.html"))

    let added = AttachmentChips.add([.file(webURL)], to: &attachments, directory: directory)

    #expect(!added)
    #expect(attachments.isEmpty)
  }

  @Test func aDroppedImageIsWrittenToAFileAndAdded() throws {
    var attachments: [Attachment] = []
    let directory = try Self.makeDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let data = try Self.pngData()

    let added = AttachmentChips.add([.image(data)], to: &attachments, directory: directory)

    #expect(added)
    let attachment = try #require(attachments.first)
    #expect(attachments.count == 1)
    #expect(attachment.type == .png)
    #expect(attachment.url.path.hasPrefix(directory.path))
    #expect(try Data(contentsOf: attachment.url) == data)
  }

  @Test func twoDroppedImagesGoToTwoFiles() throws {
    var attachments: [Attachment] = []
    let directory = try Self.makeDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let data = try Self.pngData()

    AttachmentChips.add([.image(data), .image(data)], to: &attachments, directory: directory)

    #expect(Set(attachments.map(\.url)).count == 2)
  }

  @Test func dataThatIsNotAnImageAddsNothing() throws {
    var attachments: [Attachment] = []
    let directory = try Self.makeDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let added = AttachmentChips.add(
      [.image(Data("not an image".utf8))], to: &attachments, directory: directory)

    #expect(!added)
    #expect(attachments.isEmpty)
  }

  // MARK: - Composer

  @Test func theComposerShowsTheRowOnlyWhenItHasAttachments() async {
    let model = AttachmentChipsTestModel(attachments: [])
    let harness = threadViewHarness(size: Self.composerSize, actions: NoopThreadActions()) {
      AttachmentComposerHost(model: model)
    }
    defer { harness.close() }
    harness.pump()

    let identifier = AttachmentChips.chipIdentifier(for: Self.twoAttachments[0].id)
    #expect(harness.element(identifier: identifier) == nil)
    model.attachments = [Self.twoAttachments[0]]
    await harness.pump(until: Self.waitTimeout) { harness.element(identifier: identifier) != nil }

    #expect(harness.element(identifier: identifier) != nil)
  }

  @Test func aSubmitPassesTheAttachmentsAndClearsTheRow() async throws {
    let actions = NoopThreadActions()
    let model = AttachmentChipsTestModel(text: Self.message, attachments: Self.twoAttachments)
    let harness = threadViewHarness(size: Self.composerSize, actions: actions) {
      AttachmentComposerHost(model: model)
    }
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: DefaultPromptAccessory.submitIdentifier)
    await harness.pump(until: Self.waitTimeout) { !actions.calls.isEmpty }

    let input = UserInput(text: Self.message, attachments: [Self.sourceURL, Self.pdfURL])
    #expect(actions.calls == [.send(input)])
    #expect(model.attachments.isEmpty)
  }

  @Test func aFileThatIsAChipAndALinkIsSentOneTime() async throws {
    let actions = NoopThreadActions()
    var text = AttributedString(Self.message)
    text.link = Self.sourceURL
    let model = AttachmentChipsTestModel(attachments: Self.twoAttachments)
    model.text = text
    let harness = threadViewHarness(size: Self.composerSize, actions: actions) {
      AttachmentComposerHost(model: model)
    }
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: DefaultPromptAccessory.submitIdentifier)
    await harness.pump(until: Self.waitTimeout) { !actions.calls.isEmpty }

    let input = UserInput(text: Self.message, attachments: [Self.sourceURL, Self.pdfURL])
    #expect(actions.calls == [.send(input)])
  }
}
