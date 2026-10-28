#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import AppKit
  import SwiftUI
  import Testing

  /// Tests for the scroll edge effect of the list of a thread under its two
  /// bars (^ph0m0hf).
  ///
  /// The list scrolls under the top bar and the bottom bar of the thread, and
  /// asks for the SOFT scroll edge effect at both edges (EditorKit
  /// `style.md`, "Scroll under the bars", D113 answer 7). With the
  /// `.automatic` style, AppKit picks the effect from the context of the
  /// window. TestudoApp measured the HARD effect in its window: an opaque band
  /// over its tab bar and the top bar of the thread, with a separator line at
  /// the top edge of the list, and no row drawn under the bars.
  ///
  /// The soft style does not keep the rows under the top bars readable.
  /// AppKit makes the one top effect of the list as tall as the whole top
  /// inset (the toolbar, the bars of the host and the top bar of the thread),
  /// so it washes out the rows under that stack and fades only near the top of
  /// the list (^22wbz12). The user accepted this system look on 2026-10-23.
  /// These tests check only the style, not that a row shows under a bar.
  ///
  /// An offscreen window does not draw the effect, so the tests read the
  /// style that the list asks of AppKit for each edge. Only private AppKit
  /// state holds that style, and ``ScrollPocketProbe`` is the one helper that
  /// reads it. The tests use two hosts: a plain thread, and the TestudoApp
  /// window shape (``SplitViewThreadHost``).
  @Suite(.serialized, .hostedSerially) @MainActor struct ThreadScrollEdgeEffectHostedTests {
    /// Mounts `content` in a harness, makes one render pass, and expects the
    /// soft style at the top edge and the bottom edge of the list.
    ///
    /// - Parameters:
    ///   - content: The host of a thread.
    ///   - size: The size of the content.
    ///   - styleMask: The style of the window.
    /// - Throws: An issue when the list or its scroll view is not there.
    static func expectSoftEdges(
      of content: some View, size: CGSize = ConnectionModelViewsHostedTests.size,
      styleMask: NSWindow.StyleMask = .borderless
    ) throws {
      let harness = HostedViewHarness(content, size: size, styleMask: styleMask)
      defer { harness.close() }
      harness.render()

      let scrollView = try ThreadBarInsetHostedTests.listScrollView(in: harness)
      let styles = ScrollPocketProbe.styles(of: scrollView)

      #expect(styles[ScrollPocketProbe.topEdge] == ScrollPocketProbe.softStyle, "styles by edge \(styles)")
      #expect(styles[ScrollPocketProbe.bottomEdge] == ScrollPocketProbe.softStyle, "styles by edge \(styles)")
    }

    /// A plain thread view, as TestudoApp `ChatAreaView` shows it.
    @Test func theListOfAPlainThreadAsksForTheSoftEdgeEffectUnderBothBars() async throws {
      let session = try await ThreadTopBarHostedTests.openSessionWithNotice()
      defer { session.close() }

      try Self.expectSoftEdges(of: ThreadBarInsetHostedTests.thread(session))
    }

    /// The thread in the detail column of a three-column
    /// `NavigationSplitView` with an inspector and a toolbar, in a titled
    /// window, under an item header and a tab bar: the TestudoApp window.
    @Test func theListOfAThreadInASplitViewDetailAsksForTheSoftEdgeEffectUnderBothBars() async throws {
      let session = try await ThreadTopBarHostedTests.openSessionWithNotice()
      defer { session.close() }

      try Self.expectSoftEdges(
        of: SplitViewThreadHost(session: session), size: ThreadBarInsetHostedTests.splitWindowSize,
        styleMask: ThreadBarInsetHostedTests.titledStyle)
    }
  }
#endif
