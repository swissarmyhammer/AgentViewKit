import Testing

/// Checks that the header and the banners at the top of a thread are in the
/// top bar (TestudoApp `features/style.md`, "Scroll under the bars", D113
/// answer 7).
///
/// The list of a thread scrolls under its top bar, and thus under the
/// toolbar of the window, with the scroll edge effect. In
/// ``AgentThreadView``, the top bar is its `.safeAreaBar(edge: .top)` block.
/// The scan is the scan of ``ThreadBottomBarStructureTests``.
@Suite struct ThreadTopBarStructureTests {
  /// The code text before the opening brace of the top bar of a thread.
  static let topBarStart = ".safeAreaBar(edge: .top)"

  /// Each view that shows only in the top bar of the thread, in the order of
  /// the bar.
  static let topBarViews = ["AgentInfoHeader", "AgentConnectionBanner", "SessionNoticeBanner", "SessionStreamBanner"]
    .map { BarView(file: ComposerGlassStructureTests.threadFile, view: $0, barStart: topBarStart) }

  @Test(arguments: topBarViews)
  func eachViewAtTheTopOfTheThreadIsOnlyInTheTopBar(_ place: BarView) throws {
    try ThreadBottomBarStructureTests.expectOnlyInItsBar(place)
  }
}
