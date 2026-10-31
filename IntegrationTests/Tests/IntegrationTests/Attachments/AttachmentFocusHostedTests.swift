import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import EditorTestSupport
import Foundation
import SwiftUI
import Testing
import UniformTypeIdentifiers

@testable import AgentViewKit

/// Tests for the first responder of an attachment scope that a `nav.*` move
/// focuses (^ars99rn).
///
/// The views of ``Surface`` have no focusable view at the center of their
/// scope, so EditorKit gives the focus to the beacon of the scope. The
/// inspector has a focusable view of its own, which takes the focus.
@Suite(.serialized, .hostedSerially) @MainActor struct AttachmentFocusHostedTests {
  /// An attachment view that lets the beacon of its scope hold the focus.
  enum Surface: CaseIterable, Sendable {
    /// An ``AttachmentChip``, as the composer shows it.
    case chip
    /// An ``AttachmentView`` of a type that shows the chip.
    case attachmentChip
    /// An ``AttachmentView`` of an image file.
    case attachmentImage
    /// An ``ArtifactView`` of a file.
    case artifact
    /// An ``ImageView`` of an image block.
    case image
  }

  /// A view to mount, with the id of the attachment of its scope.
  struct MountedSurface {
    /// The view.
    let content: AnyView

    /// The id of the attachment of the scope of the view.
    let id: AttachmentID
  }

  /// Makes the view of `surface` over a file in `directory`.
  ///
  /// - Parameters:
  ///   - surface: The view to make.
  ///   - directory: The directory of the file of the view.
  /// - Returns: The view, with the id of the attachment of its scope.
  /// - Throws: The error of the write of the file.
  static func mount(_ surface: Surface, in directory: TemporaryFolder) throws -> MountedSurface {
    switch surface {
    case .chip:
      let attachment = try AttachmentFixtures.attachment(named: "blob.bin", in: directory)
      return MountedSurface(content: AnyView(AttachmentChip(attachment)), id: attachment.id)
    case .attachmentChip:
      let attachment = try AttachmentFixtures.attachment(named: "blob.bin", in: directory)
      return MountedSurface(content: AnyView(AttachmentView(attachment)), id: attachment.id)
    case .attachmentImage:
      let url = try directory.write(WireContentBlockViewHostedTests.imageName, contents: TestImage.makePNGData())
      let attachment = AgentViewKit.Attachment(url: url)
      return MountedSurface(content: AnyView(AttachmentView(attachment)), id: attachment.id)
    case .artifact:
      let url = try directory.write("plan.txt", contents: Data(AttachmentFixtures.fileText.utf8))
      let artifact = ArtifactPayload(
        id: "artifact-1", title: "The plan", type: UTType.plainText.identifier, url: url)
      return MountedSurface(
        content: AnyView(ArtifactView(artifact: artifact)), id: AgentViewKit.Attachment(url: url).id)
    case .image:
      let (png, image) = try TestImage.makePNGContent(uri: WireContentBlockViewHostedTests.imageURI)
      let file = ContentBlockFile.attachment(of: png, named: WireContentBlockViewHostedTests.imageName, type: .png)
      return MountedSurface(content: AnyView(ImageView(image: image)), id: file.id)
    }
  }

  /// Mounts the view that `makeView` makes, lands a `nav.*` move on the root
  /// scope of its attachment, and gives the focused scope to `inspect`.
  ///
  /// - Parameters:
  ///   - makeView: Makes the view to mount over a file in a temporary
  ///     directory.
  ///   - inspect: The checks on the focused scope.
  /// - Throws: The error of the write of the file, or an issue when the
  ///   focus does not land.
  static func inspectFocusedScope(
    of makeView: (TemporaryFolder) throws -> MountedSurface,
    _ inspect: (AgentItemFocusHostedTests.FocusedItem) throws -> Void
  ) async throws {
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    defer { directory.remove() }
    let mounted = try makeView(directory)
    let system = CommandSystem()
    let harness = HostedViewHarness(mounted.content.commandSystem(system), size: AttachmentCommandsHostedTests.viewSize)
    defer { harness.close() }
    harness.render()
    let scope = FocusPath.root(AgentScopeKind.attachment(mounted.id))

    try inspect(
      try await AgentItemFocusHostedTests.focusedItem(at: scope, in: system, harness: harness) {
        try #require(system.geometry.requestFocus(at: scope))
      })
  }

  /// The beacon of the scope holds the focus, and covers the view.
  @Test(arguments: Surface.allCases)
  func theBeaconOfTheScopeHoldsTheFocus(surface: Surface) async throws {
    try await Self.inspectFocusedScope(of: { try Self.mount(surface, in: $0) }) { focused in
      #expect(focused.responder is GeometryProbeView)
      #expect(WindowSpace.rect(of: focused.responder) == focused.itemRect)
    }
  }

  /// The inspector has a focusable view of its own, so a `nav.*` move on its
  /// scope focuses that view and not the beacon of the scope.
  @Test func aFocusableViewOfTheInspectorTakesTheFocusOfItsScope() async throws {
    try await Self.inspectFocusedScope(of: { directory in
      let attachment = try AttachmentFixtures.attachment(named: "blob.bin", in: directory)
      return MountedSurface(content: AnyView(AttachmentInspector(attachment)), id: attachment.id)
    }) { focused in
      #expect(WindowSpace.rect(of: focused.responder) != focused.itemRect)
    }
  }
}
