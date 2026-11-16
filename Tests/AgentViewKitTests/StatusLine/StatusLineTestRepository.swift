import Foundation
import Testing
import libgit2

/// A temporary folder for the status line tests, removed at the end of the
/// test.
nonisolated final class StatusLineTemporaryFolder {
  /// The path of the folder, with symbolic links resolved.
  let path: String

  init() throws {
    let url = FileManager.default.temporaryDirectory.appending(
      path: "status-line-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    path = url.resolvingSymlinksInPath().path(percentEncoded: false).trimmingSuffix("/")
  }

  deinit {
    try? FileManager.default.removeItem(atPath: path)
  }

  /// Writes a file, and makes its folders.
  func write(_ relativePath: String, _ text: String = "x\n") throws {
    let url = URL(filePath: path).appending(path: relativePath)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(text.utf8).write(to: url)
  }

  /// Removes a file.
  func remove(_ relativePath: String) throws {
    try FileManager.default.removeItem(atPath: path + "/" + relativePath)
  }
}

/// A git repository that the tests make with libgit2. The tests run no `git`
/// program.
nonisolated final class StatusLineTestRepository {
  /// The folder of the work tree.
  let folder: StatusLineTemporaryFolder

  /// The repository.
  let repository: OpaquePointer

  /// The path of the work tree.
  var path: String { folder.path }

  init() throws {
    try #require(git_libgit2_init() > 0)
    folder = try StatusLineTemporaryFolder()
    var repository: OpaquePointer?
    try #require(git_repository_init(&repository, folder.path, 0) == GIT_OK.rawValue)
    self.repository = try #require(repository)
  }

  deinit {
    git_repository_free(repository)
    git_libgit2_shutdown()
  }

  /// Adds files to the index.
  func stage(_ paths: [String]) throws {
    var index: OpaquePointer?
    try #require(git_repository_index(&index, repository) == GIT_OK.rawValue)
    defer { git_index_free(index) }
    for path in paths {
      try #require(git_index_add_bypath(index, path) == GIT_OK.rawValue)
    }
    try #require(git_index_write(index) == GIT_OK.rawValue)
  }

  /// Writes, stages and commits files on the HEAD.
  @discardableResult
  func commit(_ files: [String: String], message: String = "change") throws -> git_oid {
    for (path, text) in files { try folder.write(path, text) }
    try stage(Array(files.keys))
    var index: OpaquePointer?
    try #require(git_repository_index(&index, repository) == GIT_OK.rawValue)
    defer { git_index_free(index) }
    var treeID = git_oid()
    try #require(git_index_write_tree(&treeID, index) == GIT_OK.rawValue)
    var tree: OpaquePointer?
    try #require(git_tree_lookup(&tree, repository, &treeID) == GIT_OK.rawValue)
    defer { git_tree_free(tree) }
    var signature: UnsafeMutablePointer<git_signature>?
    try #require(git_signature_new(&signature, "Tester", "tester@example.invalid", 1_700_000_000, 0) == GIT_OK.rawValue)
    defer { git_signature_free(signature) }
    var parent: OpaquePointer?
    var parentID = git_oid()
    let hasParent = git_reference_name_to_id(&parentID, repository, "HEAD") == GIT_OK.rawValue
    if hasParent {
      try #require(git_commit_lookup(&parent, repository, &parentID) == GIT_OK.rawValue)
    }
    defer { if let parent { git_commit_free(parent) } }
    var commitID = git_oid()
    var parents: [OpaquePointer?] = hasParent ? [parent] : []
    let result = parents.withUnsafeMutableBufferPointer { buffer in
      git_commit_create(
        &commitID, repository, "HEAD", signature, signature, nil, message, tree, buffer.count, buffer.baseAddress)
    }
    try #require(result == GIT_OK.rawValue)
    return commitID
  }

  /// Makes a reference that points to a commit.
  func makeReference(_ name: String, to id: git_oid) throws {
    var reference: OpaquePointer?
    var target = id
    try #require(git_reference_create(&reference, repository, name, &target, 1, nil) == GIT_OK.rawValue)
    git_reference_free(reference)
  }

  /// Makes the remote `origin` and the upstream `origin/<branch>` of the
  /// branch at `id`.
  func setUpstream(branch: String, at id: git_oid) throws {
    var remote: OpaquePointer?
    try #require(git_remote_create(&remote, repository, "origin", "https://example.invalid/r.git") == GIT_OK.rawValue)
    git_remote_free(remote)
    try makeReference("refs/remotes/origin/\(branch)", to: id)
    var local: OpaquePointer?
    try #require(git_branch_lookup(&local, repository, branch, GIT_BRANCH_LOCAL) == GIT_OK.rawValue)
    defer { git_reference_free(local) }
    try #require(git_branch_set_upstream(local, "origin/\(branch)") == GIT_OK.rawValue)
  }

  /// Detaches the HEAD at a commit.
  func detachHead(at id: git_oid) throws {
    var target = id
    try #require(git_repository_set_head_detached(repository, &target) == GIT_OK.rawValue)
  }

  /// Writes a file in the git folder, such as `MERGE_HEAD`.
  func writeGitFile(_ relativePath: String, _ text: String) throws {
    try folder.write(".git/" + relativePath, text)
  }
}

nonisolated extension String {
  /// The text with no `suffix` at its end.
  func trimmingSuffix(_ suffix: String) -> String {
    count > suffix.count && hasSuffix(suffix) ? String(dropLast(suffix.count)) : self
  }
}

nonisolated extension git_oid {
  /// The hexadecimal text of the id.
  var hexText: String {
    var copy = self
    return String(cString: git_oid_tostr_s(&copy))
  }
}
