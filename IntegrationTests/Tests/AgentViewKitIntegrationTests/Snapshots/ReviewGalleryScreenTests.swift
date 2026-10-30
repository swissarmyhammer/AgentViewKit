#if DEBUG
  import EditorTestSupport
  import Foundation
  import Testing

  /// The review gallery of the package (^8q34yt8, ^wprq982), written with
  /// EditorKit's `ReviewGallery` helper (EditorKit `style.md`, "Review
  /// gallery").
  ///
  /// The test records each ``ReviewGalleryScreen`` in a real window on the
  /// screen in Light and in Dark, shows every image that the snapshot suites generated in
  /// ``snapshotRoot``, and writes the page `index.html` with both into
  /// ``gallery``. Each run of `swift test --package-path IntegrationTests`
  /// writes the folder again. Open the page to review the screens. The test
  /// records each screen one time, in both looks, and the checks of a look
  /// read the images of that one recording.
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

    /// The folder of the images that the snapshot suites generated.
    static let snapshotRoot = GeneratedImages.root

    @Test func thePageShowsEachKeyScreenAndEachGeneratedSnapshot() async throws {
      try await GeneratedImages.generateAll()
      let report = try await ReviewGalleryScreen.withReviewScreens(ReviewGalleryScreen.allCases[...]) { screens in
        try await Self.gallery.record(screens, snapshotRoots: [Self.snapshotRoot])
      }

      expectReviewGalleryComplete(report)
      for screen in ReviewGalleryScreen.allCases where screen.glassColumn != nil {
        try Self.expectLightTextOnTheDarkGlassColumn(of: screen)
      }
    }

    /// Expects that the dark image of `screen` on the page shows light text
    /// on its dark glass column. The check reads the image that the page test
    /// recorded, so the screen is not mounted and captured again for it.
    ///
    /// - Parameter screen: A screen with a ``ReviewGalleryScreen/glassColumn``.
    /// - Throws: The error of the read of the image.
    static func expectLightTextOnTheDarkGlassColumn(of screen: ReviewGalleryScreen) throws {
      let column = try #require(screen.glassColumn)
      let image = try screen.recordedImage(in: .dark, of: gallery)

      let colors = try #require(try RegionColors(of: image, in: column), "\(screen)")

      #expect(colors.background.luminance <= CompositedSnapshotTests.darkLuminance, "\(screen): \(colors)")
      #expect(colors.contrast >= CompositedSnapshotTests.minimumTextContrast, "\(screen): \(colors)")
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
