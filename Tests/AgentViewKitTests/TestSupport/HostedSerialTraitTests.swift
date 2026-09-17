import Foundation
import Testing

/// Tests for ``HostedTestLock`` and ``HostedSerialTrait``.
@Suite struct HostedSerialTraitTests {
  /// The text that shows that a test file mounts a view in a window.
  static let hostingMarkers = ["HostedViewHarness(", "threadViewHarness(", "NSWindow("]

  /// The text that shows that a test file declares a test.
  static let testMarker = "@Test"

  /// The name of the trait that each hosted suite must have.
  static let traitMarker = ".hostedSerially"

  /// The folder of the test files of this target.
  static var testsFolder: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }

  /// The number of bodies that run at the same time in the lock test.
  static let concurrentBodies = 8

  /// The largest number of lock bodies that ran at the same time.
  actor OverlapCounter {
    private var running = 0
    private(set) var largest = 0

    func enter() {
      running += 1
      largest = max(largest, running)
    }

    func leave() {
      running -= 1
    }
  }

  /// The error that a lock body throws.
  struct BodyError: Error {}

  @Test func theLockRunsOneBodyAtATime() async throws {
    let lock = HostedTestLock()
    let counter = OverlapCounter()

    try await withThrowingTaskGroup(of: Void.self) { group in
      for _ in 0..<Self.concurrentBodies {
        group.addTask {
          try await lock.run {
            await counter.enter()
            await Task.yield()
            await counter.leave()
          }
        }
      }
      try await group.waitForAll()
    }

    #expect(await counter.largest == 1)
  }

  @Test func aThrowingBodyReleasesTheLock() async throws {
    let lock = HostedTestLock()
    let counter = OverlapCounter()

    await #expect(throws: BodyError.self) {
      try await lock.run { throw BodyError() }
    }
    try await lock.run { await counter.enter() }

    #expect(await counter.largest == 1)
  }

  @Test func eachHostedTestFileHasTheSerialTrait() throws {
    let files = try Self.swiftFiles(in: Self.testsFolder)
    try #require(!files.isEmpty)

    var missing: [String] = []
    for file in files {
      let text = try String(contentsOf: file, encoding: .utf8)
      let isHosted = Self.hostingMarkers.contains { text.contains($0) }
      guard text.contains(Self.testMarker), isHosted, !text.contains(Self.traitMarker) else {
        continue
      }
      missing.append(file.lastPathComponent)
    }

    #expect(missing.isEmpty, "These hosted test files need \(Self.traitMarker): \(missing)")
  }

  /// The Swift files under `folder`, other than this file.
  ///
  /// - Parameter folder: The folder to read.
  /// - Returns: The file URLs.
  /// - Throws: An error when the folder cannot be read.
  static func swiftFiles(in folder: URL) throws -> [URL] {
    let thisFile = URL(fileURLWithPath: #filePath).standardizedFileURL
    guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)
    else {
      throw CocoaError(.fileReadNoSuchFile)
    }
    return enumerator.compactMap { $0 as? URL }
      .filter { $0.pathExtension == "swift" && $0.standardizedFileURL != thisFile }
  }
}
