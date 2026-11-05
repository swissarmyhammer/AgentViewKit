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
/// The form is EditorKit's `InspectorView`: the form identifier stands on
/// its group, and its grouped form, a scroll view on macOS, is a scroll area
/// under it. The section rows of the form sit inside the system margin,
/// and a view that fills a row has the leading and trailing inset of the row
/// content.
@Suite(.serialized, .hostedSerially) @MainActor struct AttachmentInspectorFormHostedTests {
  /// The size of the window: about the width of an inspector column.
  static let size = CGSize(width: 320, height: 600)

  @Test func theContentOfTheInspectorIsAScrollingForm() throws {
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    defer { directory.remove() }
    let attachment = try Self.attachment(in: directory)
    let harness = try Self.mountInspector(of: attachment)
    defer { harness.close() }

    let roles = harness.elements(under: AttachmentInspector.formIdentifier).compactMap(\.role)
    #expect(roles.contains(NSAccessibility.Role.scrollArea.rawValue))
    let inForm = Set(harness.elements(under: AttachmentInspector.formIdentifier).compactMap(\.identifier))
    #expect(inForm.contains(AttachmentInspector.nameIdentifier(of: [attachment])))
    for identifier in AttachmentInspector.actionIdentifiers {
      #expect(inForm.contains(identifier), "No action \(identifier) in the form.")
    }
  }

  /// The preview has the inset of the section rows: its leading edge is the
  /// leading edge of the name row, and its trailing inset from the form is
  /// the same as its leading inset.
  @Test func thePreviewHasTheLeadingAndTrailingInsetOfTheSectionRows() throws {
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    defer { directory.remove() }
    let attachment = try Self.attachment(in: directory)
    let harness = try Self.mountInspector(of: attachment)
    defer { harness.close() }

    let form = try #require(harness.frame(identifier: AttachmentInspector.formIdentifier))
    let name = try #require(harness.frame(identifier: AttachmentInspector.nameIdentifier(of: [attachment])))
    let previewView = try #require(views(ofType: QLPreviewView.self, in: harness.hostingView).first)
    let preview = harness.screenFrame(of: previewView)

    let leadingInset = preview.minX - form.minX
    #expect(leadingInset > 0)
    #expect(preview.minX == name.minX)
    #expect(form.maxX - preview.maxX == leadingInset)
  }

  /// Mounts the inspector of `attachment` in a window of ``size``, and makes
  /// one render pass.
  ///
  /// The mount and the render pass are those of
  /// ``AttachmentInspectorHostedTests/mountInspectorContent(of:size:)``.
  ///
  /// - Parameter attachment: The file of the inspector.
  /// - Returns: The harness of the inspector. The caller closes it.
  /// - Throws: An issue when the selection holds no attachment.
  static func mountInspector(of attachment: AgentViewKit.Attachment) throws
    -> HostedViewHarness<AttachmentInspector>
  {
    try AttachmentInspectorHostedTests.mountInspectorContent(
      of: InspectorSelection(attachments: [attachment]), size: size)
  }

  /// Writes the file of the inspector to `directory`, and makes its
  /// attachment.
  ///
  /// - Parameter directory: The directory of the file.
  /// - Returns: The attachment of the file.
  /// - Throws: The error of the write of the file.
  static func attachment(in directory: TemporaryFolder) throws -> AgentViewKit.Attachment {
    try AttachmentFixtures.attachment(named: "blob.bin", in: directory)
  }
}
