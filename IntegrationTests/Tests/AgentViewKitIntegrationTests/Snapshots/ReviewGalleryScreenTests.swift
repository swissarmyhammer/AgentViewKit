#if DEBUG
  import EditorTestSupport
  import Foundation
  import Testing

  /// The review gallery of the package (^8q34yt8, ^wprq982), written with
  /// EditorKit's `ReviewGallery` helper (EditorKit `style.md`, "Review
  /// gallery").
  ///
  /// The test records each ``ReviewGalleryScreen`` in a real window on the
  /// screen in Light and in Dark, finds every reference PNG under
  /// ``snapshotRoot``, and writes the page `index.html` with both into
  /// ``gallery``. Each run of `swift test` writes the folder again. Open the
  /// page to review the screens.
  ///
  /// The gallery compares no image with a reference image, so a changed
  /// screen does not fail the test. The test fails when a key screen cannot
  /// be built or captured, and when the page does not show a key screen or a
  /// reference PNG.
  @Suite(.serialized, .hostedSerially) @MainActor struct ReviewGalleryScreenTests {
    /// The name of the package, for the folder and the title of the page.
    static let package = "AgentViewKit"

    /// The review gallery of the package, at
    /// `~/Library/Caches/AgentViewKit/screenshot-check/`.
    static let gallery = ReviewGallery(package: package)

    /// The folder of the reference PNGs of the snapshot suites: the
    /// `__Snapshots__` folder next to this file.
    static let snapshotRoot = URL(filePath: #filePath).deletingLastPathComponent()
      .appending(path: ReviewImageSource.referenceFolderName, directoryHint: .isDirectory)

    @Test func thePageShowsEachKeyScreenAndEachReferenceSnapshot() async throws {
      let report = try await ReviewGalleryScreen.withReviewScreens(ReviewGalleryScreen.allCases[...]) { screens in
        try await Self.gallery.record(screens, snapshotRoots: [Self.snapshotRoot])
      }

      expectReviewGalleryComplete(report)
    }

    @Test(arguments: [ReviewGalleryScreen.gallery, .inspector])
    func theDarkImageShowsLightTextOnTheDarkGlassColumn(screen: ReviewGalleryScreen) async throws {
      let column = try #require(screen.glassColumn)
      let image = try await screen.capture(in: .dark)

      let colors = try #require(try RegionColors(of: image, in: column))

      #expect(colors.background.luminance <= CompositedSnapshotTests.darkLuminance, "\(colors)")
      #expect(colors.contrast >= CompositedSnapshotTests.minimumTextContrast, "\(colors)")
    }
  }

  /// Pins the place of the review gallery page that the user opens (EditorKit
  /// `style.md`, "Review gallery"). It captures nothing, so it holds no lock.
  @Suite struct ReviewGalleryPathTests {
    /// The page, relative to the home folder of the user.
    static let pagePath = "Library/Caches/AgentViewKit/screenshot-check/index.html"

    @Test func thePageIsScreenshotCheckIndexInTheCachesFolderOfThePackage() {
      let expected = FileManager.default.homeDirectoryForCurrentUser.appending(path: Self.pagePath)

      #expect(
        ReviewGalleryScreenTests.gallery.pageURL.path(percentEncoded: false) == expected.path(percentEncoded: false))
    }
  }
#endif
