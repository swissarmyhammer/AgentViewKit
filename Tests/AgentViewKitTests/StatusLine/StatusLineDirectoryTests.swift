@testable import AgentViewKit
import Testing

/// The path of the `directory` module (D194 (f)).
@Suite struct StatusLineDirectoryTests {
  static let home = "/Users/me"

  /// The shown path, and the repository root part.
  static func shown(
    _ cwd: String, root: String? = nil, _ change: (inout DirectoryModule) -> Void = { _ in }
  ) -> (text: String, root: String?) {
    var module = DirectoryModule()
    change(&module)
    let parts = StatusLineDirectory.parts(cwd: cwd, homeFolder: home, repositoryRoot: root, module: module)
    return (parts.map(\.text).joined(), parts.first(where: \.isRepositoryRoot)?.text)
  }

  @Test func homeFolderIsTheHomeSymbol() {
    #expect(Self.shown("/Users/me").text == "~")
    #expect(Self.shown("/Users/me/").text == "~")
  }

  @Test func parentPartsAreShortenedFishStyle() {
    #expect(Self.shown("/Users/me/code/project").text == "~/c/project")
  }

  @Test func defaultPathIsTheWholePathFromHome() {
    #expect(Self.shown("/Users/me/code/swift/project").text == "~/c/s/project")
  }

  @Test func defaultPathInARepositoryReadsAsAPathWithTheRootWhole() {
    let shown = Self.shown("/Users/me/github/swissarmyhammer/TestudoApp", root: "/Users/me/github/swissarmyhammer/TestudoApp")
    #expect(shown.text == "~/g/s/TestudoApp")
    #expect(shown.root == "TestudoApp")
    let below = Self.shown(
      "/Users/me/github/swissarmyhammer/TestudoApp/Sources/App", root: "/Users/me/github/swissarmyhammer/TestudoApp")
    #expect(below.text == "~/g/s/TestudoApp/S/App")
    #expect(below.root == "TestudoApp")
  }

  @Test func defaultPathOutsideHomeStartsAtTheRoot() {
    let shown = Self.shown("/opt/work/repo/src", root: "/opt/work/repo")
    #expect(shown.text == "/o/w/repo/src")
    #expect(shown.root == "repo")
  }

  @Test func truncationLengthKeepsTheLastParts() {
    #expect(Self.shown("/Users/me/code/swift/project") { $0.truncationLength = 3 }.text == "c/s/project")
  }

  @Test func truncationSymbolMarksALostPart() {
    let shown = Self.shown("/Users/me/code/swift/project") {
      $0.truncationLength = 3
      $0.truncationSymbol = "…/"
    }
    #expect(shown.text == "…/c/s/project")
  }

  @Test func truncateToRepoStartsAtTheRootFolder() {
    let shown = Self.shown("/Users/me/code/Kit/Sources", root: "/Users/me/code/Kit") { $0.truncateToRepo = true }
    #expect(shown.text == "Kit/Sources")
    #expect(shown.root == "Kit")
  }

  @Test func repositoryRootThatTruncationRemovesIsNotMarked() {
    let shown = Self.shown("/Users/me/code/Kit/Sources/App/Views", root: "/Users/me/code/Kit") {
      $0.truncateToRepo = true
      $0.truncationLength = 3
    }
    #expect(shown.text == "S/A/Views")
    #expect(shown.root == nil)
  }

  @Test func folderOutsideTheHomeIsAbsolute() {
    #expect(Self.shown("/opt/tools").text == "/o/tools")
    #expect(Self.shown("/").text == "/")
  }

  @Test func zeroFishLengthKeepsEachPartWhole() {
    #expect(Self.shown("/Users/me/code/project") { $0.fishStylePwdDirLength = 0 }.text == "~/code/project")
  }

  @Test func hiddenFolderKeepsItsDot() {
    #expect(Self.shown("/Users/me/.config/sah").text == "~/.c/sah")
  }

  @Test func substitutionsChangeThePathInOrder() {
    let shown = Self.shown("/Users/me/code/project") {
      $0.substitutions = [.init(from: "~/code", to: "dev"), .init(from: "dev", to: "D")]
    }
    #expect(shown.text == "D/project")
  }

  @Test func homeSymbolIsAnOption() {
    #expect(Self.shown("/Users/me/x") { $0.homeSymbol = "🏠" }.text == "🏠/x")
  }
}
