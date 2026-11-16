import CoreServices
import Foundation
import os

/// The live folder data of the status line: the git state and the files of
/// the working folder of the session (D194 (j)).
///
/// The model reads the data off the main actor through a
/// ``StatusLineGitProbing``. It reads again when the files or the git state
/// of the folder change (FSEvents, with a delay of
/// ``StatusLineFolderWatcher/latency`` that joins a burst of changes into
/// one read), and when the view asks, such as at the end of each turn.
@MainActor @Observable public final class StatusLineModel {
  /// The folder that the model follows, or `nil`.
  public private(set) var folder: String?

  /// The git state of the folder, or `nil` outside a repository or before
  /// the first read.
  public private(set) var git: StatusLineGitSnapshot?

  /// The files of the folder, relative to it, or `nil` before the first
  /// read.
  public private(set) var files: [String]?

  /// The source of the git state and the files of a repository.
  @ObservationIgnored let probe: any StatusLineGitProbing

  /// The walk of a folder outside a repository.
  @ObservationIgnored let walk: @Sendable (String) -> [String]

  /// `true` to watch the folder with FSEvents. Tests read with
  /// ``refresh()`` only.
  @ObservationIgnored let watchesFolder: Bool

  @ObservationIgnored private var ignoreSubmodules = false
  @ObservationIgnored private var watcher: StatusLineFolderWatcher?
  @ObservationIgnored private var readCount = 0

  /// Makes a model.
  ///
  /// - Parameters:
  ///   - probe: The source of the git state, libgit2 by default.
  ///   - walk: The walk of a folder outside a repository.
  ///   - watchesFolder: `true` to watch the folder with FSEvents.
  public init(
    probe: any StatusLineGitProbing = LibGit2StatusLineProbe(),
    walk: @escaping @Sendable (String) -> [String] = { StatusLineFolderWalk.files(in: $0) },
    watchesFolder: Bool = true
  ) {
    self.probe = probe
    self.walk = walk
    self.watchesFolder = watchesFolder
  }

  /// Makes a model with fixed data, for a preview or a gallery image: each
  /// read gives the same data, and the model watches no folder.
  ///
  /// - Parameters:
  ///   - folder: The folder.
  ///   - git: The git state, or `nil` outside a repository.
  ///   - files: The files of the folder.
  public convenience init(fixedFolder folder: String, git: StatusLineGitSnapshot?, files: [String]) {
    self.init(probe: FixedStatusLineProbe(snapshot: git, files: git == nil ? nil : files), walk: { _ in files },
      watchesFolder: false)
    self.folder = folder
    self.git = git
    self.files = files
  }

  /// Follows a folder: reads its data, and watches it for changes.
  ///
  /// - Parameters:
  ///   - folder: The folder, or `nil` to follow no folder.
  ///   - ignoreSubmodules: `true` to leave submodule changes out of the git
  ///     counts.
  public func follow(_ folder: String?, ignoreSubmodules: Bool) async {
    let changed = folder != self.folder || ignoreSubmodules != self.ignoreSubmodules
    guard changed || git == nil && files == nil else { return }
    self.folder = folder
    self.ignoreSubmodules = ignoreSubmodules
    if changed {
      git = nil
      files = nil
      watcher = nil
    }
    await refresh()
  }

  /// Reads the data of the folder again. A read that a newer read or a new
  /// folder replaces changes nothing.
  public func refresh() async {
    readCount += 1
    let read = readCount
    guard let folder else {
      git = nil
      files = nil
      return
    }
    let probe = probe
    let walk = walk
    let ignoreSubmodules = ignoreSubmodules
    let snapshot = await probe.snapshot(of: folder, ignoreSubmodules: ignoreSubmodules)
    let repositoryFiles = await probe.files(in: folder)
    let files: [String]
    if let repositoryFiles {
      files = repositoryFiles
    } else {
      files = await Self.walk(folder, with: walk)
    }
    guard read == readCount, folder == self.folder else { return }
    if snapshot != git { git = snapshot }
    if files != self.files { self.files = files }
    if watchesFolder, watcher == nil || watcher?.paths != Self.watchedPaths(folder: folder, git: snapshot) {
      watcher = StatusLineFolderWatcher(paths: Self.watchedPaths(folder: folder, git: snapshot)) { [weak self] in
        Task { await self?.refresh() }
      }
    }
  }

  /// The paths that the watcher follows: the folder, and the git folder of
  /// a repository root above it.
  static func watchedPaths(folder: String, git: StatusLineGitSnapshot?) -> [String] {
    guard let root = git?.root, root != folder, !folder.hasPrefix(root + "/.git") else { return [folder] }
    return [folder, root + "/.git"]
  }

  @concurrent private static func walk(_ folder: String, with walk: @Sendable (String) -> [String]) async -> [String] {
    walk(folder)
  }
}

/// A probe that gives fixed data, for a preview or a gallery image.
nonisolated struct FixedStatusLineProbe: StatusLineGitProbing {
  let snapshot: StatusLineGitSnapshot?
  let files: [String]?

  func snapshot(of folder: String, ignoreSubmodules: Bool) async -> StatusLineGitSnapshot? { snapshot }

  func files(in folder: String) async -> [String]? { files }
}

/// An FSEvents stream on some folders. The stream calls its action on the
/// main queue, at most one time for each ``latency``.
final class StatusLineFolderWatcher {
  /// The delay that joins a burst of changes into one call, in seconds.
  static let latency: CFTimeInterval = 0.5

  /// The watched paths.
  let paths: [String]

  private let action: @MainActor () -> Void
  private var stream: FSEventStreamRef?

  private static let logger = Logger(subsystem: "AgentViewKit", category: "StatusLine")

  init(paths: [String], action: @escaping @MainActor () -> Void) {
    self.paths = paths
    self.action = action
    var context = FSEventStreamContext(
      version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
    let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
      guard let info else { return }
      let watcher = Unmanaged<StatusLineFolderWatcher>.fromOpaque(info).takeUnretainedValue()
      MainActor.assumeIsolated { watcher.action() }
    }
    guard
      let stream = FSEventStreamCreate(
        nil, callback, &context, paths as CFArray, FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
        Self.latency, FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents))
    else {
      Self.logger.error("The status line cannot watch the folder for changes.")
      return
    }
    FSEventStreamSetDispatchQueue(stream, .main)
    FSEventStreamStart(stream)
    self.stream = stream
  }

  isolated deinit {
    guard let stream else { return }
    FSEventStreamStop(stream)
    FSEventStreamInvalidate(stream)
    FSEventStreamRelease(stream)
  }
}
