import Foundation
import PackageFileSupport
import Testing

/// The benchmark target compiles some sources of the main package through
/// symbolic links (plan.md §8). A file that moves leaves a link that points
/// at nothing, and then the `Benchmarks/` package does not build. The
/// benchmark tool hides that error, so this test finds it in `swift test`.
struct BenchmarkSymlinkTests {
  /// The directory of the benchmark target, relative to the package root.
  static let benchmarkSources = "Benchmarks/Benchmarks/AgentViewKitBenchmarks"

  /// The links of the benchmark target, as (link, target) pairs.
  ///
  /// - Returns: The pairs. The target is the path that the link holds,
  ///   resolved against the directory of the link.
  static func links() throws -> [(link: URL, target: URL)] {
    let directory = PackageFiles.root.appending(path: benchmarkSources)
    let entries = try FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: [.isSymbolicLinkKey])
    return try entries.compactMap { entry in
      guard try entry.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true else {
        return nil
      }
      let destination = try FileManager.default.destinationOfSymbolicLink(atPath: entry.path())
      let target = directory.appending(path: destination, directoryHint: .notDirectory)
        .standardizedFileURL
      return (link: entry, target: target)
    }
  }

  @Test func theBenchmarkTargetHasLinks() throws {
    #expect(!(try Self.links()).isEmpty)
  }

  @Test func eachLinkOfTheBenchmarkTargetPointsAtAFile() throws {
    for (link, target) in try Self.links() {
      #expect(
        FileManager.default.fileExists(atPath: target.path()),
        "\(link.lastPathComponent) points at \(target.path()), which does not exist")
    }
  }
}
