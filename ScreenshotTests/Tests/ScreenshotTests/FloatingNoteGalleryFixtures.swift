#if DEBUG
  @testable import AgentViewKit
  import EditorStyle
  import EditorTestSupport
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI

  /// The fixed data of the images of the status notes that float over the
  /// transcript (TestudoApp D213): a thread whose list is scrolled away from
  /// the bottom, so that rows are under the notice of the top bar and under
  /// the state banner "The agent is ready" of the bottom bar.
  ///
  /// Each note is on the floating glass of the kit, the glass of the status
  /// line, so the text of the rows under it does not show through it.
  @MainActor enum FloatingNoteGalleryFixtures {
    /// The notice of the top bar.
    static let notice = Notice(
      severity: .warning, title: "The context is almost full",
      description: "The agent compacts the context before the next prompt.")

    /// A new session with the long transcript of
    /// ``PreviewFixtures/scrolledTranscript``, the notice of the top bar and
    /// an idle state with no stop reason, so that the state banner shows
    /// "The agent is ready".
    static var session: SessionModel {
      .preview(
        transcript: PreviewFixtures.scrolledTranscript + [
          .update(.notice(notice)), .update(.stateUpdate(.idle(IdleStateUpdate()))),
        ])
    }

    /// Records the image of the thread with its floating notes in each look.
    ///
    /// The settle moves the list away from the bottom
    /// (``ReviewGalleryFixtures/scrollAway(_:in:mount:)``). With
    /// `reducesTransparency`, the views of the thread read Reduce
    /// Transparency from the environment value, as under the system setting.
    /// The test changes no system setting (EditorKit `style.md`, rule 9).
    ///
    /// - Parameters:
    ///   - name: The name of the image.
    ///   - reducesTransparency: Whether the views read Reduce Transparency.
    /// - Throws: The error of the settle or of the capture.
    static func record(named name: String, reducesTransparency: Bool) async throws {
      let session = session
      let anchors = ScrollAnchorManager()
      try await ReviewGalleryScreenTests.gallery.record(
        suite: "GlassSnapshotTests", named: name, size: ReviewGalleryFixtures.threadSize,
        settle: { mount in try ReviewGalleryFixtures.scrollAway(anchors, in: session, mount: mount) },
        content: { _ in
          AgentThreadView(
            session: session, connection: ReviewGalleryFixtures.connection, anchors: anchors,
            sessionTitle: ReviewGalleryFixtures.sessionTitle
          ) {
            DefaultThreadComposer()
          }
          .environment(\._accessibilityReduceTransparency, reducesTransparency)
          // The gallery mounts the thread as a host does, with the bar inset
          // of the style (`.barInsets()`, ^e0wdpmg).
          .barInsets()
        })
    }
  }
#endif
