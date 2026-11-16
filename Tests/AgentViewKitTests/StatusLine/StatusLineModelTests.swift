@testable import AgentViewKit
import AppKit
import FoundationModelsACP
import Synchronization
import Testing

/// The live folder data of the status line, with a fake probe, and the
/// parts of the view that need no window (D194 (j)).
@MainActor @Suite struct StatusLineModelTests {
  /// A probe whose answers the test changes.
  nonisolated final class FakeProbe: StatusLineGitProbing {
    struct Answers: Sendable {
      var snapshot: StatusLineGitSnapshot?
      var files: [String]?
    }

    let answers: Mutex<Answers>

    init(snapshot: StatusLineGitSnapshot? = nil, files: [String]? = nil) {
      answers = Mutex(Answers(snapshot: snapshot, files: files))
    }

    func set(snapshot: StatusLineGitSnapshot?, files: [String]?) {
      answers.withLock { $0 = Answers(snapshot: snapshot, files: files) }
    }

    func snapshot(of folder: String, ignoreSubmodules: Bool) async -> StatusLineGitSnapshot? {
      answers.withLock { $0.snapshot }
    }

    func files(in folder: String) async -> [String]? {
      answers.withLock { $0.files }
    }
  }

  static let folder = "/Users/me/code/Kit"
  static let snapshot = StatusLineGitSnapshot(root: folder, branch: "main")

  @Test func followReadsTheGitStateAndTheFilesOfTheRepository() async {
    let probe = FakeProbe(snapshot: Self.snapshot, files: ["a.swift"])
    let model = StatusLineModel(probe: probe, walk: { _ in ["walked"] }, watchesFolder: false)

    await model.follow(Self.folder, ignoreSubmodules: false)

    #expect(model.folder == Self.folder)
    #expect(model.git == Self.snapshot)
    #expect(model.files == ["a.swift"])
  }

  @Test func folderOutsideARepositoryIsWalked() async {
    let model = StatusLineModel(probe: FakeProbe(), walk: { _ in ["notes.py"] }, watchesFolder: false)

    await model.follow("/Users/me/notes", ignoreSubmodules: false)

    #expect(model.git == nil)
    #expect(model.files == ["notes.py"])
  }

  @Test func refreshReadsTheChangedState() async {
    let probe = FakeProbe(snapshot: Self.snapshot, files: ["a.swift"])
    let model = StatusLineModel(probe: probe, walk: { _ in [] }, watchesFolder: false)
    await model.follow(Self.folder, ignoreSubmodules: false)
    var changed = Self.snapshot
    changed.counts.modified = 2
    probe.set(snapshot: changed, files: ["a.swift", "b.rs"])

    await model.refresh()

    #expect(model.git?.counts.modified == 2)
    #expect(model.files == ["a.swift", "b.rs"])
  }

  @Test func followOfNoFolderClearsTheData() async {
    let model = StatusLineModel(probe: FakeProbe(snapshot: Self.snapshot, files: []), walk: { _ in [] }, watchesFolder: false)
    await model.follow(Self.folder, ignoreSubmodules: false)

    await model.follow(nil, ignoreSubmodules: false)

    #expect(model.git == nil)
    #expect(model.files == nil)
  }

  @Test func watcherFollowsTheGitFolderOfARootAboveTheFolder() {
    #expect(StatusLineModel.watchedPaths(folder: "/r/Sources", git: .init(root: "/r")) == ["/r/Sources", "/r/.git"])
    #expect(StatusLineModel.watchedPaths(folder: "/r", git: .init(root: "/r")) == ["/r"])
    #expect(StatusLineModel.watchedPaths(folder: "/n", git: nil) == ["/n"])
  }

  // MARK: - View parts

  @Test func eachBuiltinLanguageHasABundledIcon() {
    let names = Set(StatusLineIcons.names)
    for language in StatusLineLanguages.builtin {
      #expect(language.symbol == .icon(language.name))
      #expect(names.contains(language.name), "\(language.name)")
    }
  }

  @Test func bundledIconLoadsAsATemplateImage() throws {
    let image = try #require(StatusLineIcons.image(named: "swift"))
    #expect(image.isTemplate)
    #expect(image.size.width > 0)
    #expect(StatusLineIcons.image(named: "no-such-language") == nil)
  }

  @Test func modelNameIsTheNameOfTheCurrentChoice() throws {
    let json = #"""
      [{"configId":"model","name":"Model","category":"model","type":"select","currentValue":"q4",
        "options":[{"value":"q4","name":"Qwen3 4B"},{"value":"q8","name":"Qwen3 8B"}]}]
      """#
    let options = try JSONDecoder().decode([SessionConfigOption].self, from: Data(json.utf8))
    #expect(StatusLineView.modelName(of: options) == "Qwen3 4B")
    #expect(StatusLineView.modelName(of: nil) == nil)
  }

  @Test func purpleIsTheMagentaOfThePalette() {
    #expect(StatusLineText.paletteEntry(.purple) == .magenta)
    #expect(StatusLineText.paletteEntry(.brightPurple) == .brightMagenta)
    #expect(StatusLineText.paletteEntry(.cyan) == .cyan)
  }

  @Test func crumbsOfTheLineHaveTheTextStyleOfTheLine() {
    let style = StatusLineContent.lineCrumbStyle(.default)
    #expect(style.buttons.crumbCaptionStyle == StatusLineContent.textStyle)
    #expect(StatusLineContent.textStyle == .callout)
  }

  @Test func moduleIdentifierHasTheModuleName() {
    #expect(StatusLineView.identifier == "agent-status-line")
    #expect(StatusLineView.identifier(for: .gitBranch) == "agent-status-line-git_branch")
  }
}
