@testable import AgentViewKit
import Foundation
import Testing

/// The rendering of each module and of the builtin presets (D194 (e), (f)).
@Suite struct StatusLineRendererTests {
  static let home = "/Users/me"

  static let git = StatusLineGitSnapshot(
    root: "/Users/me/code/Kit", branch: "main",
    counts: .init(staged: 3, modified: 2, untracked: 1), ahead: 1, behind: 0)

  static func input(_ change: (inout StatusLineInput) -> Void = { _ in }) -> StatusLineInput {
    var input = StatusLineInput(
      cwd: "/Users/me/code/Kit", homeFolder: home, git: git, files: ["a.swift", "b.swift", "c.py"],
      sessionTitle: "Fix the parser", date: Date(timeIntervalSince1970: 0), timeZone: .gmt)
    change(&input)
    return input
  }

  static func text(_ id: StatusLineModuleID, _ input: StatusLineInput = input(), _ change: (inout StatusLineDefinition) -> Void = { _ in }) -> String? {
    var definition = StatusLines.defaultDefinition
    change(&definition)
    return StatusLineRenderer.moduleSpans(id, definition: definition, input: input)
      .map { $0.map(\.plainText).joined() }
  }

  // MARK: - The line

  @Test func defaultLineInARepository() {
    let line = StatusLineRenderer.render(StatusLines.defaultDefinition, input: Self.input())
    #expect(line.modules == [.directory, .gitBranch, .gitStatus, .languages, .session])
    #expect(line.plainText == "~ › code › Kit main+3!2?1⇡1 swift python Fix the parser")
  }

  @Test func defaultLineOutsideARepositoryHasNoGitAndNoDoubleSpace() {
    let input = Self.input {
      $0.cwd = "/Users/me/notes"
      $0.git = nil
      $0.files = ["todo.md"]
    }
    let line = StatusLineRenderer.render(StatusLines.defaultDefinition, input: input)
    #expect(line.modules == [.directory, .session])
    #expect(line.plainText == "~ › notes Fix the parser")
    #expect(!line.pieces.contains { $0.module == nil && $0.plainText.contains("  ") })
  }

  @Test func minimalLine() throws {
    let line = StatusLineRenderer.render(try #require(StatusLines.named("minimal")), input: Self.input())
    #expect(line.modules == [.directory, .gitBranch, .session])
  }

  @Test func fullLineAddsContext() throws {
    let input = Self.input {
      $0.modelName = "Qwen3"
      $0.contextUsed = 30
      $0.contextSize = 100
    }
    let line = StatusLineRenderer.render(try #require(StatusLines.named("full")), input: input)
    #expect(line.modules.last == .context)
    #expect(!line.modules.contains(.model))
    #expect(!line.modules.contains(.time))
    #expect(line.text(of: .context) == " 30%")
  }

  @Test func modelModuleShowsInACustomFormat() {
    let input = Self.input { $0.modelName = "Qwen3" }
    #expect(Self.text(.model, input) == " Qwen3")
  }

  @Test func repositoryRootHasTheRootStyle() throws {
    let spans = try #require(
      StatusLineRenderer.moduleSpans(.directory, definition: StatusLines.defaultDefinition, input: Self.input {
        $0.cwd = "/Users/me/code/Kit/Sources"
      }))
    let directory = StatusLines.defaultDefinition.directory
    #expect(spans.map(\.plainText).joined() == "~ › code › Kit › Sources")
    #expect(spans.contains(.text("Kit", directory.repoRootStyle)))
    #expect(spans.last == .text("Sources", directory.style))
  }

  // MARK: - git_branch

  @Test func branchHasItsSymbolAndName() throws {
    let spans = try #require(
      StatusLineRenderer.moduleSpans(.gitBranch, definition: StatusLines.defaultDefinition, input: Self.input()))
    #expect(spans.first?.content == .sfSymbol("arrow.triangle.branch"))
    #expect(spans.map(\.plainText).joined() == " main")
  }

  @Test func detachedHeadShowsTheHashUnlessOnlyAttached() {
    var git = Self.git
    git.branch = nil
    git.detachedHash = "abc1234"
    let input = Self.input { $0.git = git }
    #expect(Self.text(.gitBranch, input) == " abc1234")
    #expect(Self.text(.gitBranch, input) { $0.gitBranch.onlyAttached = true } == nil)
  }

  @Test func branchTruncatesAndIgnoredBranchShowsNothing() {
    #expect(Self.text(.gitBranch) { $0.gitBranch.truncationLength = 2 } == " ma…")
    #expect(Self.text(.gitBranch) { $0.gitBranch.ignoreBranches = ["main"] } == nil)
  }

  // MARK: - git_status

  @Test func cleanRepositoryUpToDateShowsNothing() {
    let input = Self.input { $0.git = StatusLineGitSnapshot(root: "/Users/me/code/Kit", branch: "main", ahead: 0, behind: 0) }
    #expect(Self.text(.gitStatus, input) == nil)
    #expect(Self.text(.gitStatus, input) { $0.gitStatus.upToDate = "✓" } == "✓")
  }

  @Test func countsShowInTheOrderOfAllStatus() {
    let git = StatusLineGitSnapshot(
      root: "/r", branch: "main",
      counts: .init(conflicted: 1, staged: 2, modified: 3, untracked: 4, deleted: 5, renamed: 6), stashed: 7)
    #expect(Self.text(.gitStatus, Self.input { $0.git = git }) == "=1$7✘5»6+2!3?4")
  }

  @Test func divergedAndBehind() {
    var git = Self.git
    git.counts = .init()
    git.ahead = 2
    git.behind = 3
    #expect(Self.text(.gitStatus, Self.input { $0.git = git }) == "⇕⇡2⇣3")
    git.ahead = 0
    #expect(Self.text(.gitStatus, Self.input { $0.git = git }) == "⇣3")
  }

  // MARK: - git_state

  @Test func stateShowsItsLabelAndProgress() {
    var git = Self.git
    git.state = .rebase
    git.progress = .init(current: 2, total: 5)
    #expect(Self.text(.gitState, Self.input { $0.git = git }) == "REBASING 2/5")
    git.state = .merge
    git.progress = nil
    #expect(Self.text(.gitState, Self.input { $0.git = git }) == "MERGING")
    #expect(Self.text(.gitState) == nil)
  }

  // MARK: - languages, session, agent, model, context, time

  @Test func languagesAreIconsWithTheMostFilesFirst() throws {
    let spans = try #require(
      StatusLineRenderer.moduleSpans(.languages, definition: StatusLines.defaultDefinition, input: Self.input()))
    #expect(spans.filter { $0.content != .text(" ") }.map(\.content) == [.icon("swift"), .icon("python")])
  }

  @Test func languagesShowNothingBeforeTheFilesAreRead() {
    #expect(Self.text(.languages, Self.input { $0.files = nil }) == nil)
  }

  /// A title that only repeats the folder shows no session text, and leaves
  /// no space (the user, 2026-11-16).
  @Test func sessionTitledLikeItsFolderShowsNothing() {
    let input = Self.input { $0.sessionTitle = "Kit" }
    #expect(Self.text(.session, input) == nil)
    #expect(Self.text(.session, Self.input { $0.sessionTitle = "kit" }) == nil)
    #expect(Self.text(.session, Self.input { $0.sessionTitle = "  " }) == nil)
    let line = StatusLineRenderer.render(StatusLines.defaultDefinition, input: input)
    #expect(!line.modules.contains(.session))
    #expect(line.plainText == "~ › code › Kit main+3!2?1⇡1 swift python")
  }

  @Test func sessionTitleThatSaysSomethingNewShows() {
    #expect(Self.text(.session, Self.input { $0.sessionTitle = "Kit release" }) == "Kit release")
  }

  @Test func sessionTitleTruncates() {
    #expect(Self.text(.session) { $0.session.truncationLength = 3 } == "Fix…")
    #expect(Self.text(.session, Self.input { $0.sessionTitle = nil }) == nil)
  }

  @Test func agentHasItsNameAndVersion() {
    let input = Self.input {
      $0.agentName = "Agent"
      $0.agentVersion = "1.2"
    }
    #expect(Self.text(.agent, input) == "Agent 1.2")
    #expect(Self.text(.agent, Self.input { $0.agentName = "Agent" }) == "Agent")
  }

  @Test func contextTakesTheStyleOfItsThreshold() throws {
    let input = Self.input {
      $0.contextUsed = 90
      $0.contextSize = 100
    }
    let spans = try #require(
      StatusLineRenderer.moduleSpans(.context, definition: StatusLines.defaultDefinition, input: input))
    #expect(spans.allSatisfy { $0.style == "red" })
    #expect(Self.text(.context, input) { $0.context.format = "$bar" } == "█████████░")
    #expect(Self.text(.context, Self.input { $0.contextSize = 0 }) == nil)
  }

  @Test func timeUsesItsFormat() {
    let input = Self.input { $0.date = Date(timeIntervalSince1970: 3_723) }
    #expect(Self.text(.time, input) { $0.time.timeFormat = "HH:mm:ss" } == "01:02:03")
  }

  @Test func disabledModuleShowsNothing() {
    #expect(Self.text(.directory) { $0.directory.disabled = true } == nil)
    #expect(Self.text(.gitBranch) { $0.gitBranch.disabled = true } == nil)
  }

  @Test func moduleFormatChangesItsText() {
    #expect(Self.text(.gitBranch) { $0.gitBranch.format = "on $branch" } == "on main")
  }
}
