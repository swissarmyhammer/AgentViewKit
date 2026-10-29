import AppKit
import EditorCommands
import EditorCommandsUI
import EditorExtensions
import EditorStyle
import EditorTestSupport
import Foundation
import SwiftUI
import Testing
import UniformTypeIdentifiers

@testable import AgentViewKit

/// The kit draws each selection through the shared selection surface of
/// EditorKit (card ^dn1m56r): the theme accent at
/// ``EditorStyle/selectionOpacity`` behind a selected item while the window
/// is key, never the `.tint` of a host (EditorKit ^d5f8cwa), `.primary` at
/// ``EditorStyle/inactiveSelectionOpacity`` while it is not, and the text of
/// the item stays `.primary`. A focused item keeps its fill, and the focus
/// ring of its scope outlines it.
///
/// Each test shows a view over a white backdrop in light mode, in the
/// ``AgentItemFocusRingHostedTests/AccentLook``: under a red host tint and
/// the shared ``AccentTheme`` of EditorKit with a blue accent, in a real
/// window on the screen, captured from the window server. Each test sets
/// `\.appearsActive` itself, so that it chooses the window state of the
/// selection.
@Suite(.serialized, .hostedSerially) @MainActor struct SelectionSurfaceSitesHostedTests {
  /// The attachment of the kit. FoundationModelsACP has a type of the same
  /// name.
  typealias Attachment = AgentViewKit.Attachment

  /// The suite whose helpers make the files of the attachments.
  typealias Shared = AttachmentInspectorHostedTests

  /// The suite whose helpers land the focus on an attachment scope.
  typealias FocusRing = AttachmentFocusRingHostedTests

  /// The suite whose helpers give the accent look and read a focus ring.
  typealias Ring = AgentItemFocusRingHostedTests

  /// The suite whose helpers show a tool call with a location.
  typealias Locations = ContentFileSelectionHostedTests

  /// The suite whose helpers make the image block.
  typealias Blocks = WireContentBlockViewHostedTests

  /// The suite whose helper compares one pixel of two captures.
  typealias Surfaces = KitSurfaceRenderTests

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

  /// `view` over the backdrop, in light mode, in the accent look of the
  /// tests with the window state `appearsActive`.
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
    .modifier(Ring.AccentLook(appearsActive: appearsActive))
    .environment(\.colorScheme, .light)
  }

  /// The capture of `view` over the backdrop, in a real window.
  ///
  /// - Parameters:
  ///   - view: The view to show.
  ///   - appearsActive: Whether the window appears active.
  ///   - size: The size of the window.
  /// - Returns: The image.
  /// - Throws: A `WindowCaptureError`, or the error of ScreenCaptureKit.
  static func capture(of view: some View, appearsActive: Bool, size: CGSize) async throws -> CapturedImage {
    try await GlassRenderProbeTests.capture(of: onBackdrop(view, appearsActive: appearsActive), size: size)
  }

  /// The capture of a window that the fill of a selected surface covers: the
  /// theme accent at the selection opacity while the window is key, and the
  /// inactive grey while it is not.
  ///
  /// - Parameters:
  ///   - appearsActive: Whether the window appears active.
  ///   - size: The size of the window.
  /// - Returns: The image.
  /// - Throws: A `WindowCaptureError`, or the error of ScreenCaptureKit.
  static func fillCapture(appearsActive: Bool, size: CGSize) async throws -> CapturedImage {
    let fill =
      appearsActive
      ? Ring.accent.opacity(EditorStyle.selectionOpacity)
      : Color.primary.opacity(EditorStyle.inactiveSelectionOpacity)
    return try await capture(of: fill, appearsActive: appearsActive, size: size)
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
  func theSelectedCompletionRowPaintsTheSharedFill(appearsActive: Bool) async throws {
    let selected = try await Self.capture(
      of: Self.completionRow(isSelected: true), appearsActive: appearsActive, size: Self.rowSize)
    let fill = try await Self.fillCapture(appearsActive: appearsActive, size: Self.rowSize)

    #expect(try Surfaces.samePixel(in: selected, and: fill, at: Self.rowSurfacePoint))
  }

  /// A row that is not selected paints no fill.
  @Test func aCompletionRowThatIsNotSelectedPaintsNoFill() async throws {
    let row = try await Self.capture(
      of: Self.completionRow(isSelected: false), appearsActive: true, size: Self.rowSize)
    let clear = try await Self.capture(of: Color.clear, appearsActive: true, size: Self.rowSize)

    #expect(try Surfaces.samePixel(in: row, and: clear, at: Self.rowSurfacePoint))
  }

  // MARK: - Image

  /// An image whose block file the inspector shows paints the shared fill of
  /// the window state behind the image.
  @Test(arguments: windowStates)
  func anImageThatTheInspectorShowsPaintsTheSharedFill(appearsActive: Bool) async throws {
    let (view, file) = try Self.imageBlock()
    let selected = view.environment(\.inspectorSelection, InspectorSelection(attachment: file))

    let image = try await Self.capture(of: selected, appearsActive: appearsActive, size: Self.fileSize)
    let fill = try await Self.fillCapture(appearsActive: appearsActive, size: Self.fileSize)

    #expect(try Surfaces.samePixel(in: image, and: fill, at: Self.center(of: Self.fileSize)))
  }

  /// An image whose file the inspector does not show paints no fill.
  @Test func anImageThatTheInspectorDoesNotShowPaintsNoFill() async throws {
    let (view, _) = try Self.imageBlock()
    let unselected = view.environment(\.inspectorSelection, InspectorSelection())

    let image = try await Self.capture(of: unselected, appearsActive: true, size: Self.fileSize)
    let clear = try await Self.capture(of: Color.clear, appearsActive: true, size: Self.fileSize)

    #expect(image == clear)
  }

  /// A selected image that has the focus keeps its fill, and the focus ring
  /// of its scope outlines it with the square corners of the image.
  @Test func aSelectedImageWithTheFocusHasTheFillAndTheRing() async throws {
    let (view, file) = try Self.imageBlock()
    let system = CommandSystem()
    let content = Self.onBackdrop(
      view.environment(\.inspectorSelection, InspectorSelection(attachment: file)),
      appearsActive: true
    )
    .commandSystem(system)
    let mount = CaptureMount(content, size: Self.fileSize)
    defer { mount.close() }

    let focused = try await FocusRing.focusScope(of: file.id, in: mount, system: system)
    let image = try await mount.capture()

    try await Ring.expectRing(of: focused, cornerRadius: .zero)
    let fill = try await Self.fillCapture(appearsActive: true, size: Self.fileSize)
    #expect(try Surfaces.samePixel(in: image, and: fill, at: Self.center(of: Self.fileSize)))
  }

  // MARK: - Attachment chip

  /// An attachment view whose file the inspector shows draws the shared
  /// surface behind the chip, with the corners of the chip, and nothing
  /// more: its pixels are the pixels of the unselected view on that
  /// surface. So the text of the chip keeps the `.primary` color of the
  /// unselected chip.
  @Test(arguments: windowStates)
  func aSelectedAttachmentViewDrawsOnlyTheSharedSurfaceBehindItsText(appearsActive: Bool) async throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let file = try Shared.attachment(named: Locations.fileName, in: directory)
    let unselected = AttachmentView(file).environment(\.inspectorSelection, InspectorSelection())
    let onSurface = unselected.selectionSurface(true, cornerRadius: EditorStyle.default.radii.m)

    let selected = try await Self.capture(
      of: AttachmentView(file).environment(\.inspectorSelection, InspectorSelection(attachment: Attachment(url: file.url))),
      appearsActive: appearsActive, size: Self.fileSize)
    let expected = try await Self.capture(of: onSurface, appearsActive: appearsActive, size: Self.fileSize)
    let plain = try await Self.capture(of: unselected, appearsActive: appearsActive, size: Self.fileSize)

    try #require(expected != plain)
    #expect(selected == expected)
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

    let selected = try await Self.capture(
      of: view.environment(\.inspectorSelection, InspectorSelection(attachment: Attachment(url: url))),
      appearsActive: true, size: Locations.hostSize)
    let unselected = try await Self.capture(
      of: view.environment(\.inspectorSelection, InspectorSelection()), appearsActive: true, size: Locations.hostSize)

    #expect(selected != unselected)
  }
}
