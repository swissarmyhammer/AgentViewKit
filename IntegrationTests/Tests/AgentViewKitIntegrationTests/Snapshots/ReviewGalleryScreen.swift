#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import DemoSupport
  import EditorTestSupport
  import FoundationModelsACP
  import FoundationModelsACPClient
  import Quartz
  import SwiftUI
  import Testing

  /// The key screens of the review gallery (^8q34yt8): the whole thread
  /// view, the request deck in the bar, the banners, the sign-in prompt, the
  /// list scrolled under both bars, the attachment inspector and the gallery
  /// columns of the demo app.
  ///
  /// Each screen is an EditorKit `ReviewScreen`: the real kit view with fixed
  /// preview data, which EditorKit's `ReviewGallery.record` mounts in a real
  /// key window on the screen in Light and in Dark and captures from the
  /// window server (EditorKit `style.md` rule 9 and "Review gallery"). The
  /// images show what the app shows: Liquid Glass, the scroll edge effect,
  /// the vibrant labels in each look, and the mic and Send buttons of the
  /// composer. A popover is its own window, so no image shows one.
  ///
  /// The raw value is the id of the screen in the image names.
  enum ReviewGalleryScreen: String, CaseIterable {
    /// The thread with a transcript, a code block, a tool call with a diff,
    /// terminal output, a plan, the state banner, the suggestion chips, the
    /// dictation button and the composer.
    case thread

    /// The request deck in the bottom bar, with a permission request in
    /// front of a form request, above the composer.
    case requestDeck = "request-deck"

    /// The connection banner, a notice of each severity, and the state banner
    /// of a failed turn with its Show Error button.
    case banners

    /// The sign-in prompt in the bottom bar, under a prompt with an
    /// attachment chip.
    case signIn = "sign-in"

    /// A long transcript scrolled up, so that rows are under the top bar and
    /// under the bottom bar, with the scroll-to-bottom pill.
    case scrolled

    /// The thread with the attachment inspector open.
    case inspector

    /// The gallery columns of the demo app: the session list in the sidebar
    /// and a thread in the detail.
    case gallery

    /// The title of the row of the screen on the page.
    var title: String {
      switch self {
      case .thread: "Thread"
      case .requestDeck: "Request deck in the bar"
      case .banners: "Banners"
      case .signIn: "Sign-in prompt"
      case .scrolled: "List under both bars"
      case .inspector: "Attachment inspector"
      case .gallery: "Gallery columns"
      }
    }

    /// The size of the image of the screen, in points.
    var size: CGSize {
      switch self {
      case .thread, .requestDeck, .banners, .signIn, .scrolled: ReviewGalleryFixtures.threadSize
      case .inspector, .gallery: ReviewGalleryFixtures.windowSize
      }
    }

    /// The region of the glass column of the screen whose dark look a test
    /// checks, in points from the top leading corner of the image: the session
    /// list in the sidebar of the gallery columns, and the top of the
    /// attachment inspector with its form rows. `nil` for a screen with no
    /// glass column.
    var glassColumn: CGRect? {
      switch self {
      case .gallery: ReviewGalleryFixtures.sidebarColumn
      case .inspector: ReviewGalleryFixtures.inspectorColumn
      case .thread, .requestDeck, .banners, .signIn, .scrolled: nil
      }
    }

    /// The EditorKit key screen with the id, the title, the dated note and the
    /// size of this screen.
    ///
    /// The endless animations of the screen are held still, as in each
    /// capture of the package (``StillCaptureContent``,
    /// ``stopProgressIndicators(in:)``), so that each capture takes the first
    /// two equal images.
    ///
    /// - Parameters:
    ///   - settle: The wait for an event of the mounted screen before the
    ///     capture. Do not wait for a time.
    ///   - content: The view of the screen in a look.
    /// - Returns: The key screen.
    /// - Throws: The error of ``ReviewGalleryNotes/note(of:)``.
    func reviewScreen<Content: View>(
      settle: @escaping @MainActor (ReviewMount) async throws -> Void = { _ in },
      @ViewBuilder content: @escaping @MainActor (ReviewAppearance) -> Content
    ) throws -> ReviewScreen {
      ReviewScreen(
        id: rawValue, title: title, note: try ReviewGalleryNotes.note(of: self), size: size,
        settle: { mount in
          try await settle(mount)
          stopProgressIndicators(in: mount.hostingView)
        },
        content: { appearance in StillCaptureContent(content: content(appearance)) })
    }

    /// Runs `body` with the key screen of this screen, and frees what the
    /// screen holds after it: the file of the attachment inspector, and the
    /// agent of the gallery columns.
    ///
    /// - Parameter body: The work with the key screen.
    /// - Returns: The result of `body`.
    /// - Throws: The error of a fixture, or of `body`.
    func withReviewScreen<T>(_ body: (ReviewScreen) async throws -> T) async throws -> T {
      switch self {
      case .thread: try await body(ReviewGalleryFixtures.threadScreen())
      case .requestDeck: try await body(reviewScreen { _ in ReviewGalleryFixtures.deckThread })
      case .banners: try await body(reviewScreen { _ in ReviewGalleryFixtures.bannerThread })
      case .signIn: try await body(ReviewGalleryFixtures.signInScreen())
      case .scrolled: try await body(ReviewGalleryFixtures.scrolledScreen())
      case .inspector: try await ReviewGalleryFixtures.withInspectorScreen(body)
      case .gallery: try await ReviewGalleryFixtures.withGalleryScreen(body)
      }
    }

    /// Runs `body` with the key screen of each of `screens`, in order, and
    /// frees what each screen holds after it.
    ///
    /// - Parameters:
    ///   - screens: The screens still to make.
    ///   - made: The key screens made so far.
    ///   - body: The work with every key screen.
    /// - Returns: The result of `body`.
    /// - Throws: The error of a fixture, or of `body`.
    static func withReviewScreens<T>(
      _ screens: ArraySlice<ReviewGalleryScreen>, made: [ReviewScreen] = [],
      _ body: ([ReviewScreen]) async throws -> T
    ) async throws -> T {
      if let first = screens.first {
        return try await first.withReviewScreen { screen in
          try await withReviewScreens(screens.dropFirst(), made: made + [screen], body)
        }
      }
      return try await body(made)
    }

    /// The image of the screen in `appearance` that `gallery` wrote when it
    /// recorded the screen. The check of a look reads the page of the run, so
    /// no screen is mounted and captured a second time for it.
    ///
    /// - Parameters:
    ///   - appearance: The look of the window.
    ///   - gallery: The gallery that recorded the screen.
    /// - Returns: The image.
    /// - Throws: The error of the read or of the decode.
    func recordedImage(in appearance: ReviewAppearance, of gallery: ReviewGallery) throws -> CapturedImage {
      let file = gallery.directory.appending(path: ReviewGallery.screenPath(id: rawValue, appearance: appearance))
      return try CapturedImage(decoding: Data(contentsOf: file))
    }
  }

  /// The fixed data and the views of ``ReviewGalleryScreen``.
  enum ReviewGalleryFixtures {
    /// The width of the image of a thread screen, in points: about the width
    /// of the detail column of the demo window.
    static let threadWidth: CGFloat = 760

    /// The height of the image of a thread screen, in points.
    static let threadHeight: CGFloat = 860

    /// The width of the image of a screen with two columns, in points: about
    /// the width of the demo window.
    static let windowWidth: CGFloat = 1180

    /// The height of the image of a screen with two columns, in points:
    /// about the height of the demo window.
    static let windowHeight: CGFloat = 760

    /// The size of the image of a thread screen, in points: about the detail
    /// column of the demo window.
    static let threadSize = CGSize(width: threadWidth, height: threadHeight)

    /// The size of the image of a screen with two columns, in points: about
    /// the demo window.
    static let windowSize = CGSize(width: windowWidth, height: windowHeight)

    /// The width of the part of the attachment inspector that
    /// ``inspectorColumn`` reads, in points from the trailing edge: inside
    /// the inspector at each width it takes.
    static let inspectorColumnWidth: CGFloat = 200

    /// The height of the part of the attachment inspector that
    /// ``inspectorColumn`` reads, in points from the top: the form rows over
    /// the preview.
    static let inspectorColumnHeight: CGFloat = 350

    /// The session list in the sidebar of the gallery columns: the least
    /// width of the sidebar, from the top to the bottom of the window.
    static let sidebarColumn = CGRect(
      x: 0, y: 0, width: DemoWindowLayout.sidebarMinimumWidth, height: windowHeight)

    /// The form rows at the top of the attachment inspector, at the trailing
    /// edge of the window.
    static let inspectorColumn = CGRect(
      x: windowWidth - inspectorColumnWidth, y: 0, width: inspectorColumnWidth, height: inspectorColumnHeight)

    /// The title of each session in the header of a thread.
    static let sessionTitle = "Rename the search function"

    /// The suggestions of the composer.
    static let suggestions = ["Run the full test suite", "Explain the diff"]

    /// The id of the tool call with the diff.
    static let diffToolCallID = "review-gallery-edit"

    /// The index of the row that the scrolled screen moves to: the user
    /// message of the third turn. The rows of the first two turns are then
    /// above it, under the top bar, and the last rows are below the part in
    /// view, under the bottom bar.
    static let scrolledRowIndex = 4

    /// The connection of an agent that is connected and needs no sign-in, so
    /// that the header names the agent.
    static var connection: ConnectionModel {
      .preview(
        initializeResponse: InitializeResponse(
          info: Implementation(name: "Review Agent", version: "1.0.0"),
          protocolVersion: ACPClient.supportedProtocolVersion, authMethods: []))
    }

    /// Decodes the JSON text of one `session/update` notification.
    ///
    /// - Parameter json: The JSON text of the update.
    /// - Returns: The update.
    /// - Throws: The error of the decode.
    static func update(_ json: String) throws -> SessionUpdate {
      try JSONDecoder().decode(SessionUpdate.self, from: Data(json.utf8))
    }

    /// The update of a completed edit with a patch of one file, and the
    /// location of the same file. The diff shows the file as its file chip,
    /// so the expanded call shows no location chip for it (card ^tgjr9xg).
    ///
    /// - Returns: The update.
    /// - Throws: The error of the JSON encode or decode.
    static func diffToolCall() throws -> SessionUpdate {
      let patch = try #require(String(data: JSONEncoder().encode(PreviewFixtures.smallPatch), encoding: .utf8))
      return try update(
        #"""
        {"sessionUpdate": "tool_call_update", "toolCallId": "\#(diffToolCallID)", "title": "Edit SearchIndex.swift",
         "kind": "edit", "status": "completed", "locations": [{"path": "/project/Sources/Search/SearchIndex.swift", "line": 2}],
         "content": [{"type": "diff", "changes": [], "patch": {"format": "git_patch", "text": \#(patch)}}]}
        """#)
    }

    /// The prompt of the user, with a link to a zip archive, so that the
    /// message shows an attachment chip. An archive has no preview, so the
    /// chip is the default renderer of its type (`AttachmentView`), and it
    /// shows with no load.
    ///
    /// - Returns: The update.
    /// - Throws: The error of the decode.
    static func promptWithAttachment() throws -> SessionUpdate {
      try update(
        #"""
        {"sessionUpdate": "user_message", "messageId": "review-gallery-prompt",
         "content": [{"type": "text", "text": "Rename the search function, and run the tests of the checkout module."},
                     {"type": "resource_link", "uri": "file:///project/Archives/Release.zip", "name": "Release.zip",
                      "mimeType": "application/zip", "size": 24576}]}
        """#)
    }

    /// The session of the thread screen: a prompt with an attachment, a reply
    /// with a code block, an edit with a diff, terminal output, a tool call, a
    /// plan, and a last reply.
    ///
    /// - Returns: The session model.
    /// - Throws: The error of a decode.
    static func transcriptSession() throws -> SessionModel {
      .preview(transcript: [
        .update(try promptWithAttachment()),
        .agent(SnapshotFixtures.agentMessage),
        .update(try diffToolCall()),
        .terminal(
          command: SnapshotFixtures.terminalCommand, output: SnapshotFixtures.terminalOutput,
          exitCode: CommandOutputView.successExitCode),
        .toolCall(title: "Run \(SnapshotFixtures.shellCode)", kind: .execute, status: .completed),
        .plan([
          PlanEntry(content: "Rename the search function", priority: .high, status: .completed),
          PlanEntry(content: "Run the tests of the checkout module", priority: .medium, status: .completed),
        ]),
        .agent("The 18 tests of the checkout module pass."),
        .update(.stateUpdate(.idle(IdleStateUpdate(stopReason: .endTurn)))),
      ])
    }

    /// The thread of a demo session: the usage, the request deck and the
    /// default composer in the composer slot, as `SessionThreadColumn` of the
    /// demo app shows them, with the message actions, the suggestions and the
    /// dictation button.
    ///
    /// - Parameters:
    ///   - session: The session of the thread.
    ///   - connection: The connection of the thread.
    /// - Returns: The view.
    static func demoThread(_ session: SessionModel, connection: ConnectionModel) -> some View {
      AgentThreadView(session: session, connection: connection, sessionTitle: sessionTitle) {
        ContextUsageView(session: session)
          .frame(maxWidth: .infinity, alignment: .trailing)
        RequestDeck(session: session)
        DefaultThreadComposer()
      }
      .messageFooter { entry in MessageActions(entry: entry) }
      .promptSuggestions(suggestions)
      .speechTranscriber(FakeSpeechTranscriber())
    }

    /// The thread screen: each block expanded, captured after the syntax
    /// parse of the code block.
    ///
    /// - Returns: The key screen.
    /// - Throws: The error of a decode or of the note. The settle records an
    ///   issue when the cache has no model for the code block.
    static func threadScreen() throws -> ReviewScreen {
      let session = try transcriptSession()
      let cache = CodeBlockModelCache()
      return try ReviewGalleryScreen.thread.reviewScreen(settle: { _ in
        await SnapshotFixtures.waitForSyntax(of: try SnapshotFixtures.codeBlockModel(in: cache, session: session))
      }) { _ in
        demoThread(session, connection: connection)
          .environment(\.expandedBlocksStore, ExpandedBlocksStore(defaultExpanded: { _ in true }))
          .environment(\.codeBlockModelCache, cache)
      }
    }

    /// The thread whose deck shows a permission request in front of a form
    /// request.
    static var deckThread: some View {
      let permission = RequestPermissionRequest(
        options: [
          PermissionOption(kind: .allowOnce, name: "Allow", optionId: PermissionOptionId(rawValue: "allow")),
          PermissionOption(kind: .allowAlways, name: "Always Allow", optionId: PermissionOptionId(rawValue: "always")),
          PermissionOption(kind: .rejectOnce, name: "Reject", optionId: PermissionOptionId(rawValue: "reject")),
        ],
        sessionId: SessionModel.previewSessionId, title: "Run swift test?")
      let session = SessionModel.preview(
        transcript: [
          .user("Why does the build fail?"),
          .agent("Parser.swift does not import Foundation. I will add the import and run the tests."),
          .toolCall(title: "Run swift test", kind: .execute, status: .pending),
        ],
        pendingPermissions: [permission], pendingElicitations: [PreviewFixtures.formElicitation])
      return demoThread(session, connection: connection)
    }

    /// The thread of a disconnected agent with a notice of each severity and
    /// a turn that failed.
    static var bannerThread: some View {
      let notices = [
        Notice(severity: .info, title: "A new model version is available", description: "The next session uses it."),
        Notice(severity: .warning, title: "The quota is almost used", description: "You used 90 percent of it."),
        Notice(severity: .error, title: "The search index is not available", description: "Build the index again."),
      ]
      let session = SessionModel.preview(
        transcript: [.user("Search the project for the parser.")]
          + notices.map { .update(.notice($0)) }
          + [.update(.stateUpdate(.idle(IdleStateUpdate(stopReason: .error))))])
      session.appendError(code: .internalError, message: "The search tool did not start.", data: nil)
      return demoThread(session, connection: .preview(state: .disconnected))
    }

    /// The thread of an agent that asks for a sign-in, after a prompt with an
    /// attachment. The transcript is short, so the attachment chip of the
    /// prompt is in view.
    ///
    /// - Returns: The view.
    /// - Throws: The error of ``promptWithAttachment()``.
    static func signInThread() throws -> some View {
      demoThread(
        .preview(transcript: [.update(try promptWithAttachment())]),
        connection: AgentAuthViewSurfaceHostedTests.connection)
    }

    /// The sign-in screen: ``signInThread()`` in each look.
    ///
    /// - Returns: The key screen.
    /// - Throws: The error of ``signInThread()`` or of the note.
    static func signInScreen() throws -> ReviewScreen {
      let thread = try signInThread()
      return try ReviewGalleryScreen.signIn.reviewScreen { _ in thread }
    }

    /// The scrolled screen: the long transcript of
    /// ``PreviewFixtures/scrolledSession``, moved to the row at
    /// ``scrolledRowIndex`` as the Show Error button of the state banner moves
    /// it, so that the list is away from the bottom and shows the pill.
    ///
    /// - Returns: The key screen.
    /// - Throws: The error of the note. The settle records an issue when the
    ///   list does not leave the bottom.
    static func scrolledScreen() throws -> ReviewScreen {
      let session = PreviewFixtures.scrolledSession
      let anchors = ScrollAnchorManager()
      return try ReviewGalleryScreen.scrolled.reviewScreen(settle: { mount in
        let key = session.transcript.map(\.rowKey)[scrolledRowIndex]
        anchors.noteJump(to: key)
        anchors.onScroll(.item(key))
        mount.render()
        try #require(!anchors.isPinnedToBottom, "The list of the scrolled screen did not leave the bottom.")
      }) { _ in
        AgentThreadView(session: session, connection: connection, anchors: anchors, sessionTitle: sessionTitle) {
          DefaultThreadComposer()
        }
      }
    }

    /// Runs `body` with the screen of the thread with the attachment
    /// inspector open on a file on disk, and removes the file after it. The
    /// image hides the live QuickLook preview, which draws out of process at
    /// a time that no event tells.
    ///
    /// - Parameter body: The work with the key screen.
    /// - Returns: The result of `body`.
    /// - Throws: The error of the file of the attachment, of a decode, of the
    ///   note, or of `body`.
    static func withInspectorScreen<T>(_ body: (ReviewScreen) async throws -> T) async throws -> T {
      let directory = try TemporaryDirectory()
      defer { directory.remove() }
      let attachment = try AttachmentFixtures.attachment(
        named: SnapshotFixtures.inspectorFileName, in: directory)
      let session = try transcriptSession()
      let screen = try ReviewGalleryScreen.inspector.reviewScreen(settle: { mount in
        hideViews(of: [QLPreviewView.self], in: mount.hostingView)
      }) { _ in
        demoThread(session, connection: connection)
          .environment(\.inspectorSelection, InspectorSelection(attachment: attachment))
      }
      return try await body(screen)
    }

    /// The id of the scripted permission session of the Gallery tab
    /// (`DemoGallery.permission`).
    static let permissionSessionID = "gallery-permission"

    /// Runs `body` with the screen of the gallery columns of the demo app: the
    /// session list of the scripted sessions of the Gallery tab
    /// (``InMemoryDemoScript/gallery``) in the sidebar, and the resumed
    /// permission session in the detail. The permission session is open and
    /// waits for an answer, so its row shows the count of open requests.
    ///
    /// The image is made after the list shows the sessions that the agent
    /// sent, and after the permission request came. The agent stops after
    /// `body`, also when it throws.
    ///
    /// - Parameter body: The work with the key screen.
    /// - Returns: The result of `body`.
    /// - Throws: The error of the start of the agent, of `session/resume`, of
    ///   the note, or of `body`.
    static func withGalleryScreen<T>(_ body: (ReviewScreen) async throws -> T) async throws -> T {
      let agent = try await DemoAgent.makeInProcess(script: .gallery)
      do {
        let session = try await agent.connection.resumeSession(
          ResumeSessionRequest(
            cwd: agent.workingDirectory, sessionId: SessionId(rawValue: permissionSessionID),
            replayFrom: .start(ReplayFromStart())))
        let screen = try ReviewGalleryScreen.gallery.reviewScreen(settle: { mount in
          await mount.render { !agent.connection.sessions.isEmpty && !session.pendingPermissions.isEmpty }
        }) { _ in
          GalleryColumns {
            SessionListView(connection: agent.connection, cwd: agent.workingDirectory, onOpen: { _ in })
              .navigationSplitViewColumnWidth(
                min: DemoWindowLayout.sidebarMinimumWidth, ideal: DemoWindowLayout.sidebarIdealWidth)
          } detail: {
            demoThread(session, connection: agent.connection)
          } lookControls: {
            EmptyView()
          }
        }
        let result = try await body(screen)
        await agent.stop()
        return result
      } catch {
        await agent.stop()
        throw error
      }
    }
  }
#endif
