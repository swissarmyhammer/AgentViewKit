import EditorStyle
#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import AppKit
  import EditorTestSupport
  import SwiftUI
  import Testing

  /// Tests for the content insets of the list of a thread in the host shapes
  /// of TestudoApp (^ph0m0hf).
  ///
  /// The list scrolls under the bars, so its `NSScrollView` fills the column,
  /// and its public `contentInsets` keep the rows clear of the bars when the
  /// list is at an end. The top inset must be the real height of what is
  /// above the list: the title bar and the toolbar of the window, the bars of
  /// the host, and the top bar of the thread. The bottom inset must be the
  /// height of the bottom bar of the thread, the floating controls.
  ///
  /// The tests read the frames of the accessibility elements in the bars, so
  /// each height comes from the views and not from the insets:
  ///
  /// - The top bar of the thread starts two small spacings above the
  ///   ``AgentInfoHeader``: the inset of the header in its glass, and the
  ///   padding of its glass container. It
  ///   ends below the text of the notice by the tile padding of the row and
  ///   the tile margin that the bar gives the ``SessionNoticeBanner``
  ///   (^rgsq3k4).
  /// - The floating controls end one medium spacing above the bottom edge
  ///   of the list, their outer padding, which is out of their element.
  /// - A bar of the host is an element with ``hostBarIdentifier``. With no
  ///   such bar, the bars of the host end at the top edge of the safe area of
  ///   the hosting view: the title bar and the toolbar of a titled window.
  ///
  /// The windows are never on a screen. TestudoApp measured the defect in
  /// its real window: the top inset was 278 points, with a toolbar of 52
  /// points and a tab bar of 24 points.
  @Suite(.serialized, .hostedSerially) @MainActor struct ThreadBarInsetHostedTests {
    /// The height of the tab bar of a host, in points, the height of the
    /// TestudoApp tab header.
    static let hostBarHeight: CGFloat = 24

    /// The accessibility identifier of the tab bar of a host.
    static let hostBarIdentifier = "host-tab-bar"

    /// The size of the window of a `NavigationSplitView` host, the size of
    /// the TestudoApp window.
    static let splitWindowSize = CGSize(width: 1280, height: 800)

    /// The largest difference, in points, between an inset and the height
    /// that a test counts as the same height. An accessibility frame is
    /// rounded to a whole pixel, and the window of the harness has a backing
    /// scale of one.
    static let insetTolerance: CGFloat = 1

    /// The style of a window with a title bar and a toolbar, whose content
    /// fills the window under the title bar, as the TestudoApp window does.
    static let titledStyle: NSWindow.StyleMask = [.titled, .closable, .resizable, .fullSizeContentView]

    /// The tab bar of a host: a fill with the height of the TestudoApp tab
    /// header, as one accessibility element.
    static var hostBar: some View {
      Color.gray
        .frame(height: hostBarHeight)
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: "Tabs"))
        .accessibilityIdentifier(hostBarIdentifier)
    }

    /// The thread of `session` with its connection model.
    ///
    /// - Parameter session: The scripted session.
    /// - Returns: The thread view, with no animation.
    static func thread(_ session: ScriptedSession) -> some View {
      AgentThreadView(session: session.model, connection: session.connection)
        .transaction { $0.disablesAnimations = true }
    }

    /// The `NSScrollView` of the list in `harness`.
    ///
    /// - Parameter harness: The harness that shows the thread.
    /// - Returns: The scroll view whose frame holds the part of the list in
    ///   view.
    /// - Throws: An issue when the list or its scroll view is not there.
    static func listScrollView(in harness: HostedViewHarness<some View>) throws -> NSScrollView {
      let visiblePart = try #require(harness.frame(identifier: ConversationLayout.listIdentifier))
      return try #require(views(ofType: NSScrollView.self, in: harness.hostingView).first { harness.screenFrame(of: $0).contains(visiblePart) })
    }

    /// The height of the top bar of the thread in `harness`, from the frames
    /// of the header and the notice in the bar.
    ///
    /// - Parameters:
    ///   - harness: The harness that shows the thread.
    ///   - session: The scripted session, which has one notice.
    /// - Returns: The height, in points.
    /// - Throws: An issue when the header or the notice is not there.
    static func topBarHeight(in harness: HostedViewHarness<some View>, session: ScriptedSession) throws -> CGFloat {
      let style = EditorStyle.default
      let header = try #require(harness.frame(identifier: AgentInfoHeader.identifier))
      let notice = try #require(harness.frame(identifier: ThreadTopBarHostedTests.noticeIdentifier(of: session)))
      // Below the text of the notice: the padding of its tile, and then the
      // margin around the notice banners. The y axis of the screen goes up.
      let belowNotice = style.tile.padding + style.tile.margin
      return (header.maxY + aboveHeader) - (notice.minY - belowNotice)
    }

    /// The space of the top bar above the ``AgentInfoHeader``: the inset of
    /// the header in its glass and the padding of its glass container, one
    /// small spacing each.
    static var aboveHeader: CGFloat {
      EditorStyle.default.spacing.s + EditorStyle.default.spacing.s
    }

    /// The screen y of the bottom edge of the bars of the host in `harness`:
    /// the bottom of the tab bar of the host, or the top edge of the safe
    /// area of the hosting view when the host has no tab bar.
    ///
    /// - Parameter harness: The harness that shows the host.
    /// - Returns: The y, in screen points. The y axis goes up.
    static func hostBarsBottom(in harness: HostedViewHarness<some View>) -> CGFloat {
      if let hostBar = harness.frame(identifier: hostBarIdentifier) {
        return hostBar.minY
      }
      return harness.screenFrame(of: harness.hostingView).maxY - harness.hostingView.safeAreaInsets.top
    }

    /// Expects that the top bar of the thread in `harness` starts at the
    /// bottom edge of the bars of the host, so the ``AgentInfoHeader`` is not
    /// under a bar of the host (^786dxt8).
    ///
    /// - Parameter harness: The harness that shows the thread in its host.
    /// - Throws: An issue when the header is not there.
    static func expectTheHeaderBelowTheHostBars(in harness: HostedViewHarness<some View>) throws {
      let header = try #require(harness.frame(identifier: AgentInfoHeader.identifier))
      // The y axis of the screen goes up.
      let topBarTop = header.maxY + aboveHeader
      let hostBottom = hostBarsBottom(in: harness)

      #expect(abs(topBarTop - hostBottom) <= insetTolerance, "top bar top \(topBarTop), host bars bottom \(hostBottom)")
    }

    /// Expects that the top inset of the list in `harness` is the height of
    /// the bars above the list, that the bottom inset is the height of the
    /// floating controls, and that the header is below the bars of the host.
    ///
    /// - Parameters:
    ///   - harness: The harness that shows the thread in its host.
    ///   - session: The scripted session, which has one notice.
    /// - Throws: An issue when the list or an element of a bar is not there.
    static func expectInsetsOfTheBars(in harness: HostedViewHarness<some View>, session: ScriptedSession) throws {
      let scrollView = try listScrollView(in: harness)
      let list = harness.screenFrame(of: scrollView)
      let controls = try #require(harness.frame(identifier: AgentThreadLayout.floatingControlsIdentifier))
      let barsAbove = try list.maxY - hostBarsBottom(in: harness) + topBarHeight(in: harness, session: session)
      let barBelow = controls.maxY + EditorStyle.default.spacing.m - list.minY
      let insets = scrollView.contentInsets

      #expect(abs(insets.top - barsAbove) <= insetTolerance, "top inset \(insets.top), bars above \(barsAbove)")
      #expect(abs(insets.bottom - barBelow) <= insetTolerance, "bottom inset \(insets.bottom), bar below \(barBelow)")
      try expectTheHeaderBelowTheHostBars(in: harness)
    }

    /// Mounts `content` in a harness, makes one render pass, and expects the
    /// insets of the bars (``expectInsetsOfTheBars(in:session:)``).
    ///
    /// - Parameters:
    ///   - content: The host of the thread of `session`.
    ///   - session: The scripted session, which has one notice.
    ///   - size: The size of the content.
    ///   - styleMask: The style of the window.
    /// - Throws: An issue when the list or an element of a bar is not there.
    static func expectInsetsOfTheBars(
      of content: some View, session: ScriptedSession, size: CGSize = ConnectionModelViewsHostedTests.size,
      styleMask: NSWindow.StyleMask = .borderless
    ) throws {
      let harness = HostedViewHarness(content, size: size, styleMask: styleMask)
      defer { harness.close() }
      harness.render()
      try expectInsetsOfTheBars(in: harness, session: session)
    }

    /// (a) A plain thread view, as TestudoApp `ChatAreaView` shows it.
    @Test func theInsetsOfAPlainThreadAreTheHeightsOfItsBars() async throws {
      let session = try await ThreadTopBarHostedTests.openSessionWithNotice()
      defer { session.close() }

      try Self.expectInsetsOfTheBars(of: Self.thread(session), session: session)
    }

    /// (b) A host that wraps the thread in its own outer top bar, as the tab
    /// header of TestudoApp does, with the built-in inspector of the thread.
    @Test func theTopInsetOfAThreadUnderAHostBarCountsTheHostBar() async throws {
      let session = try await ThreadTopBarHostedTests.openSessionWithNotice()
      defer { session.close() }

      try Self.expectInsetsOfTheBars(
        of: Self.thread(session).safeAreaBar(edge: .top) { Self.hostBar }, session: session)
    }

    /// (b) A host that puts its own top bar in an outer safe area inset,
    /// with the built-in inspector of the thread (^786dxt8).
    @Test func theTopInsetOfAThreadUnderAHostInsetCountsTheHostInset() async throws {
      let session = try await ThreadTopBarHostedTests.openSessionWithNotice()
      defer { session.close() }

      try Self.expectInsetsOfTheBars(
        of: Self.thread(session).safeAreaInset(edge: .top, spacing: 0) { Self.hostBar }, session: session)
    }

    /// (b) A host that wraps the thread in its own outer top bar, with the
    /// inspector of the host (``AttachmentInspectorMode/host(_:)``), as
    /// TestudoApp does.
    @Test func theTopInsetOfAThreadUnderAHostBarInHostModeCountsTheHostBar() async throws {
      let session = try await ThreadTopBarHostedTests.openSessionWithNotice()
      defer { session.close() }

      try Self.expectInsetsOfTheBars(
        of: Self.thread(session)
          .safeAreaBar(edge: .top) { Self.hostBar }
          .agentAttachmentInspector(.host(.constant(nil))),
        session: session)
    }

    /// (c) The thread in the detail column of a three-column
    /// `NavigationSplitView` with an inspector and a toolbar, in a titled
    /// window, under an item header and a tab bar: the TestudoApp window
    /// (`WindowAreasView`, `ChatAreaView`).
    @Test func theTopInsetOfAThreadInASplitViewDetailCountsTheToolbarAndTheHostBar() async throws {
      let session = try await ThreadTopBarHostedTests.openSessionWithNotice()
      defer { session.close() }

      try Self.expectInsetsOfTheBars(
        of: SplitViewThreadHost(thread: Self.thread(session)), session: session, size: Self.splitWindowSize,
        styleMask: Self.titledStyle)
    }
  }

  /// The TestudoApp window around one thread: a three-column
  /// `NavigationSplitView` with an inspector and a toolbar item. The detail
  /// column shows an item header and a divider above the thread, and the
  /// thread has a tab bar in an outer top bar. The thread shows its
  /// attachments in the inspector of the host.
  struct SplitViewThreadHost<Thread: View>: View {
    /// The thread view of the detail column.
    let thread: Thread

    var body: some View {
      NavigationSplitView {
        Text(verbatim: "Sidebar")
      } content: {
        Text(verbatim: "Items")
      } detail: {
        VStack(spacing: 0) {
          Text(verbatim: "Item header")
          Divider()
          thread
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .contain)
            .contentShape(Rectangle())
            .safeAreaBar(edge: .top) { ThreadBarInsetHostedTests.hostBar }
        }
      }
      .inspector(isPresented: .constant(true)) {
        Text(verbatim: "Inspector")
      }
      .toolbar {
        ToolbarItem {
          Button(String(localized: "Share")) {}
        }
      }
      .agentAttachmentInspector(.host(.constant(nil)))
    }
  }
#endif
