@testable import AgentViewKit
import Foundation
import Testing

/// The libgit2 probe of the status line, with repositories that the tests
/// make with libgit2 (D194 (f)).
@Suite(.serialized) struct StatusLineGitProbeTests {
  let probe = LibGit2StatusLineProbe()

  @Test func folderOutsideARepositoryHasNoSnapshot() async throws {
    let folder = try StatusLineTemporaryFolder()
    #expect(await probe.snapshot(of: folder.path, ignoreSubmodules: false) == nil)
    #expect(await probe.files(in: folder.path) == nil)
  }

  @Test func newRepositoryHasItsUnbornBranch() async throws {
    let repository = try StatusLineTestRepository()
    let snapshot = try #require(await probe.snapshot(of: repository.path, ignoreSubmodules: false))
    #expect(snapshot.root == repository.path)
    #expect(snapshot.branch == "master" || snapshot.branch == "main")
    #expect(snapshot.counts == .init())
  }

  @Test func countsOfStagedModifiedUntrackedAndDeletedFiles() async throws {
    let repository = try StatusLineTestRepository()
    try repository.commit(["a.swift": "a\n", "b.swift": "b\n", "c.swift": "c\n"])
    try repository.folder.write("a.swift", "changed\n")
    try repository.folder.write("new.swift", "new\n")
    try repository.folder.write("staged.swift", "s\n")
    try repository.stage(["staged.swift"])
    try repository.folder.remove("b.swift")

    let snapshot = try #require(await probe.snapshot(of: repository.path, ignoreSubmodules: false))
    #expect(snapshot.counts == .init(staged: 1, modified: 1, untracked: 1, deleted: 1))
    #expect(snapshot.ahead == nil)
    #expect(snapshot.state == nil)
  }

  @Test func subfolderFindsTheRepositoryRoot() async throws {
    let repository = try StatusLineTestRepository()
    try repository.commit(["Sources/App/main.swift": "x\n"])
    let snapshot = try #require(
      await probe.snapshot(of: repository.path + "/Sources/App", ignoreSubmodules: false))
    #expect(snapshot.root == repository.path)
  }

  @Test func detachedHeadHasTheShortHash() async throws {
    let repository = try StatusLineTestRepository()
    let first = try repository.commit(["a.txt": "1\n"])
    try repository.commit(["a.txt": "2\n"])
    try repository.detachHead(at: first)

    let snapshot = try #require(await probe.snapshot(of: repository.path, ignoreSubmodules: false))
    #expect(snapshot.branch == nil)
    #expect(snapshot.detachedHash == String(first.hexText.prefix(7)))
  }

  @Test func aheadAndBehindOfTheUpstream() async throws {
    let repository = try StatusLineTestRepository()
    let first = try repository.commit(["a.txt": "1\n"])
    let branch = try #require(await probe.snapshot(of: repository.path, ignoreSubmodules: false)?.branch)
    try repository.setUpstream(branch: branch, at: first)
    try repository.commit(["a.txt": "2\n"])
    try repository.commit(["a.txt": "3\n"])

    let snapshot = try #require(await probe.snapshot(of: repository.path, ignoreSubmodules: false))
    #expect(snapshot.ahead == 2)
    #expect(snapshot.behind == 0)
  }

  @Test func mergeHeadIsTheMergeState() async throws {
    let repository = try StatusLineTestRepository()
    let first = try repository.commit(["a.txt": "1\n"])
    try repository.writeGitFile("MERGE_HEAD", first.hexText + "\n")

    let snapshot = try #require(await probe.snapshot(of: repository.path, ignoreSubmodules: false))
    #expect(snapshot.state == .merge)
    #expect(snapshot.progress == nil)
  }

  @Test func rebaseHasItsProgress() async throws {
    let repository = try StatusLineTestRepository()
    try repository.commit(["a.txt": "1\n"])
    try repository.writeGitFile("rebase-merge/msgnum", "2\n")
    try repository.writeGitFile("rebase-merge/end", "5\n")

    let snapshot = try #require(await probe.snapshot(of: repository.path, ignoreSubmodules: false))
    #expect(snapshot.state == .rebase)
    #expect(snapshot.progress == .init(current: 2, total: 5))
  }

  @Test func filesAreTheIndexAndTheUntrackedFilesThatAreNotIgnored() async throws {
    let repository = try StatusLineTestRepository()
    try repository.commit([".gitignore": "build/\n", "Sources/a.swift": "a\n", "README.md": "r\n"])
    try repository.folder.write("Sources/new.rs", "n\n")
    try repository.folder.write("build/out.o", "o\n")

    let files = try #require(await probe.files(in: repository.path))
    #expect(Set(files) == [".gitignore", "Sources/a.swift", "README.md", "Sources/new.rs"])
  }

  @Test func filesOfASubfolderAreRelativeToIt() async throws {
    let repository = try StatusLineTestRepository()
    try repository.commit(["Sources/a.swift": "a\n", "Tests/t.swift": "t\n"])
    try repository.folder.write("Sources/b.py", "b\n")

    let files = try #require(await probe.files(in: repository.path + "/Sources"))
    #expect(Set(files) == ["a.swift", "b.py"])
  }
}
