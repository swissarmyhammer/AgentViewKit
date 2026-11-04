@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorInspector
import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import Quartz
import SwiftUI

/// The inspector images of the review gallery (EditorKit `style.md`, "The
/// inspector" and "Review gallery").
///
/// Each subject shows as the content of a host's inspector panel, which owns
/// the one scroll view (`.inspectorScrolling(.host)`), at the width of a
/// narrow docked panel and of a wide one. A subject whose type folds several
/// objects shows two objects with different values too, so its rows read
/// "Mixed". `ReviewGallery` records each image in Light and in Dark. The
/// images are for a person to look at; no test reads their pixels.
///
/// The subjects: the attachment inspector in each ``AttachmentInspectorMode``,
/// the form style of ``ConfigOptionsView``, the list style of
/// ``ToolToggles``, and the inspection of each client model.
@MainActor
enum InspectorGallery {
  /// The section of the page of the inspector images.
  private static let suite = "Inspector"

  /// The width of a narrow docked panel, in points (Testudo's docked panel).
  private static let narrowWidth: CGFloat = 240

  /// The width of a wide docked panel, in points.
  private static let wideWidth: CGFloat = 640

  /// The height of each image, in points.
  private static let height: CGFloat = 560

  /// The width of the window of the built-in attachment inspector: a thread
  /// area with the inspector column at its trailing edge, in points.
  private static let builtInWidth: CGFloat = 900

  /// The size of the window of the built-in attachment inspector.
  private static let builtInSize = CGSize(width: builtInWidth, height: height)

  /// The panel widths of each subject, with the name of each in the image
  /// name.
  private static let widths: [(name: String, width: CGFloat)] = [("narrow", narrowWidth), ("wide", wideWidth)]

  /// One subject of the gallery: its name, its view of one object, and its
  /// view of several objects when its type folds them.
  struct Subject {
    /// The name of the subject in the image name, such as `tool-call`.
    let name: String

    /// The view of one object.
    let one: AnyView

    /// The view of two objects with different values, or `nil` when the
    /// subject shows one object only.
    let several: AnyView?

    /// Makes the subject of an `Inspectable` type.
    ///
    /// - Parameters:
    ///   - name: The name of the subject.
    ///   - first: The object of the single image, and the first of the
    ///     Mixed image.
    ///   - second: The second object of the Mixed image.
    init<Object: Inspectable>(_ name: String, _ first: Object, _ second: Object) {
      self.name = name
      one = AnyView(InspectorView(first))
      let objects = [first, second]
      several = AnyView(InspectorView(objects))
    }

    /// Makes the subject of a view that shows one object.
    ///
    /// - Parameters:
    ///   - name: The name of the subject.
    ///   - view: The view.
    init(_ name: String, view: some View) {
      self.name = name
      one = AnyView(view)
      several = nil
    }

    /// Makes the subject of a view of one object and a view of several.
    ///
    /// - Parameters:
    ///   - name: The name of the subject.
    ///   - one: The view of one object.
    ///   - several: The view of several objects with different values.
    init(_ name: String, one: some View, several: some View) {
      self.name = name
      self.one = AnyView(one)
      self.several = AnyView(several)
    }
  }

  /// Records each inspector image in `gallery`.
  ///
  /// - Parameter gallery: The review gallery of the package.
  /// - Throws: The error of a capture or of a write.
  static func record(in gallery: ReviewGallery) async throws {
    let fixtures = try await InspectorGalleryFixtures.open()
    defer { fixtures.close() }
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    defer { directory.remove() }
    let attachment = try AttachmentFixtures.attachment(named: SnapshotFixtures.inspectorFileName, in: directory)
    let second = try AttachmentFixtures.attachment(named: SnapshotFixtures.secondInspectorFileName, in: directory)
    let host = Subject(
      "attachment-host", one: AttachmentInspector(attachment), several: AttachmentInspector([attachment, second]))

    try await recordBuiltInAttachmentInspector(attachment, in: gallery)
    for subject in [host] + (try fixtures.subjects) {
      try await record(subject, in: gallery)
    }
  }

  /// Records the panel images of `subject`: one object, and several when
  /// the subject has them, at each width.
  ///
  /// - Parameters:
  ///   - subject: The subject.
  ///   - gallery: The review gallery.
  /// - Throws: The error of a capture or of a write.
  private static func record(_ subject: Subject, in gallery: ReviewGallery) async throws {
    let views = [("one", subject.one)] + (subject.several.map { [("mixed", $0)] } ?? [])
    for (count, view) in views {
      for (widthName, width) in widths {
        try await gallery.record(
          suite: suite, named: "inspector-\(subject.name)-\(widthName)-\(count)",
          size: CGSize(width: width, height: height), settle: hideQuickLook
        ) { _ in
          InspectorPanel(content: view)
        }
      }
    }
  }

  /// Records the built-in attachment inspector
  /// (``AttachmentInspectorMode/builtIn``): the trailing inspector column of
  /// `.attachmentInspector(selection:)` beside a transcript.
  ///
  /// - Parameters:
  ///   - attachment: The selected file.
  ///   - gallery: The review gallery.
  /// - Throws: The error of a capture or of a write.
  private static func recordBuiltInAttachmentInspector(
    _ attachment: AgentViewKit.Attachment, in gallery: ReviewGallery
  ) async throws {
    let selection = InspectorSelection(attachment: attachment)
    try await gallery.record(
      suite: suite, named: "inspector-attachment-builtin", size: builtInSize, settle: hideQuickLook
    ) { _ in
      GlassSnapshotTests.backdrop
        .attachmentInspector(selection: selection)
    }
  }

  /// Hides the live `QLPreviewView` of an attachment preview. QuickLook draws
  /// the preview out of process, and no event tells when it is drawn, so the
  /// image shows the place of the preview on each run
  /// (``HostedSnapshotTests/theAttachmentInspector()``).
  ///
  /// - Parameter mount: The mounted view.
  private static func hideQuickLook(_ mount: ReviewMount) async throws {
    mount.hideViews(of: [QLPreviewView.self])
  }
}

/// A host's inspector panel: the one scroll view of the panel, with the
/// inspector content in it, which does not scroll by itself.
private struct InspectorPanel: View {
  /// The inspector content.
  let content: AnyView

  var body: some View {
    ScrollView {
      content
    }
    .inspectorScrolling(.host)
  }
}
