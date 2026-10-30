import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import EditorStyle
import class EditorTestSupport.FocusRingBed
import Foundation
import SwiftUI
import Testing
import UniformTypeIdentifiers

@testable import AgentViewKit

/// Tests for the focus ring of an attachment scope that a `nav.*` move
/// focuses (^ars99rn).
///
/// The views of ``Surface`` have no focusable view at the center of their
/// scope, so EditorKit gives the focus to the beacon of the scope, and the
/// scope draws its focus ring around the view in the theme accent
/// (EditorKit ^d5f8cwa). The ring has the corners of the surface of the
/// view: the medium radius of the style for a chip and an artifact panel,
/// and square corners for an image. The inspector has a focusable view of
/// its own, which takes the focus and draws its own ring.
///
/// Each test mounts one view in a `FocusRingBed` of EditorKit: a real key
/// window on the screen, under the red tint of a host and the shared
/// `AccentTheme` with the blue accent of the bed. It lands the focus on the
/// scope of the view, and reads the first responder of the window and the
/// ring of the scope from captures of the window server.
@Suite(.serialized, .hostedSerially) @MainActor struct AttachmentFocusRingHostedTests {
  /// The suite whose helpers read the focused item and its ring.
  typealias Ring = AgentItemFocusRingHostedTests

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

    /// The radius of the corners of the surface in the default style.
    var cornerRadius: CGFloat {
      switch self {
      case .chip, .attachmentChip, .artifact: EditorStyle.default.radii.m
      case .attachmentImage, .image: .zero
      }
    }
  }

  /// The contents of an image file that does not decode.
  static let undecodableImageText = "This is not an image."

  /// The corners that the shown surface of an attachment view reports.
  @MainActor @Observable final class ShownSurface {
    /// The corners of the shown surface, or `nil` before a surface reports
    /// them.
    var corners: SurfaceCorners?
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
  static func mount(_ surface: Surface, in directory: TemporaryDirectory) throws -> MountedSurface {
    switch surface {
    case .chip:
      let attachment = try AttachmentFixtures.attachment(named: "blob.bin", in: directory)
      return MountedSurface(content: AnyView(AttachmentChip(attachment)), id: attachment.id)
    case .attachmentChip:
      let attachment = try AttachmentFixtures.attachment(named: "blob.bin", in: directory)
      return MountedSurface(content: AnyView(AttachmentView(attachment)), id: attachment.id)
    case .attachmentImage:
      let url = try directory.file(named: WireContentBlockViewHostedTests.imageName, contents: TestImage.makePNGData())
      let attachment = AgentViewKit.Attachment(url: url)
      return MountedSurface(content: AnyView(AttachmentView(attachment)), id: attachment.id)
    case .artifact:
      let url = try directory.file(named: "plan.txt", contents: Data(AttachmentFixtures.fileText.utf8))
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

  /// Mounts the view that `makeView` makes in a `FocusRingBed`, lands a
  /// `nav.*` move on its scope, and gives the focused scope to `inspect`.
  ///
  /// - Parameters:
  ///   - makeView: Makes the view to mount over a file in a temporary
  ///     directory.
  ///   - inspect: The checks on the focused scope.
  /// - Throws: The error of the write of the file, or an issue when the
  ///   focus does not land.
  static func inspectFocusedScope(
    of makeView: (TemporaryDirectory) throws -> MountedSurface, _ inspect: (Ring.FocusedItem) async throws -> Void
  ) async throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let mounted = try makeView(directory)
    let bed = FocusRingBed(size: AttachmentCommandsHostedTests.viewSize) { mounted.content }
    defer { bed.close() }
    try await inspect(try await focusScope(of: mounted.id, in: bed))
  }

  /// Lands a `nav.*` move on the root scope of the attachment `id`, and
  /// reads the first responder of the window and the ring of the scope.
  ///
  /// - Parameters:
  ///   - id: The id of the attachment of the scope.
  ///   - bed: The bed that shows the scope.
  /// - Returns: The first responder, with the area of the scope and its
  ///   ring.
  /// - Throws: An issue when the focus does not land, or an error when a
  ///   capture fails.
  static func focusScope(of id: AttachmentID, in bed: FocusRingBed) async throws -> Ring.FocusedItem {
    let scope = FocusPath.root(AgentScopeKind.attachment(id))

    return try await Ring.focusedItem(at: scope, in: bed) {
      try #require(bed.system.geometry.requestFocus(at: scope))
    }
  }

  /// The beacon of the scope holds the focus, and the scope draws its ring
  /// around the view in the theme accent, not in the tint of the host.
  @Test(arguments: Surface.allCases)
  func theBeaconOfTheScopeHoldsTheFocus(surface: Surface) async throws {
    try await Self.inspectFocusedScope(of: { try Self.mount(surface, in: $0) }) { focused in
      #expect(focused.responder is GeometryProbeView)
      #expect(WindowSpace.rect(of: focused.responder) == focused.itemRect)
      #expect(focused.ring.isDrawn(in: FocusRingBed.defaultAccent))
    }
  }

  /// The focus ring of the scope has the corners of the surface of the view.
  @Test(arguments: Surface.allCases)
  func theFocusRingHasTheCornersOfTheSurface(surface: Surface) async throws {
    try await Self.inspectFocusedScope(of: { try Self.mount(surface, in: $0) }) { focused in
      try await FocusRingBed.expectRingCorners(
        of: focused.ring, size: focused.itemRect.size, cornerRadius: surface.cornerRadius)
    }
  }

  /// An image preview whose file does not decode shows the chip in its place,
  /// so the focus ring of its scope has the corners of the chip: the medium
  /// radius of the style.
  ///
  /// The image loads asynchronously, so the test waits until the shown
  /// surface reports its corners (``AttachmentSurfaceCornersKey``) before it
  /// lands the focus.
  @Test func theFocusRingOfAPreviewThatShowsTheChipHasTheCornersOfTheChip() async throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let url = try directory.file(
      named: WireContentBlockViewHostedTests.imageName, contents: Data(Self.undecodableImageText.utf8))
    let attachment = AgentViewKit.Attachment(url: url)
    let shown = ShownSurface()
    let bed = FocusRingBed(size: AttachmentCommandsHostedTests.viewSize) {
      AttachmentView(attachment)
        .onPreferenceChange(AttachmentSurfaceCornersKey.self) { shown.corners = $0 }
    }
    defer { bed.close() }

    await bed.render(when: { shown.corners != nil })
    let focused = try await Self.focusScope(of: attachment.id, in: bed)

    try await FocusRingBed.expectRingCorners(
      of: focused.ring, size: focused.itemRect.size, cornerRadius: EditorStyle.default.radii.m)
  }

  /// The inspector has a focusable view of its own, so a `nav.*` move on its
  /// scope focuses that view and not the beacon of the scope. The ring is
  /// the ring of that view, and the inspector keeps the default corners of
  /// its scope.
  @Test func aFocusableViewOfTheInspectorTakesTheFocusOfItsScope() async throws {
    try await Self.inspectFocusedScope(of: { directory in
      let attachment = try AttachmentFixtures.attachment(named: "blob.bin", in: directory)
      return MountedSurface(content: AnyView(AttachmentInspector(attachment)), id: attachment.id)
    }) { focused in
      #expect(WindowSpace.rect(of: focused.responder) != focused.itemRect)
    }
  }
}
