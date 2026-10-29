@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorTestSupport
import Quartz
import SwiftUI
import Testing

/// Checks the layout of ``AttachmentInspector``: a grouped form with the
/// system margins, the look of the inspectors of Xcode and Icon Composer
/// (^bkhgxs5).
///
/// A grouped form on macOS is a scroll view, so its accessibility element is
/// a scroll area. The section rows of the form sit inside the system margin,
/// and a view that fills a row has the leading and trailing inset of the row
/// content. The form shows the backdrop of its host in its margin: a kit view
/// adds no opaque fill of its own (the rows keep the system look).
@Suite(.serialized, .hostedSerially) @MainActor struct AttachmentInspectorFormHostedTests {
  /// The size of the window: about the width of an inspector column.
  static let size = CGSize(width: 320, height: 600)

  /// A point in the top leading corner of the window, in points. The form
  /// has its system margin there, and no section row.
  static let marginPoint = CGPoint(x: 2, y: 2)

  @Test func theContentOfTheInspectorIsAScrollingForm() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let harness = try Self.mountInspector(in: directory)
    defer { harness.close() }

    let form = try #require(harness.element(identifier: AttachmentInspector.formIdentifier))
    #expect(form.role == NSAccessibility.Role.scrollArea.rawValue)
    let inForm = Set(harness.elements(under: AttachmentInspector.formIdentifier).compactMap(\.identifier))
    #expect(inForm.contains(AttachmentInspector.nameIdentifier))
    for identifier in AttachmentInspector.actionIdentifiers {
      #expect(inForm.contains(identifier), "No action \(identifier) in the form.")
    }
  }

  /// The preview has the inset of the section rows: its leading edge is the
  /// leading edge of the name row, and its trailing inset from the form is
  /// the same as its leading inset.
  @Test func thePreviewHasTheLeadingAndTrailingInsetOfTheSectionRows() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let harness = try Self.mountInspector(in: directory)
    defer { harness.close() }

    let form = try #require(harness.frame(identifier: AttachmentInspector.formIdentifier))
    let name = try #require(harness.frame(identifier: AttachmentInspector.nameIdentifier))
    let previewView = try #require(views(ofType: QLPreviewView.self, in: harness.hostingView).first)
    let preview = harness.screenFrame(of: previewView)

    let leadingInset = preview.minX - form.minX
    #expect(leadingInset > 0)
    #expect(preview.minX == name.minX)
    #expect(form.maxX - preview.maxX == leadingInset)
  }

  @Test func theBackdropOfTheHostShowsInTheMarginOfTheForm() async throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try Self.attachment(in: directory)

    let image = try await ContentEdgeHostedProbe.capture(
      of: AttachmentInspector(attachment), backdrop: .behindToTheEdge, size: Self.size)

    #expect(try GlassRenderProbeTests.showsBackdrop(image, at: Self.marginPoint))
  }

  /// Mounts the inspector of a file in `directory` in a window of ``size``,
  /// and makes one render pass.
  ///
  /// The mount and the render pass are those of
  /// ``AttachmentInspectorHostedTests/mountInspectorContent(of:size:)``.
  ///
  /// - Parameter directory: The directory of the file.
  /// - Returns: The harness of the inspector. The caller closes it.
  /// - Throws: The error of the write of the file.
  static func mountInspector(in directory: TemporaryDirectory) throws
    -> HostedViewHarness<AttachmentInspector>
  {
    try AttachmentInspectorHostedTests.mountInspectorContent(
      of: InspectorSelection(attachment: attachment(in: directory)), size: size)
  }

  /// Writes the file of the inspector to `directory`, and makes its
  /// attachment.
  ///
  /// - Parameter directory: The directory of the file.
  /// - Returns: The attachment of the file.
  /// - Throws: The error of the write of the file.
  static func attachment(in directory: TemporaryDirectory) throws -> AgentViewKit.Attachment {
    try AttachmentInspectorHostedTests.attachment(named: "blob.bin", in: directory)
  }
}
