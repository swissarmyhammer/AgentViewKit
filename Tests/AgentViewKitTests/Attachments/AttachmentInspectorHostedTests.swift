import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import Foundation
import SwiftUI
import Testing
import UniformTypeIdentifiers

@Suite(.serialized) @MainActor struct AttachmentInspectorHostedTests {
  /// The size of a view that shows the attachment and the inspector.
  static let hostSize = CGSize(width: 900, height: 600)

  /// The time that a test waits for a view change, in seconds.
  static let waitSeconds: TimeInterval = 2

  /// The text that each temporary file holds.
  static let fileText = "let answer = 42\n"

  /// The accessibility identifier of the registered PDF view.
  static let customPDFIdentifier = "custom-pdf-view"

  // MARK: - Default renderers

  @Test func aSwiftFileMountsTheCodeRenderer() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try Self.attachment(named: "Main.swift", in: directory)
    let harness = HostedViewHarness(AttachmentView(attachment), size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: AttachmentView.identifier(for: .code)) != nil)
    #expect(harness.element(identifier: AttachmentView.identifier(for: .chip)) == nil)
  }

  @Test func aBinaryFileMountsTheChip() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try Self.attachment(named: "blob.bin", in: directory)
    let harness = HostedViewHarness(AttachmentView(attachment), size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    let chip = try #require(harness.element(identifier: AttachmentView.identifier(for: .chip)))
    #expect(chip.label?.contains("blob.bin") == true)
  }

  @Test func aRegisteredPDFViewWinsOverTheDefault() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try Self.attachment(named: "paper.pdf", in: directory)
    let harness = HostedViewHarness(
      AttachmentView(attachment)
        .attachmentView(for: .pdf) { url in
          Text(url.lastPathComponent)
            .accessibilityIdentifier(Self.customPDFIdentifier)
        },
      size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: Self.customPDFIdentifier)?.label == "paper.pdf")
    #expect(harness.element(identifier: AttachmentView.identifier(for: .pdf)) == nil)
  }

  // MARK: - Inspector

  @Test func aPressOnAChipOpensTheInspector() async throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try Self.attachment(named: "blob.bin", in: directory)
    let selection = InspectorSelection()
    let harness = HostedViewHarness(
      AttachmentView(attachment).attachmentInspector(selection: selection), size: Self.hostSize)
    defer { harness.close() }
    harness.pump()
    #expect(harness.element(identifier: AttachmentInspector.nameIdentifier) == nil)

    try Self.withoutAnimation {
      try harness.press(identifier: AttachmentView.identifier(for: .chip))
    }
    await harness.pump(until: Self.waitSeconds) {
      harness.element(identifier: AttachmentInspector.nameIdentifier) != nil
    }

    #expect(selection.attachment == attachment)
    #expect(harness.element(identifier: AttachmentInspector.nameIdentifier)?.label == "blob.bin")
    for identifier in AttachmentInspector.actionIdentifiers {
      #expect(harness.element(identifier: identifier) != nil, "No action \(identifier).")
    }
  }

  @Test func theInspectorHasTheFiveActionIdentifiers() {
    #expect(
      AttachmentInspector.actionIdentifiers == [
        "inspector-open", "inspector-reveal", "inspector-share", "inspector-save",
        "inspector-quicklook",
      ])
  }

  @Test func aClearedSelectionClosesTheInspector() async throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try Self.attachment(named: "blob.bin", in: directory)
    let selection = InspectorSelection(attachment: attachment)
    let harness = HostedViewHarness(
      Text("host").attachmentInspector(selection: selection), size: Self.hostSize)
    defer { harness.close() }
    await harness.pump(until: Self.waitSeconds) {
      harness.element(identifier: AttachmentInspector.nameIdentifier) != nil
    }
    #expect(harness.element(identifier: AttachmentInspector.nameIdentifier) != nil)

    selection.clear()
    await harness.pump(until: Self.waitSeconds) {
      harness.element(identifier: AttachmentInspector.nameIdentifier) == nil
    }

    #expect(selection.attachment == nil)
    #expect(harness.element(identifier: AttachmentInspector.nameIdentifier) == nil)
  }

  @Test func theThreadViewShowsTheSelectionOfTheHost() async throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try Self.attachment(named: "notes.md", in: directory)
    let selection = InspectorSelection(attachment: attachment)
    let harness = HostedViewHarness(
      AgentThreadView(thread: AgentThread())
        .environment(\.inspectorSelection, selection),
      size: Self.hostSize)
    defer { harness.close() }
    await harness.pump(until: Self.waitSeconds) {
      harness.element(identifier: AttachmentInspector.nameIdentifier) != nil
    }

    #expect(harness.element(identifier: AttachmentInspector.nameIdentifier)?.label == "notes.md")
  }

  // MARK: - Artifact

  @Test func anArtifactWithAURLShowsItsBodyAndActions() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let url = try directory.file(named: "plan", contents: Data(Self.fileText.utf8))
    let artifact = ArtifactPayload(
      id: "artifact-1", title: "The plan", type: UTType.swiftSource.identifier, url: url)
    let harness = HostedViewHarness(ArtifactView(artifact: artifact), size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: ArtifactView.titleIdentifier)?.label == "The plan")
    #expect(harness.element(identifier: AttachmentView.identifier(for: .code)) != nil)
    for identifier in ArtifactView.actionIdentifiers {
      #expect(harness.element(identifier: identifier) != nil, "No action \(identifier).")
    }
  }

  @Test func anInlineArtifactShowsItsTextAndNoActions() {
    let artifact = ArtifactPayload(
      id: "artifact-2", title: "Notes", type: UTType.plainText.identifier,
      inlineText: "Step one")
    let harness = HostedViewHarness(ArtifactView(artifact: artifact), size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: ArtifactView.inlineTextIdentifier) != nil)
    for identifier in ArtifactView.actionIdentifiers {
      #expect(harness.element(identifier: identifier) == nil, "Unexpected action \(identifier).")
    }
  }

  // MARK: - Helpers

  /// Runs `body` in a transaction with no animation.
  ///
  /// The inspector opens with an AppKit split view animation. The harness
  /// window is not on a screen, so that animation does not end, and the
  /// inspector stays closed. A change with no animation opens it at once.
  ///
  /// - Parameter body: The change to make.
  /// - Throws: The error of `body`.
  static func withoutAnimation(_ body: () throws -> Void) throws {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    try withTransaction(transaction, body)
  }

  /// Writes a file and makes its attachment.
  ///
  /// - Parameters:
  ///   - name: The file name, with its extension.
  ///   - directory: The directory of the file.
  /// - Returns: The attachment of the file.
  /// - Throws: The error of the write.
  static func attachment(named name: String, in directory: TemporaryDirectory) throws
    -> AgentViewKit.Attachment
  {
    AgentViewKit.Attachment(url: try directory.file(named: name, contents: Data(fileText.utf8)))
  }
}
