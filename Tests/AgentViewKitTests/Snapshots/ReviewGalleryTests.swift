import AgentViewKitTestSupport
import Foundation
import SwiftUI
import Testing

/// Tests for ``ReviewGallery``: the names of its images, the checks of a
/// render, the contact sheet, and the removal of the images of an earlier
/// run. Each test uses its own temporary folder.
@Suite @MainActor struct ReviewGalleryTests {
  /// The size of each test image, in points.
  static let imageSize = CGSize(width: 40, height: 20)

  /// The name of the screen of the test images.
  static let screen = "thread"

  /// Pixels with two colors: a red half and a blue half.
  static var twoColorPixels: RenderedPixels? {
    RenderedPixels(rendering: HStack(spacing: 0) { Color.red; Color.blue }, size: imageSize)
  }

  /// Pixels with one color only, as a render that drew nothing.
  static var oneColorPixels: RenderedPixels? {
    RenderedPixels(rendering: Color.red, size: imageSize)
  }

  /// The two rows of the contact sheet tests, in order.
  static let rows = [
    ReviewGalleryRow(screen: "thread", title: "Thread", note: "The rows have no fill."),
    ReviewGalleryRow(screen: "gallery", title: "Gallery", note: "The sidebar has no fill."),
  ]

  /// Runs `body` with a gallery in a new temporary folder, and removes the
  /// folder at the end.
  ///
  /// - Parameter body: The test, with the gallery and its folder.
  /// - Throws: The error of the folder or of `body`.
  static func withGallery(_ body: (ReviewGallery, TemporaryDirectory) throws -> Void) throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    try body(ReviewGallery(directory: directory.url), directory)
  }

  @Test func theGalleryShowsTheLightAndTheDarkVariantsOnly() {
    #expect(ReviewGallery.variants == [.light, .dark])
  }

  @Test func theDefaultFolderIsTheScreenshotCheckFolderOfTheCaches() throws {
    let caches = try #require(FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first)

    #expect(
      ReviewGallery.defaultDirectory.standardizedFileURL
        == caches.appending(path: "AgentViewKit/screenshot-check", directoryHint: .isDirectory).standardizedFileURL)
  }

  @Test func anImageIsNamedByItsScreenAndItsVariant() throws {
    try Self.withGallery { gallery, directory in
      let url = try gallery.write(Self.twoColorPixels, screen: Self.screen, variant: .dark)

      #expect(url == directory.url.appending(path: "thread--dark.png"))
      let data = try Data(contentsOf: url)
      #expect(RenderedPixels(pngData: data, scale: RenderedPixels.renderScale) != nil)
    }
  }

  @Test func aRenderWithNoPixelsIsAnError() throws {
    try Self.withGallery { gallery, _ in
      #expect(throws: ReviewGalleryError.noPixels(name: "thread--light")) {
        try gallery.write(nil, screen: Self.screen, variant: .light)
      }
    }
  }

  @Test func aRenderOfOneColorIsAnEmptyImage() throws {
    try Self.withGallery { gallery, directory in
      #expect(throws: ReviewGalleryError.emptyImage(name: "thread--light")) {
        try gallery.write(Self.oneColorPixels, screen: Self.screen, variant: .light)
      }
      #expect(!FileManager.default.fileExists(atPath: directory.url.appending(path: "thread--light.png").path))
    }
  }

  @Test func theContactSheetHasARowForEachScreenAndACellForEachVariant() throws {
    try Self.withGallery { gallery, _ in
      for row in Self.rows {
        for variant in ReviewGallery.variants {
          try gallery.write(Self.twoColorPixels, screen: row.screen, variant: variant)
        }
      }

      let html = try String(contentsOf: gallery.writeContactSheet(Self.rows), encoding: .utf8)

      let cells = ["thread--light.png", "thread--dark.png", "gallery--light.png", "gallery--dark.png"]
      let positions = try cells.map { name in
        try #require(html.range(of: #"<a href="\#(name)"><img src="\#(name)""#)?.lowerBound)
      }
      #expect(positions == positions.sorted())
      #expect(html.contains("Thread — light"))
      #expect(html.contains("Gallery — dark"))
      #expect(html.contains("The sidebar has no fill."))
    }
  }

  @Test func theContactSheetMarksAMissingImage() throws {
    try Self.withGallery { gallery, _ in
      try gallery.write(Self.twoColorPixels, screen: Self.screen, variant: .light)

      let html = try String(contentsOf: gallery.writeContactSheet([Self.rows[0]]), encoding: .utf8)

      #expect(html.contains("No image: thread--dark.png"))
      #expect(!html.contains(#"src="thread--dark.png""#))
    }
  }

  @Test func theContactSheetEscapesItsText() throws {
    try Self.withGallery { gallery, _ in
      let row = ReviewGalleryRow(screen: Self.screen, title: "A <b> & \"c\"", note: "x < y")

      let html = try String(contentsOf: gallery.writeContactSheet([row]), encoding: .utf8)

      #expect(html.contains("A &lt;b&gt; &amp; &quot;c&quot;"))
      #expect(html.contains("x &lt; y"))
      #expect(!html.contains("<b>"))
    }
  }

  @Test func theRemovalOfAnEarlierRunKeepsOtherFiles() throws {
    try Self.withGallery { gallery, directory in
      let kept = try directory.file(named: "notes.txt", contents: Data())
      try gallery.write(Self.twoColorPixels, screen: Self.screen, variant: .light)
      try gallery.writeContactSheet(Self.rows)

      try gallery.removeEarlierRun()

      let names = try FileManager.default.contentsOfDirectory(atPath: directory.url.path)
      #expect(names == [kept.lastPathComponent])
    }
  }

  @Test func theRemovalOfAnEarlierRunAcceptsAMissingFolder() throws {
    try Self.withGallery { _, directory in
      let gallery = ReviewGallery(directory: directory.url.appending(path: "missing"))

      try gallery.removeEarlierRun()
    }
  }
}
