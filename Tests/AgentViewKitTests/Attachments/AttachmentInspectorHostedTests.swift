import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import Foundation
import SwiftUI
import Testing
import UniformTypeIdentifiers

/// Hosted tests of the attachment views, the inspector and the artifact view.
///
/// Each change comes from the test on the main actor: a mount, a press, or a
/// change of the selection. One render pass after the change puts its result
/// in the accessibility tree, so the test reads the tree after that pass. An
/// inspector that opens after the mount shows its split view item only after
/// a run loop turn, so the two tests of that case wait for the selection and
/// read the inspector content in its own harness
/// (``mountInspectorContent(of:)``).
@Suite(.serialized, .hostedSerially) @MainActor struct AttachmentInspectorHostedTests {
  /// The size of a view that shows the attachment and the inspector.
  static let hostSize = CGSize(width: 900, height: 600)

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
    harness.render()

    #expect(harness.element(identifier: AttachmentView.identifier(for: .code)) != nil)
    #expect(harness.element(identifier: AttachmentView.identifier(for: .chip)) == nil)
  }

  @Test func aBinaryFileMountsTheChip() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try Self.attachment(named: "blob.bin", in: directory)
    let harness = HostedViewHarness(AttachmentView(attachment), size: Self.hostSize)
    defer { harness.close() }
    harness.render()

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
    harness.render()

    #expect(harness.element(identifier: Self.customPDFIdentifier)?.label == "paper.pdf")
    #expect(harness.element(identifier: AttachmentView.identifier(for: .pdf)) == nil)
  }

  // MARK: - Inspector

  /// A press on a chip selects its attachment, and the inspector content of
  /// that selection shows the name and the five actions.
  ///
  /// The test waits for the selection, and then mounts the inspector content
  /// of the selection in its own harness with one render pass.
  ///
  /// Gap: the test does not prove that the AppKit split view shows the
  /// inspector item. In the off-screen harness window the item shows only
  /// after a run loop turn. Task ^2pbwh3e checks that on a real screen.
  @Test func aPressOnAChipSelectsItsAttachmentForTheInspectorContent() async throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try Self.attachment(named: "blob.bin", in: directory)
    let selection = InspectorSelection()
    let harness = HostedViewHarness(
      AttachmentView(attachment).attachmentInspector(selection: selection), size: Self.hostSize)
    defer { harness.close() }
    harness.render()
    #expect(harness.element(identifier: AttachmentInspector.nameIdentifier) == nil)

    try Self.withoutAnimation {
      try harness.press(identifier: AttachmentView.identifier(for: .chip))
    }
    await ObservationWait.until { selection.attachment != nil }

    #expect(selection.attachment == attachment)
    let content = try Self.mountInspectorContent(of: selection)
    defer { content.close() }
    #expect(content.element(identifier: AttachmentInspector.nameIdentifier)?.label == "blob.bin")
    for identifier in AttachmentInspector.actionIdentifiers {
      #expect(content.element(identifier: identifier) != nil, "No action \(identifier).")
    }
  }

  @Test func theInspectorHasTheFiveActionIdentifiers() {
    #expect(
      AttachmentInspector.actionIdentifiers == [
        "inspector-open", "inspector-reveal", "inspector-share", "inspector-save",
        "inspector-quicklook",
      ])
  }

  @Test func aClearedSelectionClosesTheInspector() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try Self.attachment(named: "blob.bin", in: directory)
    let selection = InspectorSelection(attachment: attachment)
    let harness = HostedViewHarness(
      Text("host").attachmentInspector(selection: selection), size: Self.hostSize)
    defer { harness.close() }
    harness.render()
    #expect(harness.element(identifier: AttachmentInspector.nameIdentifier) != nil)

    selection.clear()
    harness.render()

    #expect(selection.attachment == nil)
    #expect(harness.element(identifier: AttachmentInspector.nameIdentifier) == nil)
  }

  /// A thread view of a session with a host selection shows no inspector
  /// before the host selects, and the selection of the host then holds the
  /// attachment, whose inspector content shows its name.
  ///
  /// The test waits for the selection, and then mounts the inspector content
  /// of the selection in its own harness with one render pass.
  ///
  /// Gap: the test does not prove that the AppKit split view of the thread
  /// view shows the inspector item. In the off-screen harness window the
  /// item shows only after a run loop turn. Task ^2pbwh3e checks that on a
  /// real screen.
  @Test func theSelectionOfTheHostOfAThreadViewGivesItsAttachmentToTheInspectorContent() async throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try Self.attachment(named: "notes.md", in: directory)
    let selection = InspectorSelection()
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = HostedViewHarness(
      AgentThreadView(session: session.model, connection: session.connection)
        .environment(\.inspectorSelection, selection),
      size: Self.hostSize)
    defer { harness.close() }
    harness.render()
    #expect(harness.element(identifier: AttachmentInspector.nameIdentifier) == nil)

    try Self.withoutAnimation { selection.select(attachment) }
    await ObservationWait.until { selection.attachment != nil }

    #expect(selection.attachment == attachment)
    let content = try Self.mountInspectorContent(of: selection)
    defer { content.close() }
    #expect(content.element(identifier: AttachmentInspector.nameIdentifier)?.label == "notes.md")
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
    harness.render()

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
    harness.render()

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

  /// Mounts the inspector content of the attachment that `selection` holds,
  /// as the split view item of the inspector shows it, and makes one render
  /// pass.
  ///
  /// - Parameter selection: The selection whose attachment the content shows.
  /// - Returns: The harness of the content. The caller closes it.
  /// - Throws: An issue when the selection holds no attachment.
  static func mountInspectorContent(of selection: InspectorSelection) throws
    -> HostedViewHarness<AttachmentInspector>
  {
    let attachment = try #require(selection.attachment)
    let harness = HostedViewHarness(AttachmentInspector(attachment), size: hostSize)
    harness.render()
    return harness
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
