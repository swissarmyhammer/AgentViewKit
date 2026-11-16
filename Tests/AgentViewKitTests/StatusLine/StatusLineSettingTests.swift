@testable import AgentViewKit
import FoundationModelsACP
import Testing

/// The presets and the decode of the `statusline` setting (D194 (b), (c),
/// (f)).
@Suite struct StatusLineSettingTests {
  // MARK: - Presets

  @Test func builtinPresetsAreDefaultMinimalAndFull() {
    #expect(StatusLines.builtin.map(\.name) == ["default", "minimal", "full"])
    #expect(StatusLines.defaultName == "default")
    #expect(StatusLines.named("minimal")?.name == "minimal")
    #expect(StatusLines.named("nope") == nil)
  }

  @Test func defaultPresetHasTheFormatOfTheDecision() {
    #expect(
      StatusLines.defaultDefinition.format.text
        == "$directory $git_branch$git_status$git_state $languages $session")
    #expect(StatusLines.named("minimal")?.format.text == "$directory $git_branch $session")
  }

  /// No preset shows the model or the time (the user, 2026-11-16: the Mac
  /// has a clock in the menu bar); the modules stay for a custom format.
  @Test func fullPresetAddsContextAndNoPresetShowsTheModelOrTheTime() throws {
    let full = try #require(StatusLines.named("full"))
    let base = StatusLines.defaultDefinition.format.references
    #expect(full.format.references == base.union(["context"]))
    #expect(StatusLines.builtin.allSatisfy { $0.format.references.isDisjoint(with: ["model", "time"]) })
  }

  @Test(arguments: StatusLines.builtin.map(\.name))
  func eachPresetUsesOnlyKnownModulesAndCodesWithNoLoss(name: String) throws {
    let preset = try #require(StatusLines.named(name))
    try preset.format.validate(references: StatusLineDefinition.references)
    #expect(try StatusLineTestCoding.roundTrip(preset) == preset)
  }

  @Test func defaultDirectoryHasTheOptionsOfTheDecision() {
    let directory = StatusLines.defaultDefinition.directory
    #expect(directory.truncationLength == 0)
    #expect(!directory.truncateToRepo)
    #expect(directory.fishStylePwdDirLength == 1)
    #expect(directory.homeSymbol == "~")
    #expect(directory.repoRootStyle.modifiers.contains(.bold))
    #expect(directory.style == "bold")
    #expect(directory.style.color == nil)
  }

  @Test func defaultLanguagesShowAtMostFour() {
    #expect(StatusLines.defaultDefinition.languages.maximum == 4)
    #expect(StatusLines.defaultDefinition.languages.languages.contains { $0.name == "swift" })
  }

  // MARK: - Resolve

  @Test func noSettingIsTheDefaultPreset() {
    for value in [nil, JSONValue.null] {
      let resolution = StatusLineSetting.resolve(value)
      #expect(resolution.definition == StatusLines.defaultDefinition)
      #expect(resolution.problems.isEmpty)
    }
  }

  @Test func presetSelectsTheBuiltinPreset() {
    let resolution = StatusLineSetting.resolve(.object(["preset": .string("minimal")]))
    #expect(resolution.definition == StatusLines.named("minimal"))
    #expect(resolution.problems.isEmpty)
  }

  @Test func optionChangesThePresetKeyByKey() throws {
    let value: JSONValue = .object([
      "preset": .string("minimal"),
      "directory": .object(["truncation_length": .number(2)]),
    ])
    // The default is 0 (no limit), so 2 is a change.
    let resolution = StatusLineSetting.resolve(value)
    var expected = try #require(StatusLines.named("minimal"))
    expected.directory.truncationLength = 2
    #expect(resolution.definition == expected)
    #expect(resolution.problems.isEmpty)
  }

  @Test func formatReplacesTheFormatOfThePreset() {
    let resolution = StatusLineSetting.resolve(.object(["format": .string("$session $directory")]))
    #expect(resolution.definition.format.text == "$session $directory")
    #expect(resolution.problems.isEmpty)
  }

  @Test func listReplacesTheListOfThePreset() {
    let value: JSONValue = .object([
      "languages": .object([
        "languages": .array([.object(["name": .string("swift"), "detect_extensions": .array([.string("swift")])])])
      ])
    ])
    let resolution = StatusLineSetting.resolve(value)
    #expect(resolution.definition.languages.languages.map(\.name) == ["swift"])
    #expect(resolution.definition.languages.languages.first?.symbol == .text("swift"))
    #expect(resolution.problems.isEmpty)
  }

  @Test func unknownPresetIsAProblemAndKeepsTheDefault() {
    let resolution = StatusLineSetting.resolve(.object(["preset": .string("fancy")]))
    #expect(resolution.definition == StatusLines.defaultDefinition)
    #expect(resolution.problems.map(\.keyPath) == [["statusline", "preset"]])
  }

  @Test func unknownKeysAreProblemsWithTheirKeyPaths() {
    let value: JSONValue = .object([
      "colour": .string("red"),
      "directory": .object(["truncation_length": .number(2), "read_only": .bool(true)]),
    ])
    let resolution = StatusLineSetting.resolve(value)
    #expect(
      Set(resolution.problems.map(\.keyPath)) == [
        ["statusline", "colour"], ["statusline", "directory", "read_only"],
      ])
    // The known key of the module still applies.
    #expect(resolution.definition.directory.truncationLength == 2)
  }

  @Test func wrongValueIsAProblemAndKeepsThePresetModule() {
    let value: JSONValue = .object([
      "git_branch": .object(["style": .string("rainbow"), "truncation_length": .number(4)]),
      "directory": .object(["truncation_length": .number(2)]),
    ])
    let resolution = StatusLineSetting.resolve(value)
    #expect(resolution.definition.gitBranch == StatusLines.defaultDefinition.gitBranch)
    #expect(resolution.definition.directory.truncationLength == 2)
    #expect(resolution.problems.map(\.keyPath) == [["statusline", "git_branch", "style"]])
  }

  @Test func wrongTypeIsAProblem() {
    let value: JSONValue = .object(["directory": .object(["truncate_to_repo": .string("yes")])])
    let resolution = StatusLineSetting.resolve(value)
    #expect(resolution.problems.map(\.keyPath) == [["statusline", "directory", "truncate_to_repo"]])
    #expect(resolution.definition.directory == StatusLines.defaultDefinition.directory)
  }

  @Test func unknownModuleInTheFormatIsAProblem() {
    let resolution = StatusLineSetting.resolve(.object(["format": .string("$directory $battery")]))
    #expect(resolution.problems.map(\.keyPath) == [["statusline", "format"]])
    #expect(resolution.definition.format == StatusLines.defaultDefinition.format)
  }

  @Test func unknownReferenceInAModuleFormatIsAProblem() {
    let value: JSONValue = .object(["git_branch": .object(["format": .string("$symbol$remote")])])
    let resolution = StatusLineSetting.resolve(value)
    #expect(resolution.problems.map(\.keyPath) == [["statusline", "git_branch", "format"]])
  }

  @Test func settingThatIsNotAnObjectIsAProblem() {
    let resolution = StatusLineSetting.resolve(.string("minimal"))
    #expect(resolution.definition == StatusLines.defaultDefinition)
    #expect(resolution.problems.map(\.keyPath) == [["statusline"]])
  }

  @Test func unknownKeyInAListElementIsAProblem() {
    let value: JSONValue = .object([
      "context": .object([
        "thresholds": .array([.object(["below": .number(10), "style": .string("red"), "color": .string("x")])])
      ])
    ])
    let resolution = StatusLineSetting.resolve(value)
    #expect(resolution.problems.map(\.keyPath) == [["statusline", "context", "thresholds", "0", "color"]])
    #expect(resolution.definition.context.thresholds == [ContextModule.Threshold(below: 10, style: "red")])
  }

  // MARK: - Settings keys

  @Test func settingsKeysHoldEachModuleAndItsOptions() {
    let keys = Set(StatusLineDefinition.settingsKeys)
    #expect(keys.contains(["preset"]))
    #expect(keys.contains(["format"]))
    #expect(keys.contains(["directory", "truncation_length"]))
    #expect(keys.contains(["git_status", "ahead"]))
    #expect(keys.contains(["languages", "languages", "*", "detect_extensions"]))
    #expect(keys.contains(["context", "thresholds", "*", "below"]))
    #expect(!keys.contains(["directory", "read_only"]))
    for module in StatusLineModuleID.allCases {
      #expect(keys.contains([module.rawValue, "format"]))
      #expect(keys.contains([module.rawValue, "style"]))
      #expect(keys.contains([module.rawValue, "disabled"]))
    }
  }
}
