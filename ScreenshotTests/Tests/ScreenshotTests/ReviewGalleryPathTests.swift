#if DEBUG
  import EditorTestSupport
  import Foundation
  import Testing

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
