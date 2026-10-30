import Testing

/// Checks that the header and the banners at the top of a thread are in the
/// top bar (EditorKit `style.md`, "Scroll under the bars", D113
/// answer 7), and that only the header is on glass.
///
/// The list of a thread scrolls under its top bar, and thus under the
/// toolbar of the window, with the scroll edge effect. AppKit makes that
/// effect as tall as the whole top inset, so it washes out the rows under the
/// bars, and fades only near the top of the list (^22wbz12, accepted by the
/// user on 2026-10-23). In ``AgentThreadView``, the top bar is its
/// `.safeAreaBar(edge: .top)` block.
/// The scan is the scan of ``ThreadBottomBarStructureTests``.
///
/// The header is a floating surface, the same as the conversation header in
/// Messages: it is on the floating glass of EditorStyle, `floatingGlass()`.
/// The connection banner, the notice banner and the stream banner are
/// content, with no glass of their own. The scan reads the bar one line at a
/// time, so the header and its glass are on one code line.
@Suite struct ThreadTopBarStructureTests {
  /// The code text before the opening brace of the top bar of a thread.
  static let topBarStart = ".safeAreaBar(edge: .top)"

  /// The view of the top bar that is on the floating glass of the kit.
  static let header = "AgentInfoHeader"

  /// The views of the top bar that are content, with no glass, in the order
  /// of the bar.
  static let banners = ["AgentConnectionBanner", "SessionNoticeBanner", "SessionStreamBanner"]

  /// Each view that shows only in the top bar of the thread, in the order of
  /// the bar.
  static let topBarViews = ([header] + banners)
    .map { BarView(file: ComposerGlassStructureTests.threadFile, view: $0, barStart: topBarStart) }

  /// The glass forms that make a glass surface in the thread view: the
  /// floating glass of the kit. EditorKit's `glassPlacement` engine holds the
  /// thread view to no direct glass effect (``StyleRuleEngineTests``).
  static let surfaceForms = [GlassForm.floatingGlass]

  /// The code lines of the top bar of the thread, with each comment and each
  /// string literal blanked.
  ///
  /// - Returns: The lines of the bar block.
  /// - Throws: An error when the file cannot be read, or an issue when the
  ///   file has no top bar.
  static func topBarLines() throws -> [Substring] {
    let code = try ThreadBottomBarStructureTests.code(of: ComposerGlassStructureTests.threadFile)
    let bar = try #require(ThreadBottomBarStructureTests.block(after: topBarStart, in: code))
    return bar.split(separator: "\n")
  }

  /// The lines of the top bar that call a view.
  ///
  /// - Parameter view: The name of the view type.
  /// - Returns: The lines with a call of `view`.
  /// - Throws: The error of ``topBarLines()``.
  static func topBarLines(calling view: String) throws -> [Substring] {
    try topBarLines().filter { $0.contains(GlassForm.callPattern(view)) }
  }

  /// Whether a code line makes a glass surface: one of ``surfaceForms``.
  ///
  /// - Parameter line: The code line.
  /// - Returns: `true` when the line uses a form of ``surfaceForms``.
  static func makesGlassSurface(_ line: Substring) -> Bool {
    surfaceForms.contains { line.contains($0.pattern) }
  }

  @Test(arguments: topBarViews)
  func eachViewAtTheTopOfTheThreadIsOnlyInTheTopBar(_ place: BarView) throws {
    try ThreadBottomBarStructureTests.expectOnlyInItsBar(place)
  }

  @Test func theHeaderInTheTopBarIsOnTheFloatingGlassOfTheKit() throws {
    let lines = try Self.topBarLines(calling: Self.header)

    #expect(lines.count == 1, "\(lines)")
    #expect(lines.allSatisfy { $0.contains(GlassForm.floatingGlass.pattern) }, "\(lines)")
  }

  @Test func theHeaderIsTheOnlyGlassSurfaceOfTheTopBar() throws {
    let surfaces = try Self.topBarLines().filter(Self.makesGlassSurface)

    #expect(surfaces.count == 1, "\(surfaces)")
    #expect(surfaces.allSatisfy { $0.contains(GlassForm.callPattern(Self.header)) }, "\(surfaces)")
  }

  @Test(arguments: banners)
  func eachBannerInTheTopBarIsContentWithNoGlass(_ banner: String) throws {
    let lines = try Self.topBarLines(calling: banner)
    let glass = lines.filter(Self.makesGlassSurface)

    #expect(lines.count == 1, "\(lines)")
    #expect(glass.isEmpty, "\(glass)")
  }
}
