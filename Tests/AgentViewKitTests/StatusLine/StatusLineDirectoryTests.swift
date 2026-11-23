@testable import AgentViewKit
import Testing

/// The path of the `directory` module (D194 (f)): whole Finder names with
/// the Finder separator.
@Suite struct StatusLineDirectoryTests {
  static let home = "/Users/me"

  /// The container of the Testudo app in iCloud Drive.
  static let testudoContainer = "/Users/me/Library/Mobile Documents/iCloud~testudo~app"

  /// Eight long folder names below the home folder.
  static let longNames = [
    "Engineering", "Applications", "Development", "Repositories", "Swissarmyhammer", "AgentViewKit",
    "Documentation", "Architecture",
  ]

  /// The shown forms of the path, from the whole path to the narrowest
  /// form.
  static func forms(
    _ cwd: String, root: String? = nil, names: [String: String] = [:],
    _ change: (inout DirectoryModule) -> Void = { _ in }
  ) -> [[StatusLineDirectory.Part]] {
    var module = DirectoryModule()
    change(&module)
    return StatusLineDirectory.forms(
      cwd: cwd, homeFolder: home, repositoryRoot: root, module: module, displayName: { names[$0] })
  }

  /// The shown forms of the path as text.
  static func formTexts(_ cwd: String, _ change: (inout DirectoryModule) -> Void = { _ in }) -> [String] {
    forms(cwd, change).map { $0.map(\.text).joined() }
  }

  /// The whole shown path, and the repository root part.
  static func shown(
    _ cwd: String, root: String? = nil, names: [String: String] = [:],
    _ change: (inout DirectoryModule) -> Void = { _ in }
  ) -> (text: String, root: String?) {
    let parts = forms(cwd, root: root, names: names, change).first ?? []
    return (parts.map(\.text).joined(), parts.first(where: \.isRepositoryRoot)?.text)
  }

  /// The shown folder names of the whole path, with no separators.
  static func folders(_ cwd: String, names: [String: String] = [:]) -> [String] {
    shown(cwd, names: names).text.components(separatedBy: StatusLineDirectory.separator)
  }

  /// The folder names of each narrower form of a long path, with no
  /// separators.
  static func narrowerFolders(_ cwd: String) -> [[String]] {
    formTexts(cwd).dropFirst().map { $0.components(separatedBy: StatusLineDirectory.separator) }
  }

  /// The path below the home folder with the eight ``longNames``.
  static let longPath = home + "/" + longNames.joined(separator: "/")

  @Test func homeFolderIsTheHomeSymbol() {
    #expect(Self.shown("/Users/me").text == "~")
    #expect(Self.shown("/Users/me/").text == "~")
  }

  @Test func parentPartsAreWholeNames() {
    #expect(Self.shown("/Users/me/code/project").text == "~ › code › project")
  }

  @Test func separatorIsTheSeparatorOfFinder() {
    #expect(StatusLineDirectory.separator == " › ")
  }

  @Test func defaultPathInARepositoryReadsAsAPathWithTheRootWhole() {
    let shown = Self.shown("/Users/me/github/swissarmyhammer/TestudoApp", root: "/Users/me/github/swissarmyhammer/TestudoApp")
    #expect(shown.text == "~ › github › swissarmyhammer › TestudoApp")
    #expect(shown.root == "TestudoApp")
    let below = Self.shown(
      "/Users/me/github/swissarmyhammer/TestudoApp/Sources/App", root: "/Users/me/github/swissarmyhammer/TestudoApp")
    #expect(below.text == "~ › github › swissarmyhammer › TestudoApp › Sources › App")
    #expect(below.root == "TestudoApp")
  }

  @Test func defaultPathOutsideHomeStartsAtTheRoot() {
    let shown = Self.shown("/opt/work/repo/src", root: "/opt/work/repo")
    #expect(shown.text == "/ › opt › work › repo › src")
    #expect(shown.root == "repo")
  }

  @Test func rootFolderShowsItsDisplayName() {
    #expect(Self.shown("/opt/tools", names: ["/": "Macintosh HD"]).text == "Macintosh HD › opt › tools")
  }

  @Test func truncationLengthKeepsTheLastParts() {
    #expect(Self.shown("/Users/me/code/swift/project") { $0.truncationLength = 3 }.text == "code › swift › project")
  }

  @Test func truncationSymbolMarksALostPart() {
    let shown = Self.shown("/Users/me/code/swift/project") {
      $0.truncationLength = 3
      $0.truncationSymbol = "… › "
    }
    #expect(shown.text == "… › code › swift › project")
  }

  @Test func truncateToRepoStartsAtTheRootFolder() {
    let shown = Self.shown("/Users/me/code/Kit/Sources", root: "/Users/me/code/Kit") { $0.truncateToRepo = true }
    #expect(shown.text == "Kit › Sources")
    #expect(shown.root == "Kit")
  }

  @Test func repositoryRootThatTruncationRemovesIsNotMarked() {
    let shown = Self.shown("/Users/me/code/Kit/Sources/App/Views", root: "/Users/me/code/Kit") {
      $0.truncateToRepo = true
      $0.truncationLength = 3
    }
    #expect(shown.text == "Sources › App › Views")
    #expect(shown.root == nil)
  }

  @Test func folderOutsideTheHomeIsAbsolute() {
    #expect(Self.shown("/opt/tools").text == "/ › opt › tools")
    #expect(Self.shown("/").text == "/")
  }

  @Test func fishStyleLengthCutsEachParentPart() {
    #expect(Self.shown("/Users/me/code/project") { $0.fishStylePwdDirLength = 1 }.text == "~ › c › project")
  }

  @Test func fishStyleKeepsTheDotOfAHiddenFolder() {
    #expect(Self.shown("/Users/me/.config/sah") { $0.fishStylePwdDirLength = 1 }.text == "~ › .c › sah")
  }

  @Test func substitutionsChangeThePathInOrder() {
    let shown = Self.shown("/Users/me/code/project") {
      $0.substitutions = [.init(from: "~/code", to: "dev"), .init(from: "dev", to: "D")]
    }
    #expect(shown.text == "D › project")
  }

  @Test func homeSymbolIsAnOption() {
    #expect(Self.shown("/Users/me/x") { $0.homeSymbol = "🏠" }.text == "🏠 › x")
  }

  // MARK: - Finder names

  @Test func eachPartIsItsDisplayName() {
    let names = ["/Users/me/Documents": "Dokumente"]
    #expect(Self.shown("/Users/me/Documents/notes", names: names).text == "~ › Dokumente › notes")
  }

  @Test func iCloudContainerShowsAsICloudDriveAndTheNameOfTheContainer() {
    let cwd = Self.testudoContainer + "/Documents/Agents"
    #expect(Self.folders(cwd, names: [Self.testudoContainer: "Testudo"]) == ["iCloud Drive", "Testudo", "Agents"])
  }

  @Test func iCloudDriveFolderShowsAsICloudDrive() {
    let cwd = "/Users/me/Library/Mobile Documents/com~apple~CloudDocs/Notes"
    #expect(Self.folders(cwd) == ["iCloud Drive", "Notes"])
  }

  @Test func repositoryRootInAnICloudContainerKeepsTheRootStyle() {
    let cwd = Self.testudoContainer + "/Documents/Agents"
    let shown = Self.shown(cwd, root: cwd, names: [Self.testudoContainer: "Testudo"])
    #expect(shown.root == "Agents")
  }

  // MARK: - A long path

  @Test func eachNarrowerFormRemovesOneMoreMiddleName() {
    #expect(
      Self.formTexts("/Users/me/a/b/c/d") == ["~ › a › b › c › d", "~ › … › b › c › d", "~ › … › c › d", "~ › … › d"])
  }

  /// The user, 2026-11-23: "Keep last folder".
  @Test func narrowestFormKeepsTheLastFolderOnly() {
    #expect(Self.formTexts("/Users/me/code/AgentViewKit/Sources/AgentViewKit").last == "~ › … › AgentViewKit")
  }

  @Test func longPathHasAFormForEachMiddleName() {
    #expect(Self.forms(Self.longPath).count == Self.longNames.count - StatusLineDirectory.keptLastFolders + 1)
  }

  @Test func eachNarrowerFormHasExactlyOneEllipsis() {
    #expect(Self.narrowerFolders(Self.longPath).allSatisfy { $0.filter { $0 == StatusLineDirectory.ellipsis }.count == 1 })
  }

  @Test func eachNarrowerFormShowsOnlyWholeNames() {
    let shownNames = Self.narrowerFolders(Self.longPath).flatMap { $0.filter { $0 != "~" && $0 != StatusLineDirectory.ellipsis } }
    #expect(!shownNames.isEmpty && shownNames.allSatisfy(Self.longNames.contains))
  }

  @Test func eachNarrowerFormKeepsTheHomeAndTheLastFolders() {
    let lastFolders = Array(Self.longNames.suffix(StatusLineDirectory.keptLastFolders))
    #expect(Self.narrowerFolders(Self.longPath).allSatisfy { $0.first == "~" && Array($0.suffix(lastFolders.count)) == lastFolders })
  }

  @Test func pathWithNoMiddleNameHasOneForm() {
    #expect(Self.formTexts("/Users/me/project") == ["~ › project"])
  }

  @Test func truncationLengthGivesOneForm() {
    #expect(Self.forms(Self.longPath) { $0.truncationLength = 4 }.count == 1)
  }

  // MARK: - The home folder

  @Test func userDatabaseHomeIsTheHomeNotTheSandboxContainer() {
    let home = UserHomeFolder.path(userDatabase: "/Users/me", process: "/Users/me/Library/Containers/app.testudo/Data")
    let forms = StatusLineDirectory.forms(
      cwd: "/Users/me/Documents/Agents", homeFolder: home, repositoryRoot: nil, module: DirectoryModule())
    #expect(forms.first?.first?.text == "~")
  }

  @Test func processHomeIsTheHomeWithNoUserDatabaseEntry() {
    #expect(UserHomeFolder.path(userDatabase: nil, process: "/Users/me") == "/Users/me")
  }

  // MARK: - The help of the module

  @Test func fullPathIsTheHelpOfTheModule() {
    let input = StatusLineInput(cwd: "/Users/me/code/project", homeFolder: Self.home)
    let line = StatusLineRenderer.render(StatusLines.defaultDefinition, input: input)
    #expect(line.help(of: .directory) == "/Users/me/code/project")
  }

  @Test func rendererShowsTheDisplayNamesOfTheInput() {
    var input = StatusLineInput(cwd: "/Users/me/code/project", homeFolder: Self.home)
    input.displayNames = ["/Users/me/code": "Code"]
    let line = StatusLineRenderer.render(StatusLines.defaultDefinition, input: input)
    #expect(line.text(of: .directory) == "~ › Code › project")
  }
}
