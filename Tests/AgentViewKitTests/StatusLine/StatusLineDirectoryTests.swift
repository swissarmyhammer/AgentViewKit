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

  @Test func pathKeepsAtMostThreeParts() {
    #expect(Self.shown("/Users/me/code/swift/project").text == "c/s/project")
  }

  @Test func truncationSymbolMarksALostPart() {
    #expect(Self.shown("/Users/me/code/swift/project") { $0.truncationSymbol = "…/" }.text == "…/c/s/project")
  }

  @Test func repositoryRootIsTheFirstPartAndStaysWhole() {
    let shown = Self.shown("/Users/me/code/Kit/Sources", root: "/Users/me/code/Kit")
    #expect(shown.text == "Kit/Sources")
    #expect(shown.root == "Kit")
  }

  @Test func repositoryRootThatTruncationRemovesIsNotMarked() {
    let shown = Self.shown("/Users/me/code/Kit/Sources/App/Views", root: "/Users/me/code/Kit")
    #expect(shown.text == "S/A/Views")
    #expect(shown.root == nil)
  }

  @Test func withNoTruncateToRepoTheHomeSymbolStarts() {
    let shown = Self.shown("/Users/me/code/Kit", root: "/Users/me/code/Kit") { $0.truncateToRepo = false }
    #expect(shown.text == "~/c/Kit")
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
