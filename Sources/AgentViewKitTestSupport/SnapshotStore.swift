import Foundation
import Testing

/// The result of ``SnapshotStore/compare(_:named:)``.
public enum SnapshotOutcome: Equatable, Sendable {
  /// The image is close to its reference image
  /// (``RenderedPixels/isClose(to:tolerance:)``).
  case matched

  /// The record mode wrote the image as the reference image.
  case recorded

  /// The image has no reference image. The store wrote the actual image.
  case missingReference

  /// The image is not close to its reference image. The store wrote the
  /// actual image, and the difference image when the two images have the
  /// same size.
  case changed(hasDifferenceImage: Bool)
}

/// The errors of ``SnapshotStore``.
public enum SnapshotStoreError: Error, Equatable {
  /// No folder above the test file holds `Package.swift`.
  case noPackageRoot(testFile: String)

  /// Core Graphics or ImageIO did not make a PNG image of the pixels.
  case noImage(name: String)

  /// The reference image is not a PNG image that ImageIO can read.
  case unreadableReference(path: String)
}

/// The reference images of the snapshot tests of one suite, and the folder
/// for the images of a view that changed (AVK-13).
///
/// A snapshot test makes the pixels of a view (``ViewSnapshot``) and gives
/// them to ``verify(_:named:sourceLocation:)``. The store compares the
/// pixels with the reference image `<name>.png` in ``referenceDirectory``,
/// with the tolerance of ``RenderedPixels/isClose(to:tolerance:)``. When the
/// view changed, the store writes `<name>.actual.png` and `<name>.diff.png`
/// to ``outputDirectory``, attaches them to the test, and records an issue.
///
/// The record mode writes the reference images. Set the environment variable
/// ``recordVariable`` to `1` for one run:
///
/// ```bash
/// AVK_SNAPSHOT_RECORD=1 swift test --filter SnapshotTests
/// ```
///
/// In the record mode, each snapshot test records an issue, so that a run
/// with the variable never passes by mistake.
public struct SnapshotStore: Sendable {
  /// The environment variable that turns on the record mode. It is
  /// `nonisolated` because the arguments of a test use it.
  nonisolated public static let recordVariable = "AVK_SNAPSHOT_RECORD"

  /// The value of ``recordVariable`` that turns on the record mode.
  private static let recordValue = "1"

  /// The folder next to the test file that holds the reference images of
  /// each suite.
  private static let referenceFolderName = "__Snapshots__"

  /// The folder, relative to the package root, for the actual and
  /// difference images of each suite.
  private static let outputFolderPath = ".build/snapshots"

  /// The file that marks the root folder of the package.
  private static let manifestName = "Package.swift"

  /// The file extension of each image.
  private static let imageExtension = "png"

  /// The part of the file name of an actual image after the name of the
  /// image.
  private static let actualSuffix = ".actual"

  /// The part of the file name of a difference image after the name of the
  /// image.
  private static let differenceSuffix = ".diff"

  /// The folder of the reference images.
  public let referenceDirectory: URL

  /// The folder of the actual and difference images.
  public let outputDirectory: URL

  /// Whether ``compare(_:named:)`` writes each image as its reference image.
  public let isRecording: Bool

  /// The largest share of the pixels of an image, from 0 to 1, that can be
  /// different from the reference image
  /// (``RenderedPixels/changedPixelCount(comparedWith:tolerance:)``). With
  /// `0`, the image matches only when it is close to the reference image
  /// (``RenderedPixels/isClose(to:tolerance:)``).
  public let changedPixelShare: Double

  /// Makes a store with two folders.
  ///
  /// - Parameters:
  ///   - referenceDirectory: The folder of the reference images.
  ///   - outputDirectory: The folder of the actual and difference images.
  ///   - isRecording: Whether the store writes each image as its reference
  ///     image.
  ///   - changedPixelShare: The largest share of the pixels that can be
  ///     different from the reference image. Use
  ///     ``RenderedPixels/glassRimShare`` for a glass part that
  ///     `ImageRenderer` draws.
  public init(
    referenceDirectory: URL, outputDirectory: URL, isRecording: Bool, changedPixelShare: Double = 0
  ) {
    self.referenceDirectory = referenceDirectory
    self.outputDirectory = outputDirectory
    self.isRecording = isRecording
    self.changedPixelShare = changedPixelShare
  }

  /// Makes the store of the suite `suite`.
  ///
  /// The reference images are in `__Snapshots__/<suite>/`, next to the test
  /// file. The actual and difference images go to
  /// `.build/snapshots/<suite>/` in the package root.
  ///
  /// - Parameters:
  ///   - suite: The name of the suite.
  ///   - changedPixelShare: The largest share of the pixels that can be
  ///     different from the reference image.
  ///   - testFile: The path of the test file. Keep the default value.
  ///   - environment: The environment that can turn on the record mode.
  /// - Throws: ``SnapshotStoreError/noPackageRoot(testFile:)`` when no folder
  ///   above the test file holds `Package.swift`.
  public init(
    suite: String, changedPixelShare: Double = 0, testFile: StaticString = #filePath,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) throws {
    let testFilePath = "\(testFile)"
    let testDirectory = URL(filePath: testFilePath).deletingLastPathComponent()
    guard let root = Self.packageRoot(above: testDirectory) else {
      throw SnapshotStoreError.noPackageRoot(testFile: testFilePath)
    }
    self.init(
      referenceDirectory: testDirectory.appending(path: Self.referenceFolderName).appending(path: suite),
      outputDirectory: root.appending(path: Self.outputFolderPath).appending(path: suite),
      isRecording: Self.isRecording(in: environment), changedPixelShare: changedPixelShare)
  }

  /// Whether `environment` turns on the record mode.
  ///
  /// - Parameter environment: The environment variables.
  /// - Returns: `true` when ``recordVariable`` is `1`.
  public static func isRecording(in environment: [String: String]) -> Bool {
    environment[recordVariable] == recordValue
  }

  /// The URL of the reference image of `name`.
  ///
  /// - Parameter name: The name of the image, such as `thread-dark`.
  /// - Returns: The file URL.
  public func referenceURL(named name: String) -> URL {
    referenceDirectory.appending(path: name).appendingPathExtension(Self.imageExtension)
  }

  /// The URL of the actual image of `name` after a change.
  ///
  /// - Parameter name: The name of the image.
  /// - Returns: The file URL.
  public func actualURL(named name: String) -> URL {
    outputDirectory.appending(path: name + Self.actualSuffix).appendingPathExtension(Self.imageExtension)
  }

  /// The URL of the difference image of `name` after a change.
  ///
  /// - Parameter name: The name of the image.
  /// - Returns: The file URL.
  public func differenceURL(named name: String) -> URL {
    outputDirectory.appending(path: name + Self.differenceSuffix).appendingPathExtension(Self.imageExtension)
  }

  /// Compares `pixels` with the reference image of `name`, and writes the
  /// images that the outcome needs.
  ///
  /// Before the comparison, the store removes the actual and difference
  /// images of an earlier run, so that the output folder shows only the
  /// changes of this run.
  ///
  /// - Parameters:
  ///   - pixels: The pixels of the view.
  ///   - name: The name of the image, such as `thread-dark`.
  /// - Returns: The outcome.
  /// - Throws: A ``SnapshotStoreError``, or the error of a file operation.
  public func compare(_ pixels: RenderedPixels, named name: String) throws -> SnapshotOutcome {
    try removeOutput(named: name)
    if isRecording {
      try Self.write(pixels, named: name, to: referenceURL(named: name))
      return .recorded
    }
    guard let reference = try referencePixels(named: name, scale: pixels.scale) else {
      try Self.write(pixels, named: name, to: actualURL(named: name))
      return .missingReference
    }
    guard !matches(pixels, reference) else { return .matched }
    try Self.write(pixels, named: name, to: actualURL(named: name))
    guard let difference = pixels.difference(from: reference) else {
      return .changed(hasDifferenceImage: false)
    }
    try Self.write(difference, named: name, to: differenceURL(named: name))
    return .changed(hasDifferenceImage: true)
  }

  /// Whether `pixels` match `reference`: the two images have the same size,
  /// and the share of changed pixels is ``changedPixelShare`` or less.
  ///
  /// - Parameters:
  ///   - pixels: The pixels of the view.
  ///   - reference: The pixels of the reference image.
  /// - Returns: `true` when the images match.
  private func matches(_ pixels: RenderedPixels, _ reference: RenderedPixels) -> Bool {
    guard let changed = pixels.changedPixelCount(comparedWith: reference) else { return false }
    return Double(changed) <= Double(pixels.pixelCount) * changedPixelShare
  }

  /// Requires that `pixels` are close to the reference image of `name`.
  ///
  /// When the outcome of ``compare(_:named:)`` is not
  /// ``SnapshotOutcome/matched``, the function attaches the actual and
  /// difference images to the test and records an issue with their paths.
  ///
  /// - Parameters:
  ///   - pixels: The pixels of the view, or `nil` when the render gave none.
  ///   - name: The name of the image, such as `thread-dark`.
  ///   - sourceLocation: The location of the caller, for the issue.
  /// - Throws: An issue when `pixels` is `nil`, a ``SnapshotStoreError``, or
  ///   the error of a file operation.
  public func verify(
    _ pixels: RenderedPixels?, named name: String, sourceLocation: SourceLocation = #_sourceLocation
  ) throws {
    let pixels = try #require(pixels, "The render of \(name) gave no pixels", sourceLocation: sourceLocation)
    let outcome = try compare(pixels, named: name)
    guard let message = message(for: outcome, named: name) else { return }
    attachOutput(named: name, sourceLocation: sourceLocation)
    Issue.record(Comment(rawValue: message), sourceLocation: sourceLocation)
  }

  /// The text of the issue of `outcome`.
  ///
  /// - Parameters:
  ///   - outcome: The outcome of ``compare(_:named:)``.
  ///   - name: The name of the image.
  /// - Returns: The text, or `nil` for ``SnapshotOutcome/matched``.
  private func message(for outcome: SnapshotOutcome, named name: String) -> String? {
    let reference = Self.path(of: referenceURL(named: name))
    let actual = Self.path(of: actualURL(named: name))
    switch outcome {
    case .matched:
      return nil
    case .recorded:
      return "Recorded the reference image \(reference). Run the test again without \(Self.recordVariable)."
    case .missingReference:
      return "No reference image at \(reference). The actual image is at \(actual). "
        + "To record the reference image, run the test with \(Self.recordVariable)=\(Self.recordValue)."
    case .changed(let hasDifferenceImage):
      let difference = hasDifferenceImage ? Self.path(of: differenceURL(named: name)) : "none: the size changed"
      return "The view does not look as its reference image \(reference). "
        + "The actual image: \(actual). The difference image: \(difference)."
    }
  }

  /// Attaches the actual and difference images of `name` that this run
  /// wrote to the current test.
  ///
  /// - Parameters:
  ///   - name: The name of the image.
  ///   - sourceLocation: The location of the caller.
  private func attachOutput(named name: String, sourceLocation: SourceLocation) {
    for url in [actualURL(named: name), differenceURL(named: name)] {
      guard let data = try? Data(contentsOf: url) else { continue }
      Attachment.record(data, named: url.lastPathComponent, sourceLocation: sourceLocation)
    }
  }

  /// The pixels of the reference image of `name`.
  ///
  /// - Parameters:
  ///   - name: The name of the image.
  ///   - scale: The number of pixels in the image for each point.
  /// - Returns: The pixels, or `nil` when the image has no reference image.
  /// - Throws: ``SnapshotStoreError/unreadableReference(path:)`` when the
  ///   reference image is not a PNG image, or the error of the read.
  private func referencePixels(named name: String, scale: CGFloat) throws -> RenderedPixels? {
    let url = referenceURL(named: name)
    guard Self.fileExists(at: url) else { return nil }
    guard let pixels = RenderedPixels(pngData: try Data(contentsOf: url), scale: scale) else {
      throw SnapshotStoreError.unreadableReference(path: Self.path(of: url))
    }
    return pixels
  }

  /// Writes `pixels` to `url` as a PNG image.
  ///
  /// - Parameters:
  ///   - pixels: The pixels to write.
  ///   - name: The name of the image, for the error.
  ///   - url: The file URL.
  /// - Throws: ``SnapshotStoreError/noImage(name:)`` when the pixels give no
  ///   PNG image, or the error of the write.
  private static func write(_ pixels: RenderedPixels, named name: String, to url: URL) throws {
    guard let image = pixels.pngData() else { throw SnapshotStoreError.noImage(name: name) }
    try write(image, to: url)
  }

  /// Removes the actual and difference images of `name`.
  ///
  /// - Parameter name: The name of the image.
  /// - Throws: The error of the removal.
  private func removeOutput(named name: String) throws {
    for url in [actualURL(named: name), differenceURL(named: name)] where Self.fileExists(at: url) {
      try FileManager.default.removeItem(at: url)
    }
  }

  /// Writes `data` to `url`, and makes the folder of `url` first. The write
  /// is atomic. ``ReviewGallery`` writes its files with it too.
  ///
  /// - Parameters:
  ///   - data: The bytes of the file.
  ///   - url: The file URL.
  /// - Throws: The error of the file manager or of the write.
  static func write(_ data: Data, to url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url, options: .atomic)
  }

  /// The nearest folder at or above `directory` that holds `Package.swift`.
  ///
  /// - Parameter directory: The folder to start from.
  /// - Returns: The folder, or `nil` when no folder above holds the file.
  private static func packageRoot(above directory: URL) -> URL? {
    let folders = sequence(first: directory.standardizedFileURL) { folder in
      let parent = folder.deletingLastPathComponent().standardizedFileURL
      return path(of: parent) == path(of: folder) ? nil : parent
    }
    return folders.first { fileExists(at: $0.appending(path: manifestName)) }
  }

  /// Whether a file is at `url`.
  ///
  /// - Parameter url: The file URL.
  /// - Returns: `true` when the file exists.
  private static func fileExists(at url: URL) -> Bool {
    FileManager.default.fileExists(atPath: path(of: url))
  }

  /// The file system path of `url`, for a message and a file check.
  ///
  /// - Parameter url: The file URL.
  /// - Returns: The path, with no percent encoding.
  private static func path(of url: URL) -> String {
    url.path(percentEncoded: false)
  }
}
