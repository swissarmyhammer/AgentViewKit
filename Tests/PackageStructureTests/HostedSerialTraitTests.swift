import EditorTestSupport
import Foundation
import Testing

/// Tests that each hosted test file runs under the `.hostedSerially` trait of
/// EditorKit `EditorTestSupport`, which holds the shared UI test lock of the
/// Mac (`~/Library/Caches/swissarmyhammer/ui-tests.lock`) for each of its
/// tests.
///
/// A file that mounts a view in a window, or that captures a real window from
/// the window server, holds the lock, so no two hosted tests, captures or UI
/// test runs of this Mac take the key window at once.
@Suite struct HostedSerialTraitTests {
  /// The text that shows that a test file mounts a view in a window, or
  /// captures a real window.
  static let hostingMarkers = ["HostedViewHarness(", "NSWindow(", "CaptureWindow(", "CapturedImage("]

  /// The text that shows that a test file declares a test.
  static let testMarker = "@Test"

  /// The name of the trait that each hosted suite must have.
  static let traitMarker = ".hostedSerially"

  /// The folder of the test targets that mount views, relative to the
  /// package root: the nested integration package (plan.md §11 decision 21).
  /// No root test mounts a view (`RootTestsHostNoViewTests`).
  static let testsFolders = [IntegrationPackage.testsPath]

  /// This file. It holds the markers as text, so the scan skips it.
  static var thisFile: URL { URL(filePath: #filePath).standardizedFileURL }

  @Test func eachHostedTestFileHasTheSerialTrait() throws {
    let files = try Self.testsFolders
      .flatMap { try swiftFiles(under: PackageFiles().file($0)) }
      .filter { $0.standardizedFileURL != Self.thisFile }
    try #require(!files.isEmpty)

    let missing = try files.compactMap { file -> String? in
      let text = try String(contentsOf: file, encoding: .utf8)
      let isHosted = Self.hostingMarkers.contains { text.contains($0) }
      guard text.contains(Self.testMarker), isHosted, !text.contains(Self.traitMarker) else {
        return nil
      }
      return file.lastPathComponent
    }

    #expect(missing.isEmpty, "These hosted test files need \(Self.traitMarker): \(missing)")
  }
}
