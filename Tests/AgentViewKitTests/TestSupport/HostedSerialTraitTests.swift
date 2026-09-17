import Foundation
import PackageFileSupport
import Testing

/// Tests for ``HostedTestLock`` and ``HostedSerialTrait``.
@Suite struct HostedSerialTraitTests {
  /// The text that shows that a test file mounts a view in a window.
  static let hostingMarkers = ["HostedViewHarness(", "threadViewHarness(", "NSWindow("]

  /// The text that shows that a test file declares a test.
  static let testMarker = "@Test"

  /// The name of the trait that each hosted suite must have.
  static let traitMarker = ".hostedSerially"

  /// The folder of the test files of this target, relative to the package
  /// root.
  static let testsFolder = "Tests/AgentViewKitTests"

  /// This file. It holds the markers as text, so the scan skips it.
  static var thisFile: URL { URL(filePath: #filePath).standardizedFileURL }

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
    let files = try PackageFiles.swiftFiles(in: PackageFiles.file(Self.testsFolder))
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
