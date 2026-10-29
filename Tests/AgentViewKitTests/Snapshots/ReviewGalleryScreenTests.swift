#if DEBUG
  import AgentViewKitTestSupport
  import Foundation
  import Testing

  /// The review gallery of the full screens of the kit (^8q34yt8).
  ///
  /// The test captures each ``ReviewGalleryScreen`` in a real window on the
  /// screen in each look of ``ReviewGallery/looks`` (Light and Dark), writes
  /// the images to ``ReviewGallery/defaultDirectory``, and writes the contact
  /// sheet `index.html` next to them. Each run of `swift test` writes the
  /// folder again. Open `index.html` to review the screens.
  ///
  /// The gallery compares no image with a reference image, so a changed
  /// screen does not fail the test. The test fails when a screen cannot be
  /// built, when a capture fails or holds one color only, or when a file
  /// cannot be written. To make a screen a snapshot test later, give its
  /// capture to EditorKit `SnapshotStore.verify(_:named:in:sourceLocation:)`
  /// in place of `ReviewGallery.write(_:screen:look:)`.
  @Suite(.serialized, .hostedSerially) @MainActor struct ReviewGalleryScreenTests {
    @Test func eachScreenIsWrittenInEachLookWithTheContactSheet() async throws {
      let gallery = ReviewGallery()
      try gallery.removeEarlierRun()

      for screen in ReviewGalleryScreen.allCases {
        for look in ReviewGallery.looks {
          try gallery.write(try await screen.capture(in: look), screen: screen.rawValue, look: look)
        }
      }
      let sheet = try gallery.writeContactSheet(ReviewGalleryScreen.allCases.map(\.row))

      let html = try String(contentsOf: sheet, encoding: .utf8)
      #expect(!html.contains("No image:"))
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
#endif
