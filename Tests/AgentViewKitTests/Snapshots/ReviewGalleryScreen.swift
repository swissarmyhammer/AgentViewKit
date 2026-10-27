#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import DemoSupport
  import FoundationModelsACP
  import FoundationModelsACPClient
  import Quartz
  import SwiftUI
  import Testing

  /// The full screens of the review gallery (^8q34yt8): the whole thread
  /// view, the request deck in the bar, the banners, the sign-in prompt, the
  /// list scrolled under both bars, the attachment inspector and the gallery
  /// columns of the demo app.
  ///
  /// Each screen is the real kit view in the hidden window of path A of
  /// ``ViewSnapshot``, with fixed preview data. The cache of a window draws no
  /// Liquid Glass and no scroll edge effect, so each image shows what the kit
  /// draws: its fills, tints, layout and text over the content. Apple's glass
  /// is not in the images.
  ///
  /// The raw value is the name of the screen in the image names.
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

    /// The title of the screen in the contact sheet.
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

    /// The judgement of the reviewer under the row of the screen, with the
    /// id of each card that a finding made.
    var note: String {
      ReviewGalleryNotes.notes[self] ?? ReviewGalleryNotes.notJudged
    }

    /// The row of the screen in the contact sheet.
    var row: ReviewGalleryRow {
      ReviewGalleryRow(screen: rawValue, title: title, note: note)
    }

    /// The size of the image of the screen, in points.
    var size: CGSize {
      switch self {
      case .thread, .requestDeck, .banners, .signIn, .scrolled: ReviewGalleryFixtures.threadSize
      case .inspector, .gallery: ReviewGalleryFixtures.windowSize
      }
    }

    /// The pixels of the screen in `variant`.
    ///
    /// - Parameter variant: The settings of the image.
    /// - Returns: The pixels, or `nil` when AppKit gives no cache.
    /// - Throws: An issue when the screen cannot be built.
    func pixels(in variant: SnapshotVariant) async throws -> RenderedPixels? {
      switch self {
      case .thread: try await ReviewGalleryFixtures.threadPixels(size: size, variant: variant)
      case .requestDeck:
        try await ViewSnapshot.hostedPixels(of: ReviewGalleryFixtures.deckThread, size: size, variant: variant)
      case .banners:
        try await ViewSnapshot.hostedPixels(of: ReviewGalleryFixtures.bannerThread, size: size, variant: variant)
      case .signIn:
        try await ViewSnapshot.hostedPixels(of: ReviewGalleryFixtures.signInThread(), size: size, variant: variant)
      case .scrolled: try ReviewGalleryFixtures.scrolledPixels(size: size, variant: variant)
      case .inspector: try await ReviewGalleryFixtures.inspectorPixels(size: size, variant: variant)
      case .gallery: try await ReviewGalleryFixtures.galleryPixels(size: size, variant: variant)
      }
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
    /// location of the file, so that the expanded call shows a location chip.
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

    /// The pixels of the thread screen: each block expanded, after the
    /// syntax parse of the code block.
    ///
    /// - Parameters:
    ///   - size: The size of the image.
    ///   - variant: The settings of the image.
    /// - Returns: The pixels.
    /// - Throws: An issue when the cache has no model for the code block.
    static func threadPixels(size: CGSize, variant: SnapshotVariant) async throws -> RenderedPixels? {
      let session = try transcriptSession()
      let cache = CodeBlockModelCache()
      let thread = demoThread(session, connection: connection)
        .environment(\.expandedBlocksStore, ExpandedBlocksStore(defaultExpanded: { _ in true }))
        .environment(\.codeBlockModelCache, cache)
      return try await ViewSnapshot.hostedPixels(of: thread, size: size, variant: variant) {
        await SnapshotFixtures.waitForSyntax(of: try SnapshotFixtures.codeBlockModel(in: cache, session: session))
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

    /// The pixels of the scrolled screen: the long transcript of
    /// ``PreviewFixtures/scrolledSession``, moved to the row at
    /// ``scrolledRowIndex`` as the Show Error button of the state banner moves
    /// it, so that the list is away from the bottom and shows the pill.
    ///
    /// - Parameters:
    ///   - size: The size of the image.
    ///   - variant: The settings of the image.
    /// - Returns: The pixels.
    /// - Throws: An issue when the list does not leave the bottom.
    static func scrolledPixels(size: CGSize, variant: SnapshotVariant) throws -> RenderedPixels? {
      let session = PreviewFixtures.scrolledSession
      let anchors = ScrollAnchorManager()
      let thread = AgentThreadView(
        session: session, connection: connection, anchors: anchors, sessionTitle: sessionTitle
      ) {
        DefaultThreadComposer()
      }
      let harness = ViewSnapshot.makeHarness(of: thread, size: size, variant: variant)
      defer { harness.close() }
      harness.render()
      let key = session.transcript.map(\.rowKey)[scrolledRowIndex]
      anchors.noteJump(to: key)
      anchors.onScroll(.item(key))
      harness.render()
      try #require(!anchors.isPinnedToBottom, "The list of the scrolled screen did not leave the bottom.")
      harness.render()
      return ViewSnapshot.pixels(of: harness)
    }

    /// The pixels of the thread with the attachment inspector open on a file
    /// on disk. The image hides the live QuickLook preview, which draws out
    /// of process at a time that no event tells.
    ///
    /// - Parameters:
    ///   - size: The size of the image.
    ///   - variant: The settings of the image.
    /// - Returns: The pixels.
    /// - Throws: The error of the file of the attachment.
    static func inspectorPixels(size: CGSize, variant: SnapshotVariant) async throws -> RenderedPixels? {
      let directory = try TemporaryDirectory()
      defer { directory.remove() }
      let attachment = try AttachmentInspectorHostedTests.attachment(
        named: SnapshotFixtures.inspectorFileName, in: directory)
      let thread = demoThread(try transcriptSession(), connection: connection)
        .environment(\.inspectorSelection, InspectorSelection(attachment: attachment))
      return try await ViewSnapshot.hostedPixels(
        of: thread, size: size, variant: variant, hiding: [QLPreviewView.self])
    }

    /// The id of the scripted permission session of the Gallery tab
    /// (`DemoGallery.permission`).
    static let permissionSessionID = "gallery-permission"

    /// The pixels of the gallery columns of the demo app: the session list of
    /// the scripted sessions of the Gallery tab (``InMemoryDemoScript/gallery``)
    /// in the sidebar, and the resumed permission session in the detail. The
    /// permission session is open and waits for an answer, so its row shows
    /// the count of open requests.
    ///
    /// The image is made after the list shows the sessions that the agent
    /// sent, and after the permission request came. The function stops the
    /// agent at the end.
    ///
    /// - Parameters:
    ///   - size: The size of the image.
    ///   - variant: The settings of the image.
    /// - Returns: The pixels.
    /// - Throws: The error of the start of the agent or of `session/resume`.
    static func galleryPixels(size: CGSize, variant: SnapshotVariant) async throws -> RenderedPixels? {
      let agent = try await DemoAgent.makeInProcess(script: .gallery)
      let session = try await agent.connection.resumeSession(
        ResumeSessionRequest(
          cwd: agent.workingDirectory, sessionId: SessionId(rawValue: permissionSessionID),
          replayFrom: .start(ReplayFromStart())))
      let columns = GalleryColumns {
        SessionListView(connection: agent.connection, cwd: agent.workingDirectory, onOpen: { _ in })
          .navigationSplitViewColumnWidth(
            min: DemoWindowLayout.sidebarMinimumWidth, ideal: DemoWindowLayout.sidebarIdealWidth)
      } detail: {
        demoThread(session, connection: agent.connection)
      } lookControls: {
        EmptyView()
      }
      let pixels = await ViewSnapshot.hostedPixels(of: columns, size: size, variant: variant) {
        await ObservationWait.until { !agent.connection.sessions.isEmpty && !session.pendingPermissions.isEmpty }
      }
      await agent.stop()
      return pixels
    }
  }
#endif
