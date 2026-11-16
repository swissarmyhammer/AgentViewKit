import Foundation
import libgit2

/// The git state of a folder, for the git modules of the status line
/// (D194 (f)).
nonisolated public struct StatusLineGitSnapshot: Hashable, Sendable {
  /// An operation in progress in the repository.
  public enum State: String, Hashable, Sendable, CaseIterable {
    case rebase, merge, revert, cherryPick, bisect, am, amOrRebase
  }

  /// The progress of a rebase: the step and the count of steps.
  public struct Progress: Hashable, Sendable {
    public var current: Int
    public var total: Int

    public init(current: Int, total: Int) {
      self.current = current
      self.total = total
    }
  }

  /// The counts of the work tree and the index.
  public struct Counts: Hashable, Sendable {
    public var conflicted = 0
    public var staged = 0
    public var modified = 0
    public var untracked = 0
    public var deleted = 0
    public var renamed = 0

    public init(
      conflicted: Int = 0, staged: Int = 0, modified: Int = 0, untracked: Int = 0, deleted: Int = 0, renamed: Int = 0
    ) {
      self.conflicted = conflicted
      self.staged = staged
      self.modified = modified
      self.untracked = untracked
      self.deleted = deleted
      self.renamed = renamed
    }
  }

  /// The folder of the work tree: the repository root.
  public var root: String

  /// The branch, or `nil` when the HEAD is detached.
  public var branch: String?

  /// The short hash of the commit of a detached HEAD, or `nil`.
  public var detachedHash: String?

  /// The counts of the work tree and the index.
  public var counts: Counts

  /// The count of stash entries.
  public var stashed: Int

  /// The commits that the branch has and its upstream does not, or `nil`
  /// with no upstream.
  public var ahead: Int?

  /// The commits that the upstream has and the branch does not, or `nil`
  /// with no upstream.
  public var behind: Int?

  /// The operation in progress, or `nil`.
  public var state: State?

  /// The progress of a rebase, or `nil`.
  public var progress: Progress?

  public init(
    root: String, branch: String? = nil, detachedHash: String? = nil, counts: Counts = Counts(), stashed: Int = 0,
    ahead: Int? = nil, behind: Int? = nil, state: State? = nil, progress: Progress? = nil
  ) {
    self.root = root
    self.branch = branch
    self.detachedHash = detachedHash
    self.counts = counts
    self.stashed = stashed
    self.ahead = ahead
    self.behind = behind
    self.state = state
    self.progress = progress
  }
}

/// A source of the git state of a folder. The status line reads it off the
/// main actor. Tests give a source of their own.
nonisolated public protocol StatusLineGitProbing: Sendable {
  /// The git state of the repository that holds a folder.
  ///
  /// - Parameters:
  ///   - folder: The path of the folder.
  ///   - ignoreSubmodules: `true` to leave submodule changes out of the
  ///     counts.
  /// - Returns: The state, or `nil` when no repository holds the folder.
  func snapshot(of folder: String, ignoreSubmodules: Bool) async -> StatusLineGitSnapshot?

  /// The files of the folder: for a folder in a repository, each file of the
  /// index and each untracked file that the ignore rules do not exclude.
  ///
  /// - Parameter folder: The path of the folder.
  /// - Returns: The paths relative to the folder, or `nil` when no
  ///   repository holds the folder.
  func files(in folder: String) async -> [String]?
}

/// The git state from libgit2 in the process. The status line runs no `git`
/// program (D194 (f)).
nonisolated public struct LibGit2StatusLineProbe: StatusLineGitProbing {
  /// The length of a short commit hash.
  public static let shortHashLength = 7

  /// Starts libgit2 one time for the process.
  private static let libraryStartCount: Int32 = git_libgit2_init()

  public init() {}

  @concurrent public func snapshot(of folder: String, ignoreSubmodules: Bool) async -> StatusLineGitSnapshot? {
    guard
      var snapshot = Self.withRepository(at: folder, { repository in
        Self.snapshot(of: repository, ignoreSubmodules: ignoreSubmodules)
      }) ?? nil
    else { return nil }
    snapshot.root = Self.root(snapshot.root, inSpellingOf: folder)
    return snapshot
  }

  @concurrent public func files(in folder: String) async -> [String]? {
    Self.withRepository(at: folder) { repository -> [String]? in
      guard let root = Self.workTree(of: repository) else { return nil }
      let prefix = Self.relativePrefix(of: folder, in: root)
      let tracked = Self.indexPaths(of: repository)
      let untracked = Self.statusEntries(of: repository, flags: Self.untrackedFlags, show: GIT_STATUS_SHOW_WORKDIR_ONLY) {
        entry -> String? in
        guard entry.status.rawValue & GIT_STATUS_WT_NEW.rawValue != 0,
          let path = entry.index_to_workdir?.pointee.new_file.path
        else { return nil }
        return String(cString: path)
      }
      return (tracked + untracked).compactMap { path in
        guard let prefix else { return path }
        return path.hasPrefix(prefix) ? String(path.dropFirst(prefix.count)) : nil
      }
    } ?? nil
  }

  // MARK: - Repository

  private static func withRepository<T>(at folder: String, _ body: (OpaquePointer) -> T) -> T? {
    guard libraryStartCount > 0 else { return nil }
    var repository: OpaquePointer?
    guard git_repository_open_ext(&repository, folder, 0, nil) == GIT_OK.rawValue, let repository else {
      return nil
    }
    defer { git_repository_free(repository) }
    guard git_repository_is_bare(repository) == 0 else { return nil }
    return body(repository)
  }

  /// The work tree of a repository, with no `/` at the end.
  private static func workTree(of repository: OpaquePointer) -> String? {
    guard let path = git_repository_workdir(repository) else { return nil }
    let text = String(cString: path)
    return text.count > 1 && text.hasSuffix("/") ? String(text.dropLast()) : text
  }

  /// The repository root in the spelling of the folder that the caller
  /// gave. libgit2 resolves symbolic links, such as `/var` to
  /// `/private/var`, and the directory module compares the root with the
  /// folder of the session.
  ///
  /// - Parameters:
  ///   - root: The root from libgit2.
  ///   - folder: The folder of the caller.
  /// - Returns: The root as the start of `folder`, or `root` when the
  ///   spellings do not match.
  static func root(_ root: String, inSpellingOf folder: String) -> String {
    let trimmedFolder = folder.count > 1 && folder.hasSuffix("/") ? String(folder.dropLast()) : folder
    guard let relative = relativePrefix(of: folder, in: root) else {
      return canonical(trimmedFolder) == canonical(root) ? trimmedFolder : root
    }
    let suffix = "/" + relative.dropLast()
    guard trimmedFolder.hasSuffix(suffix) else { return root }
    let candidate = String(trimmedFolder.dropLast(suffix.count))
    return canonical(candidate) == canonical(root) ? candidate : root
  }

  private static func canonical(_ path: String) -> String {
    let text = URL(filePath: path).standardizedFileURL.resolvingSymlinksInPath().path(percentEncoded: false)
    return text.count > 1 && text.hasSuffix("/") ? String(text.dropLast()) : text
  }

  /// The path of `folder` relative to `root` with a `/` at the end, `nil`
  /// when the folder is the root.
  private static func relativePrefix(of folder: String, in root: String) -> String? {
    let folder = URL(filePath: folder).standardizedFileURL.resolvingSymlinksInPath().path(percentEncoded: false)
    let root = URL(filePath: root).standardizedFileURL.resolvingSymlinksInPath().path(percentEncoded: false)
    let trimmedFolder = folder.hasSuffix("/") ? String(folder.dropLast()) : folder
    let trimmedRoot = root.hasSuffix("/") ? String(root.dropLast()) : root
    guard trimmedFolder != trimmedRoot, trimmedFolder.hasPrefix(trimmedRoot + "/") else { return nil }
    return String(trimmedFolder.dropFirst(trimmedRoot.count + 1)) + "/"
  }

  private static func snapshot(of repository: OpaquePointer, ignoreSubmodules: Bool) -> StatusLineGitSnapshot? {
    guard let root = workTree(of: repository) else { return nil }
    var snapshot = StatusLineGitSnapshot(root: root)
    readHead(of: repository, into: &snapshot)
    var flags = statusFlags
    if ignoreSubmodules { flags |= GIT_STATUS_OPT_EXCLUDE_SUBMODULES.rawValue }
    snapshot.counts = counts(
      of: statusEntries(of: repository, flags: flags, show: GIT_STATUS_SHOW_INDEX_AND_WORKDIR) { $0.status })
    snapshot.stashed = stashCount(of: repository)
    let state = state(of: repository)
    snapshot.state = state
    if state == .rebase || state == .amOrRebase || state == .am {
      snapshot.progress = rebaseProgress(of: repository)
    }
    return snapshot
  }

  /// Reads the branch, the detached hash, and ahead and behind.
  private static func readHead(of repository: OpaquePointer, into snapshot: inout StatusLineGitSnapshot) {
    if git_repository_head_unborn(repository) == 1 {
      var head: OpaquePointer?
      if git_reference_lookup(&head, repository, "HEAD") == GIT_OK.rawValue, let head {
        defer { git_reference_free(head) }
        if let target = git_reference_symbolic_target(head) {
          snapshot.branch = shortBranchName(String(cString: target))
        }
      }
      return
    }
    var head: OpaquePointer?
    guard git_repository_head(&head, repository) == GIT_OK.rawValue, let head else { return }
    defer { git_reference_free(head) }
    if git_repository_head_detached(repository) == 1 {
      if let oid = git_reference_target(head), let text = git_oid_tostr_s(oid) {
        snapshot.detachedHash = String(String(cString: text).prefix(shortHashLength))
      }
      return
    }
    if let name = git_reference_shorthand(head) {
      snapshot.branch = String(cString: name)
    }
    var upstream: OpaquePointer?
    guard git_branch_upstream(&upstream, head) == GIT_OK.rawValue, let upstream else { return }
    defer { git_reference_free(upstream) }
    guard let local = git_reference_target(head), let remote = git_reference_target(upstream) else { return }
    var ahead = 0
    var behind = 0
    if git_graph_ahead_behind(&ahead, &behind, repository, local, remote) == GIT_OK.rawValue {
      snapshot.ahead = ahead
      snapshot.behind = behind
    }
  }

  private static func shortBranchName(_ reference: String) -> String {
    let prefix = "refs/heads/"
    return reference.hasPrefix(prefix) ? String(reference.dropFirst(prefix.count)) : reference
  }

  // MARK: - Status

  private static let statusOptionsVersion = UInt32(GIT_STATUS_OPTIONS_VERSION)

  /// The flags of the counts: untracked files, and renames.
  private static let statusFlags =
    GIT_STATUS_OPT_INCLUDE_UNTRACKED.rawValue | GIT_STATUS_OPT_RENAMES_HEAD_TO_INDEX.rawValue

  /// The flags of the file list: untracked files one by one.
  private static let untrackedFlags =
    GIT_STATUS_OPT_INCLUDE_UNTRACKED.rawValue | GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS.rawValue

  /// Reads the status list of a repository. `transform` reads each entry
  /// while the list is alive: an entry points into the list.
  private static func statusEntries<T>(
    of repository: OpaquePointer, flags: UInt32, show: git_status_show_t, _ transform: (git_status_entry) -> T?
  ) -> [T] {
    var options = git_status_options()
    guard git_status_options_init(&options, statusOptionsVersion) == GIT_OK.rawValue else { return [] }
    options.show = show
    options.flags = flags
    var list: OpaquePointer?
    guard git_status_list_new(&list, repository, &options) == GIT_OK.rawValue, let list else { return [] }
    defer { git_status_list_free(list) }
    return (0..<git_status_list_entrycount(list)).compactMap { git_status_byindex(list, $0).flatMap { transform($0.pointee) } }
  }

  /// The counts of the status entries. An entry adds to each count that it
  /// matches, as in starship.
  static func counts(of statuses: [git_status_t]) -> StatusLineGitSnapshot.Counts {
    var counts = StatusLineGitSnapshot.Counts()
    for entry in statuses {
      let status = entry.rawValue
      func has(_ flag: git_status_t) -> Bool { status & flag.rawValue != 0 }
      if has(GIT_STATUS_CONFLICTED) {
        counts.conflicted += 1
        continue
      }
      if has(GIT_STATUS_INDEX_NEW) || has(GIT_STATUS_INDEX_MODIFIED) || has(GIT_STATUS_INDEX_TYPECHANGE) {
        counts.staged += 1
      }
      if has(GIT_STATUS_WT_MODIFIED) || has(GIT_STATUS_WT_TYPECHANGE) { counts.modified += 1 }
      if has(GIT_STATUS_INDEX_DELETED) || has(GIT_STATUS_WT_DELETED) { counts.deleted += 1 }
      if has(GIT_STATUS_INDEX_RENAMED) || has(GIT_STATUS_WT_RENAMED) { counts.renamed += 1 }
      if has(GIT_STATUS_WT_NEW) { counts.untracked += 1 }
    }
    return counts
  }

  private static func indexPaths(of repository: OpaquePointer) -> [String] {
    var index: OpaquePointer?
    guard git_repository_index(&index, repository) == GIT_OK.rawValue, let index else { return [] }
    defer { git_index_free(index) }
    return (0..<git_index_entrycount(index)).compactMap { position in
      git_index_get_byindex(index, position).map { String(cString: $0.pointee.path) }
    }
  }

  private static func stashCount(of repository: OpaquePointer) -> Int {
    var count = 0
    _ = withUnsafeMutablePointer(to: &count) { pointer in
      git_stash_foreach(
        repository,
        { _, _, _, payload in
          payload?.assumingMemoryBound(to: Int.self).pointee += 1
          return 0
        }, pointer)
    }
    return count
  }

  // MARK: - State

  private static func state(of repository: OpaquePointer) -> StatusLineGitSnapshot.State? {
    switch git_repository_state(repository) {
    case Int32(GIT_REPOSITORY_STATE_MERGE.rawValue): .merge
    case Int32(GIT_REPOSITORY_STATE_REVERT.rawValue), Int32(GIT_REPOSITORY_STATE_REVERT_SEQUENCE.rawValue): .revert
    case Int32(GIT_REPOSITORY_STATE_CHERRYPICK.rawValue), Int32(GIT_REPOSITORY_STATE_CHERRYPICK_SEQUENCE.rawValue):
      .cherryPick
    case Int32(GIT_REPOSITORY_STATE_BISECT.rawValue): .bisect
    case Int32(GIT_REPOSITORY_STATE_REBASE.rawValue), Int32(GIT_REPOSITORY_STATE_REBASE_INTERACTIVE.rawValue),
      Int32(GIT_REPOSITORY_STATE_REBASE_MERGE.rawValue):
      .rebase
    case Int32(GIT_REPOSITORY_STATE_APPLY_MAILBOX.rawValue): .am
    case Int32(GIT_REPOSITORY_STATE_APPLY_MAILBOX_OR_REBASE.rawValue): .amOrRebase
    default: nil
    }
  }

  /// The progress of a rebase, from the files that git writes in the git
  /// folder: `rebase-merge/msgnum` and `end`, or `rebase-apply/next` and
  /// `last`.
  private static func rebaseProgress(of repository: OpaquePointer) -> StatusLineGitSnapshot.Progress? {
    guard let pathPointer = git_repository_path(repository) else { return nil }
    let gitFolder = URL(filePath: String(cString: pathPointer), directoryHint: .isDirectory)
    for (folder, currentName, totalName) in [("rebase-merge", "msgnum", "end"), ("rebase-apply", "next", "last")] {
      let base = gitFolder.appending(path: folder, directoryHint: .isDirectory)
      if let current = number(in: base.appending(path: currentName)),
        let total = number(in: base.appending(path: totalName))
      {
        return StatusLineGitSnapshot.Progress(current: current, total: total)
      }
    }
    return nil
  }

  private static func number(in file: URL) -> Int? {
    guard let text = try? String(contentsOf: file, encoding: .utf8) else { return nil }
    return Int(text.trimmingCharacters(in: .whitespacesAndNewlines))
  }
}
