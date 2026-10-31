#if DEBUG
  import EditorTestSupport
  import Foundation
  import Testing

  /// The review gallery of the package (^8q34yt8, ^wprq982), written with
  /// EditorKit's `ReviewGallery` helper (EditorKit `style.md`, "Review
  /// gallery").
  ///
  /// The test records each image of the snapshot suites, then each
  /// ``ReviewGalleryScreen`` in a real window on the screen in Light and in
  /// Dark, and writes the page `index.html` with both into ``gallery``. Each
  /// run of `swift test --package-path ScreenshotTests` writes the folder
  /// again. Open the page to review the screens.
  ///
  /// The test fails when a key screen cannot be built or captured, and when
  /// the page does not show a key screen or a recorded image. It reads no
  /// pixel of an image.
  @Suite(.serialized, .hostedSerially) @MainActor struct ReviewGalleryScreenTests {
    /// The name of the package, for the folder and the title of the page.
    static let package = "AgentViewKit"

    /// The review gallery of the package, at
    /// `~/Library/Caches/AgentViewKit/screenshot-check/`.
    static let gallery = ReviewGallery(package: package)

    /// Records every image of the snapshot suites.
    ///
    /// The suites run in any order beside the gallery page, so the page test
    /// calls this before it writes the page; the page then shows every image
    /// of the run, whichever suite ran first.
    ///
    /// - Throws: The error of a capture or of a write.
    static func recordSnapshots() async throws {
      let hosted = HostedSnapshotTests()
      try await hosted.theThread()
      try await hosted.theButtonsOfTheBottomBarBelowTheTranscript()
      try await hosted.theIdleComposer()
      try await hosted.theComposerWhileTheAgentRuns()
      try await hosted.thePermissionRequestCard()
      try await hosted.theRequestDeckInTheBar()
      try await hosted.theSessionNotice()
      try await hosted.theStatusBanner()
      try await hosted.theCodeBlock()
      try await hosted.theTerminalOutput()
      try await hosted.theElicitationForm()
      try await hosted.theAttachmentInspector()
      let glass = GlassSnapshotTests()
      try await glass.theHeaderOfTheThread()
      try await glass.theComposer()
      try await glass.theComposerWhileTheAgentRuns()
      try await glass.theRequestDeckInTheBar()
      try await glass.theFloatingControlsOfTheThread()
    }

    @Test func thePageShowsEachKeyScreenAndEachRecordedSnapshot() async throws {
      try await Self.recordSnapshots()
      let report = try await ReviewGalleryScreen.withReviewScreens(ReviewGalleryScreen.allCases[...]) { screens in
        try await Self.gallery.record(screens, snapshotRoots: [])
      }

      expectReviewGalleryComplete(report)
    }
  }
#endif
