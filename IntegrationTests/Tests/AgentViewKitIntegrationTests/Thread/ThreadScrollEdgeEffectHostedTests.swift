#if DEBUG
  @testable import AgentViewKit
  import AppKit
  import EditorTestSupport
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// Tests for the scroll edge effect of the list of a thread under its two
  /// bars (^ph0m0hf).
  ///
  /// The list scrolls under the top bar and the bottom bar of the thread, and
  /// asks for the SOFT scroll edge effect at both edges (EditorKit
  /// `style.md`, "Scroll under the bars", D113 answer 7). The HARD effect,
  /// which TestudoApp measured with the `.automatic` style in its window, is
  /// an opaque band over the rows under a bar, with a separator line at the
  /// edge of the list: no row shows under the bar. The soft effect fades the
  /// rows under the bar, and a row still shows through it. The user accepted
  /// the washed-out look of the rows under the whole bar stack on 2026-10-23
  /// (^22wbz12).
  ///
  /// Each test captures a long thread in a real window on the screen at two
  /// scroll positions, with other rows under the bars in each, and reads the
  /// band of each edge effect: the part of the list under a bar, inside its
  /// content inset. Under the soft effect the band shows the rows under it, so
  /// it differs between the two positions. Under the hard effect the band is
  /// the same opaque fill at each position. The tests use two hosts: a plain
  /// thread, and the TestudoApp window shape (``SplitViewThreadHost``), where
  /// the `.automatic` style picks the hard effect.
  @Suite(.serialized, .hostedSerially) @MainActor struct ThreadScrollEdgeEffectHostedTests {
    /// A host of the thread.
    enum Host: CaseIterable, Sendable {
      /// A plain thread view, as TestudoApp `ChatAreaView` shows it.
      case plain

      /// The thread in the detail column of a three-column
      /// `NavigationSplitView` with an inspector and a toolbar, in a titled
      /// window, under an item header and a tab bar: the TestudoApp window.
      case splitView
    }

    /// One edge of the list.
    enum Edge: CaseIterable, Sendable {
      /// The top edge, under the top bars.
      case top

      /// The bottom edge, under the floating controls.
      case bottom
    }

    /// The size of the window of the plain thread, in points.
    static let plainSize = CGSize(width: 480, height: 640)

    /// The index of the row that the first capture scrolls to.
    static let firstRow = 4

    /// The index of the row that the second capture scrolls to: far enough
    /// from ``firstRow`` that other rows are under each bar.
    static let secondRow = 8

    /// The share of the content inset of an edge that the band of a test
    /// reads: the half of the effect nearest the visible rows, below the bars
    /// of a host and where a soft effect fades a row least.
    static let bandShare: CGFloat = 0.5

    /// A capture of the thread in a host, with the frame of its list.
    struct ScrolledThread {
      /// The capture of the hosting view of the window.
      let image: CapturedImage

      /// The frame of the scroll view of the list, in points from the top
      /// leading corner of the hosting view.
      let listFrame: CGRect

      /// The content insets of the list: the heights of the bars over it.
      let insets: NSEdgeInsets

      /// The region of the band of the edge effect at `edge`: the half of
      /// the content inset nearest the rows in view, as wide as the list.
      ///
      /// - Parameter edge: The edge of the list.
      /// - Returns: The region, in points from the top leading corner.
      func band(at edge: Edge) -> CGRect {
        let bandShare = ThreadScrollEdgeEffectHostedTests.bandShare
        switch edge {
        case .top:
          let height = insets.top * bandShare
          return CGRect(x: listFrame.minX, y: listFrame.minY + insets.top - height, width: listFrame.width, height: height)
        case .bottom:
          let height = insets.bottom * bandShare
          return CGRect(x: listFrame.minX, y: listFrame.maxY - insets.bottom, width: listFrame.width, height: height)
        }
      }
    }

    /// Captures the long thread of ``PreviewFixtures/scrolledSession`` in
    /// `host`, moved to the row at `index`, so that the list is away from
    /// both of its ends.
    ///
    /// - Parameters:
    ///   - host: The host of the thread.
    ///   - index: The index of the row that the list moves to.
    /// - Returns: The capture and the geometry of the list.
    /// - Throws: An issue when the list does not leave its bottom or has no
    ///   scroll view, or the error of the capture.
    static func capture(in host: Host, scrolledTo index: Int) async throws -> ScrolledThread {
      let session = PreviewFixtures.scrolledSession
      let anchors = ScrollAnchorManager()
      // The host gives the connection, as TestudoApp does: the header of the
      // agent fills the top bar. With no connection, no notice and no stream
      // banner, the top bar has no content and no height (^rgsq3k4), so the
      // top edge would have no rows under a bar.
      let thread = AgentThreadView(
        session: session, connection: ReviewGalleryFixtures.connection, anchors: anchors
      ) { DefaultThreadComposer() }
        .transaction { $0.disablesAnimations = true }
      switch host {
      case .plain:
        return try await capture(CaptureMount(thread, size: plainSize), session: session, anchors: anchors, row: index)
      case .splitView:
        let mount = CaptureMount(
          SplitViewThreadHost(thread: thread), size: ThreadBarInsetHostedTests.splitWindowSize,
          styleMask: ThreadBarInsetHostedTests.titledStyle)
        return try await capture(mount, session: session, anchors: anchors, row: index)
      }
    }

    /// Moves the list of `mount` to the row at `index` of `session`, and
    /// captures the hosting view with the frame of the list.
    ///
    /// - Parameters:
    ///   - mount: The mount of the thread.
    ///   - session: The session of the thread.
    ///   - anchors: The manager of the scroll position of the thread.
    ///   - index: The index of the row that the list moves to.
    /// - Returns: The capture and the geometry of the list.
    /// - Throws: An issue when the list does not leave its bottom or has no
    ///   scroll view, or the error of the capture.
    static func capture(
      _ mount: CaptureMount<some View>, session: SessionModel, anchors: ScrollAnchorManager, row index: Int
    ) async throws -> ScrolledThread {
      defer { mount.close() }
      let key = session.transcript.map(\.rowKey)[index]
      anchors.noteJump(to: key)
      anchors.onScroll(.item(key))
      mount.render()
      try #require(!anchors.isPinnedToBottom, "The list did not leave its bottom.")
      let list = try #require(
        views(ofType: NSScrollView.self, in: mount.hostingView).max { $0.frame.height < $1.frame.height })
      try #require(list.contentInsets.top > 0 && list.contentInsets.bottom > 0, "\(list.contentInsets)")
      let image = try await CapturedImage(capturing: mount.hostingView, over: NSColor.windowBackgroundColor.cgColor)
      return ScrolledThread(
        image: image, listFrame: mount.hostingView.convert(list.bounds, from: list), insets: list.contentInsets)
    }

    /// At each edge of the list, in each host, the rows under the bar show
    /// through the soft edge effect: the band of the effect differs between
    /// two scroll positions.
    @Test(arguments: Host.allCases, Edge.allCases)
    func theRowsUnderABarShowThroughTheSoftEdgeEffect(host: Host, edge: Edge) async throws {
      let first = try await Self.capture(in: host, scrolledTo: Self.firstRow)
      let second = try await Self.capture(in: host, scrolledTo: Self.secondRow)
      let band = CaptureGeometry.pixels(of: first.band(at: edge))

      #expect(try first.image.cropped(to: band) != second.image.cropped(to: band))
    }
  }
#endif
