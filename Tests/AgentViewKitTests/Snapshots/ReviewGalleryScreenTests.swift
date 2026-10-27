#if DEBUG
  import AgentViewKitTestSupport
  import Foundation
  import Testing

  /// The review gallery of the full screens of the kit (^8q34yt8).
  ///
  /// The test renders each ``ReviewGalleryScreen`` in each variant of
  /// ``ReviewGallery/variants`` (light and dark), writes the images to
  /// ``ReviewGallery/defaultDirectory``, and writes the contact sheet
  /// `index.html` next to them. Each run of `swift test` writes the folder
  /// again. Open `index.html` to review the screens.
  ///
  /// The gallery compares no image with a reference image, so a changed
  /// screen does not fail the test. The test fails when a screen cannot be
  /// built, when a render gives no image or an image of one color, or when a
  /// file cannot be written. To make a screen a snapshot test later, give its
  /// pixels to `SnapshotStore.verify(_:named:sourceLocation:)` in place of
  /// `ReviewGallery.write(_:screen:variant:)`.
  @Suite(.serialized, .hostedSerially) @MainActor struct ReviewGalleryScreenTests {
    @Test func eachScreenIsWrittenInEachVariantWithTheContactSheet() async throws {
      let gallery = ReviewGallery()
      try gallery.removeEarlierRun()

      for screen in ReviewGalleryScreen.allCases {
        for variant in ReviewGallery.variants {
          try gallery.write(try await screen.pixels(in: variant), screen: screen.rawValue, variant: variant)
        }
      }
      let sheet = try gallery.writeContactSheet(ReviewGalleryScreen.allCases.map(\.row))

      let html = try String(contentsOf: sheet, encoding: .utf8)
      #expect(!html.contains("No image:"))
    }

    @Test(arguments: [ReviewGalleryScreen.gallery, .inspector])
    func theDarkImageShowsLightTextOnTheDarkGlassColumn(screen: ReviewGalleryScreen) async throws {
      let column = try #require(screen.glassColumn)
      let pixels = try #require(try await screen.pixels(in: .dark))

      let colors = try #require(RegionColors(of: pixels, in: column))

      #expect(colors.background.luminance <= CompositedSnapshotTests.darkLuminance, "\(colors)")
      #expect(colors.contrast >= CompositedSnapshotTests.minimumTextContrast, "\(colors)")
    }
  }
#endif
