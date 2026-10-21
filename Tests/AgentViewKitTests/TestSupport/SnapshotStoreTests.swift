import AgentViewKitTestSupport
import Foundation
import PackageFileSupport
import SwiftUI
import Testing

/// Tests for ``SnapshotStore``: the reference images, the record mode, and
/// the actual and difference images of a view that changed (AVK-13).
@Suite @MainActor struct SnapshotStoreTests {
  /// The name of the image that the tests store.
  static let name = "halves-light"

  /// A store in two new folders of `directory`.
  ///
  /// - Parameters:
  ///   - directory: The temporary directory of the test.
  ///   - isRecording: Whether the store writes reference images.
  /// - Returns: The store.
  static func store(in directory: TemporaryDirectory, isRecording: Bool = false) -> SnapshotStore {
    SnapshotStore(
      referenceDirectory: directory.url.appending(path: "references"),
      outputDirectory: directory.url.appending(path: "output"),
      isRecording: isRecording)
  }

  /// Whether a file is at `url`.
  ///
  /// - Parameter url: The file URL.
  /// - Returns: `true` when the file exists.
  static func exists(_ url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
  }

  /// The pixels of the PNG file at `url`, at the scale of a render.
  ///
  /// - Parameter url: The file URL.
  /// - Returns: The pixels.
  /// - Throws: An error when the file cannot be read, or an issue when it is
  ///   not a PNG image.
  static func pixels(at url: URL) throws -> RenderedPixels {
    try #require(RenderedPixels(pngData: Data(contentsOf: url), scale: RenderedPixels.renderScale))
  }

  @Test func theRecordModeWritesTheReferenceImage() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let store = Self.store(in: directory, isRecording: true)
    let halves = try RenderedPixelsPNGTests.halves()

    let outcome = try store.compare(halves, named: Self.name)

    #expect(outcome == .recorded)
    #expect(try Self.pixels(at: store.referenceURL(named: Self.name)).isClose(to: halves))
  }

  @Test func aViewWithNoReferenceImageWritesTheActualImage() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let store = Self.store(in: directory)

    let outcome = try store.compare(RenderedPixelsPNGTests.halves(), named: Self.name)

    #expect(outcome == .missingReference)
    #expect(Self.exists(store.actualURL(named: Self.name)))
  }

  @Test func aViewThatLooksAsItsReferenceMatches() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    _ = try Self.store(in: directory, isRecording: true).compare(RenderedPixelsPNGTests.halves(), named: Self.name)
    let store = Self.store(in: directory)

    let outcome = try store.compare(RenderedPixelsPNGTests.halves(), named: Self.name)

    #expect(outcome == .matched)
    #expect(!Self.exists(store.actualURL(named: Self.name)))
  }

  @Test func aViewThatChangedWritesTheActualAndTheDifferenceImages() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    _ = try Self.store(in: directory, isRecording: true).compare(RenderedPixelsPNGTests.halves(), named: Self.name)
    let store = Self.store(in: directory)

    let outcome = try store.compare(RenderedPixelsPNGTests.filled(), named: Self.name)

    #expect(outcome == .changed(hasDifferenceImage: true))
    #expect(try Self.pixels(at: store.actualURL(named: Self.name)).isClose(to: RenderedPixelsPNGTests.filled()))
    #expect(
      try Self.pixels(at: store.differenceURL(named: Self.name)).marksAChange(at: RenderedPixelsTests.trailingPoint))
  }

  @Test func aViewOfANewSizeWritesTheActualImageWithNoDifferenceImage() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    _ = try Self.store(in: directory, isRecording: true).compare(RenderedPixelsPNGTests.halves(), named: Self.name)
    let store = Self.store(in: directory)
    let smaller = try #require(
      RenderedPixels(rendering: RenderedPixelsTests.drawn, size: RenderedPixelsTests.leadingHalf.size))

    let outcome = try store.compare(smaller, named: Self.name)

    #expect(outcome == .changed(hasDifferenceImage: false))
    #expect(Self.exists(store.actualURL(named: Self.name)))
    #expect(!Self.exists(store.differenceURL(named: Self.name)))
  }

  @Test func aMatchRemovesTheImagesOfAnEarlierChange() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    _ = try Self.store(in: directory, isRecording: true).compare(RenderedPixelsPNGTests.halves(), named: Self.name)
    let store = Self.store(in: directory)
    _ = try store.compare(RenderedPixelsPNGTests.filled(), named: Self.name)

    _ = try store.compare(RenderedPixelsPNGTests.halves(), named: Self.name)

    #expect(!Self.exists(store.actualURL(named: Self.name)))
    #expect(!Self.exists(store.differenceURL(named: Self.name)))
  }

  /// The size of the renders of the tests of the glass rim share. Its
  /// 80,000 pixels let the share allow 80 changed pixels.
  static let rimTestSize = CGSize(width: 200, height: 100)

  /// The side of a square that is 16 pixels at the scale of a render.
  static let smallSquareSide: CGFloat = 2

  /// The pixels of ``RenderedPixelsTests/drawn`` that fills the view, with a
  /// square of ``RenderedPixelsTests/notDrawn`` of `side` points in its top
  /// leading corner.
  ///
  /// - Parameter side: The side of the square, in points.
  /// - Returns: The pixels.
  /// - Throws: An issue when the renderer gives no pixels.
  static func filled(withSquareOf side: CGFloat) throws -> RenderedPixels {
    let view = ZStack(alignment: .topLeading) {
      RenderedPixelsTests.drawn
      RenderedPixelsTests.notDrawn.frame(width: side, height: side)
    }
    return try #require(RenderedPixels(rendering: view, size: rimTestSize))
  }

  /// A store in two new folders of `directory`, which allows the share of
  /// changed pixels of a glass rim.
  ///
  /// - Parameter directory: The temporary directory of the test.
  /// - Returns: The store.
  static func glassStore(in directory: TemporaryDirectory) -> SnapshotStore {
    SnapshotStore(
      referenceDirectory: directory.url.appending(path: "references"),
      outputDirectory: directory.url.appending(path: "output"), isRecording: false,
      changedPixelShare: RenderedPixels.glassRimShare)
  }

  @Test func aStoreWithTheGlassRimShareMatchesAChangeOfFewPixels() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    _ = try Self.store(in: directory, isRecording: true).compare(Self.filled(withSquareOf: 0), named: Self.name)

    let outcome = try Self.glassStore(in: directory).compare(Self.filled(withSquareOf: Self.smallSquareSide), named: Self.name)

    #expect(outcome == .matched)
  }

  @Test func aStoreWithTheGlassRimShareFindsALargeChange() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    _ = try Self.store(in: directory, isRecording: true).compare(Self.filled(withSquareOf: 0), named: Self.name)
    let large = try Self.filled(withSquareOf: Self.rimTestSize.height)

    #expect(try Self.glassStore(in: directory).compare(large, named: Self.name) == .changed(hasDifferenceImage: true))
  }

  @Test func aStoreWithNoChangedPixelShareFindsAChangeOfFewPixels() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    _ = try Self.store(in: directory, isRecording: true).compare(Self.filled(withSquareOf: 0), named: Self.name)

    let outcome = try Self.store(in: directory).compare(Self.filled(withSquareOf: Self.smallSquareSide), named: Self.name)

    #expect(outcome == .changed(hasDifferenceImage: true))
  }

  @Test func theCheckOfAViewThatChangedRecordsAnIssue() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    _ = try Self.store(in: directory, isRecording: true).compare(RenderedPixelsPNGTests.halves(), named: Self.name)
    let changed = try RenderedPixelsPNGTests.filled()

    withKnownIssue {
      try Self.store(in: directory).verify(changed, named: Self.name)
    }
  }

  @Test func theCheckOfAViewThatLooksAsItsReferenceRecordsNoIssue() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    _ = try Self.store(in: directory, isRecording: true).compare(RenderedPixelsPNGTests.halves(), named: Self.name)

    try Self.store(in: directory).verify(RenderedPixelsPNGTests.halves(), named: Self.name)
  }

  @Test(arguments: [
    ([SnapshotStore.recordVariable: "1"], true),
    ([SnapshotStore.recordVariable: "0"], false),
    ([:], false),
  ])
  func theRecordVariableSetsTheRecordMode(environment: [String: String], isRecording: Bool) {
    #expect(SnapshotStore.isRecording(in: environment) == isRecording)
  }

  @Test func theReferenceImagesAreNextToTheTestFile() throws {
    let store = try SnapshotStore(suite: "SomeSuite", environment: [:])

    let testDirectory = URL(filePath: #filePath).deletingLastPathComponent()
    #expect(store.referenceDirectory.standardizedFileURL == testDirectory.appending(path: "__Snapshots__/SomeSuite").standardizedFileURL)
  }

  @Test func theOutputImagesAreInTheBuildFolderOfThePackage() throws {
    let store = try SnapshotStore(suite: "SomeSuite", environment: [:])

    #expect(store.outputDirectory.standardizedFileURL == PackageFiles.root.appending(path: ".build/snapshots/SomeSuite").standardizedFileURL)
  }
}
