import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import EditorExtensions
import EditorStyle
import Foundation
import SwiftUI
import Testing
import UniformTypeIdentifiers

@testable import AgentViewKit

/// The kit draws each selection through the shared selection surface of
/// EditorKit (card ^dn1m56r): the accent at ``EditorStyle/selectionOpacity``
/// behind a selected item while the window is key, `.primary` at
/// ``EditorStyle/inactiveSelectionOpacity`` while it is not, and the text of
/// the item stays `.primary`. A focused item keeps its fill, and the focus
/// ring of its scope outlines it.
///
/// Each test shows a view over a white backdrop in light mode, with a red
/// tint, in a window of a ``HostedViewHarness``. The window of a harness is
/// not key, so each test sets `\.appearsActive` itself.
@Suite(.serialized, .hostedSerially) @MainActor struct SelectionSurfaceSitesHostedTests {
  /// The attachment of the kit. FoundationModelsACP has a type of the same
  /// name.
  typealias Attachment = AgentViewKit.Attachment

  /// The suite whose helpers make the files of the attachments.
  typealias Shared = AttachmentInspectorHostedTests

  /// The suite whose helpers land the focus on an attachment scope.
  typealias FocusRing = AttachmentFocusRingHostedTests

  /// The suite whose helper reads the mask of a focus ring.
  typealias Ring = AgentItemFocusRingHostedTests

  /// The suite whose helpers show a tool call with a location.
  typealias Locations = ContentFileSelectionHostedTests

  /// The suite whose helpers make the image block.
  typealias Blocks = WireContentBlockViewHostedTests

  /// The accent of each test: a color that no part of the views draws.
  static let tint = Color.red

  /// The backdrop below each view.
  static let backdrop = Color.white

  /// The size of the window that shows an attachment view or an image.
  static let fileSize = CGSize(width: 320, height: 200)

  /// The size of the window that shows one row of the completion list: the
  /// width of the list.
  static let rowSize = CGSize(width: EditorKitPromptEditor.completionListWidth, height: 40)

  /// The label of the completion row of the tests.
  static let completionLabel = "README.md"

  /// The two states of the window.
  nonisolated static let windowStates = [true, false]

  // MARK: - Helpers

  /// `view` over the backdrop, in light mode, with the tint of the tests and
  /// the window state `appearsActive`.
  ///
  /// - Parameters:
  ///   - view: The view to show.
  ///   - appearsActive: Whether the window appears active.
  /// - Returns: The view to mount.
  static func onBackdrop(_ view: some View, appearsActive: Bool) -> some View {
    ZStack {
      backdrop
      view
    }
    .tint(tint)
    .environment(\.appearsActive, appearsActive)
    .environment(\.colorScheme, .light)
  }

  /// The pixels of `view` over the backdrop, from the cache of a window.
  ///
  /// - Parameters:
  ///   - view: The view to show.
  ///   - appearsActive: Whether the window appears active.
  ///   - size: The size of the window.
  /// - Returns: The pixels.
  /// - Throws: An error when AppKit gives no pixels.
  static func pixels(of view: some View, appearsActive: Bool, size: CGSize) throws -> RenderedPixels {
    try GlassRenderProbeHostedTests.cachedPixels(of: onBackdrop(view, appearsActive: appearsActive), size: size)
  }

  /// The pixels of a window that the fill of a selected surface covers: the
  /// accent at the selection opacity while the window is key, and the
  /// inactive grey while it is not.
  ///
  /// - Parameters:
  ///   - appearsActive: Whether the window appears active.
  ///   - size: The size of the window.
  /// - Returns: The pixels.
  /// - Throws: An error when AppKit gives no pixels.
  static func fillPixels(appearsActive: Bool, size: CGSize) throws -> RenderedPixels {
    let fill =
      appearsActive
      ? tint.opacity(EditorStyle.selectionOpacity) : Color.primary.opacity(EditorStyle.inactiveSelectionOpacity)
    return try pixels(of: fill, appearsActive: appearsActive, size: size)
  }

  /// The center of a window of `size`.
  ///
  /// - Parameter size: The size of the window.
  /// - Returns: The center, in points from the top leading corner.
  static func center(of size: CGSize) -> CGPoint {
    CGPoint(x: size.width / 2, y: size.height / 2)
  }

  /// The image block of the tests, and the attachment of its block file.
  ///
  /// The PNG image of ``TestImage`` is clear, so the fill behind the image
  /// shows through it.
  ///
  /// - Returns: The view of the block, and the attachment of its file.
  /// - Throws: An error when AppKit cannot make the image.
  static func imageBlock() throws -> (view: ImageView, file: Attachment) {
    let (png, image) = try TestImage.makePNGContent(uri: Blocks.imageURI)
    return (ImageView(image: image), ContentBlockFile.attachment(of: png, named: Blocks.imageName, type: .png))
  }

  /// A completion row of the tests.
  ///
  /// - Parameter isSelected: Whether the row is the selected row.
  /// - Returns: The row.
  static func completionRow(isSelected: Bool) -> PromptCompletionRow {
    PromptCompletionRow(
      item: Completion(label: completionLabel, insert: .text(completionLabel), kind: .path), isSelected: isSelected)
  }

  // MARK: - Completion row

  /// A point of the completion row inside its selection surface and before
  /// its text, which the row insets by the small spacing step.
  static let rowSurfacePoint = CGPoint(x: EditorStyle.default.spacing.s / 2, y: rowSize.height / 2)

  /// The selected row of the completion list paints the shared fill of the
  /// window state behind its text.
  @Test(arguments: windowStates)
  func theSelectedCompletionRowPaintsTheSharedFill(appearsActive: Bool) throws {
    let selected = try Self.pixels(
      of: Self.completionRow(isSelected: true), appearsActive: appearsActive, size: Self.rowSize)

    #expect(
      selected.isClose(
        to: try Self.fillPixels(appearsActive: appearsActive, size: Self.rowSize), at: [Self.rowSurfacePoint]))
  }

  /// A row that is not selected paints no fill.
  @Test func aCompletionRowThatIsNotSelectedPaintsNoFill() throws {
    let row = try Self.pixels(of: Self.completionRow(isSelected: false), appearsActive: true, size: Self.rowSize)

    #expect(
      row.isClose(
        to: try Self.pixels(of: Color.clear, appearsActive: true, size: Self.rowSize), at: [Self.rowSurfacePoint]))
  }

  // MARK: - Image

  /// An image whose block file the inspector shows paints the shared fill of
  /// the window state behind the image.
  @Test(arguments: windowStates)
  func anImageThatTheInspectorShowsPaintsTheSharedFill(appearsActive: Bool) throws {
    let (view, file) = try Self.imageBlock()
    let selected = view.environment(\.inspectorSelection, InspectorSelection(attachment: file))

    let pixels = try Self.pixels(of: selected, appearsActive: appearsActive, size: Self.fileSize)

    #expect(
      pixels.isClose(
        to: try Self.fillPixels(appearsActive: appearsActive, size: Self.fileSize),
        at: [Self.center(of: Self.fileSize)]))
  }

  /// An image whose file the inspector does not show paints no fill.
  @Test func anImageThatTheInspectorDoesNotShowPaintsNoFill() throws {
    let (view, _) = try Self.imageBlock()
    let unselected = view.environment(\.inspectorSelection, InspectorSelection())

    let pixels = try Self.pixels(of: unselected, appearsActive: true, size: Self.fileSize)

    #expect(pixels.isClose(to: try Self.pixels(of: Color.clear, appearsActive: true, size: Self.fileSize)))
  }

  /// A selected image that has the focus keeps its fill, and the focus ring
  /// of its scope outlines it with the square corners of the image.
  @Test func aSelectedImageWithTheFocusHasTheFillAndTheRing() throws {
    let (view, file) = try Self.imageBlock()
    let system = CommandSystem()
    let content = Self.onBackdrop(
      view.environment(\.inspectorSelection, InspectorSelection(attachment: file)),
      appearsActive: true
    )
    .commandSystem(system)
    let harness = HostedViewHarness(content, size: Self.fileSize)
    defer { harness.close() }
    harness.render()

    let focused = try FocusRing.focusScope(of: file.id, in: harness, system: system)
    let pixels = try #require(RenderedPixels(cachingDisplayOf: harness.hostingView))

    try Ring.expectFocusRingMask(of: focused.responder, cornerRadius: .zero)
    #expect(
      pixels.isClose(
        to: try Self.fillPixels(appearsActive: true, size: Self.fileSize), at: [Self.center(of: Self.fileSize)]))
  }

  // MARK: - Attachment chip

  /// An attachment view whose file the inspector shows draws the shared
  /// surface behind the chip, with the corners of the chip, and nothing
  /// more: its pixels are the pixels of the unselected view on that
  /// surface. So the text of the chip keeps the `.primary` color of the
  /// unselected chip.
  @Test(arguments: windowStates)
  func aSelectedAttachmentViewDrawsOnlyTheSharedSurfaceBehindItsText(appearsActive: Bool) throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let file = try Shared.attachment(named: Locations.fileName, in: directory)
    let unselected = AttachmentView(file).environment(\.inspectorSelection, InspectorSelection())
    let onSurface = unselected.selectionSurface(true, cornerRadius: EditorStyle.default.radii.m)

    let selected = try Self.pixels(
      of: AttachmentView(file).environment(\.inspectorSelection, InspectorSelection(attachment: Attachment(url: file.url))),
      appearsActive: appearsActive, size: Self.fileSize)
    let expected = try Self.pixels(of: onSurface, appearsActive: appearsActive, size: Self.fileSize)

    try #require(!expected.isClose(to: try Self.pixels(of: unselected, appearsActive: appearsActive, size: Self.fileSize)))
    #expect(selected.isClose(to: expected))
  }

  // MARK: - Tool call location

  /// The chip of a tool call location whose file the inspector shows draws a
  /// selected state.
  @Test func aLocationThatTheInspectorShowsDrawsTheSelectedState() async throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let url = try directory.file(named: Locations.fileName, contents: Locations.blobBytes)
    let (session, call) = try await Locations.openLocationCall(path: url.path(percentEncoded: false))
    defer { session.close() }
    let view = Locations.expandedView(of: call)

    let selected = try Self.pixels(
      of: view.environment(\.inspectorSelection, InspectorSelection(attachment: Attachment(url: url))),
      appearsActive: true, size: Locations.hostSize)
    let unselected = try Self.pixels(
      of: view.environment(\.inspectorSelection, InspectorSelection()), appearsActive: true, size: Locations.hostSize)

    #expect(!selected.isClose(to: unselected))
  }
}
