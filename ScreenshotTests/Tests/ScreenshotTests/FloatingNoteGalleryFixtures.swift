#if DEBUG
  @testable import AgentViewKit
  import EditorStyle
  import EditorTestSupport
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI

  /// The fixed data of the images of the notes that float over the
  /// transcript (TestudoApp D213): a thread whose list is scrolled away from
  /// the bottom, so that rows are under the notice of the top bar and under
  /// the state banner "The agent is ready" of the bottom bar, or under the
  /// sign-in card of the bottom bar.
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

    /// The sign-in methods of the sign-in card: an agent method and a
    /// terminal method, so that the card shows a Sign In button and a Run
    /// button.
    static let signInMethods = [PreviewFixtures.agentAuthMethod, PreviewFixtures.terminalAuthMethod]

    /// Records the image of the thread with its floating status notes in
    /// each look.
    ///
    /// - Parameters:
    ///   - name: The name of the image.
    ///   - reducesTransparency: Whether the views read Reduce Transparency.
    /// - Throws: The error of the settle or of the capture.
    static func recordNotes(named name: String, reducesTransparency: Bool) async throws {
      try await record(
        named: name, session: session, connection: ReviewGalleryFixtures.connection,
        reducesTransparency: reducesTransparency)
    }

    /// Records the image of the thread with the sign-in card in its bottom
    /// bar in each look. The agent asks for a sign-in, so the card floats
    /// over the rows of the long transcript of
    /// ``PreviewFixtures/scrolledTranscript``.
    ///
    /// - Parameters:
    ///   - name: The name of the image.
    ///   - reducesTransparency: Whether the views read Reduce Transparency.
    /// - Throws: The error of the settle or of the capture.
    static func recordSignIn(named name: String, reducesTransparency: Bool) async throws {
      let session = PreviewFixtures.scrolledSession
      try await record(
        named: name, session: session,
        connection: PreviewFixtures.authConnection(methods: signInMethods, openSessions: [session]),
        reducesTransparency: reducesTransparency)
    }

    /// Records the image of a thread with its floating notes in each look.
    ///
    /// The settle moves the list away from the bottom
    /// (``ReviewGalleryFixtures/scrollAway(_:in:mount:)``). With
    /// `reducesTransparency`, the views of the thread read Reduce
    /// Transparency from the environment value, as under the system setting.
    /// The test changes no system setting (EditorKit `style.md`, rule 9). The
    /// terminal auth runner of the previews starts no process, so the Run
    /// button of a sign-in card runs no agent program.
    ///
    /// - Parameters:
    ///   - name: The name of the image.
    ///   - session: The session of the thread, with a long transcript.
    ///   - connection: The connection model of the thread.
    ///   - reducesTransparency: Whether the views read Reduce Transparency.
    /// - Throws: The error of the settle or of the capture.
    private static func record(
      named name: String, session: SessionModel, connection: ConnectionModel, reducesTransparency: Bool
    ) async throws {
      let anchors = ScrollAnchorManager()
      try await ReviewGalleryScreenTests.gallery.record(
        suite: "GlassSnapshotTests", named: name, size: ReviewGalleryFixtures.threadSize,
        settle: { mount in try ReviewGalleryFixtures.scrollAway(anchors, in: session, mount: mount) },
        content: { _ in
          AgentThreadView(
            session: session, connection: connection, anchors: anchors,
            sessionTitle: ReviewGalleryFixtures.sessionTitle
          ) {
            DefaultThreadComposer()
          }
          .terminalAuthRunner(PreviewFixtures.terminalAuthRunner)
          .environment(\._accessibilityReduceTransparency, reducesTransparency)
          // The gallery mounts the thread as a host does, with the bar inset
          // of the style (`.barInsets()`, ^e0wdpmg).
          .barInsets()
        })
    }
  }
#endif
