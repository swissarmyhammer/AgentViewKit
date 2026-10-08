import Foundation
import PackageFileSupport
import Testing

/// Holds the component list of `README.md` equal to the component inventory
/// of plan.md §9.
///
/// Both lists are Markdown bullets. A bullet names its components in
/// backticks at its start, with a comma or `and` between two names, and then
/// describes them. This suite reads the names of each bullet the same way in
/// both files and compares the two sets.
///
/// The suite also holds the quick starts of the README: the ACP client quick
/// start and the in-process quick start are compiled snippets, and no Swift
/// block of the README uses the thread path of the kit.
@Suite struct ReadmeCoverageTests {
  /// The heading of the inventory in plan.md.
  static let planHeading = "## 9. Component inventory"

  /// The heading of the component list in README.md.
  static let readmeHeading = "## Components"

  /// The prefix of a heading that ends a section.
  static let sectionPrefix = "## "

  /// The bullet form: the leading names of a component bullet.
  ///
  /// A `Regex` is not `Sendable`, so each read makes the value again.
  static var bullet: Regex<(Substring, names: Substring)> {
    /^- (?<names>`[A-Za-z0-9_]+`(?:(?:, | and )`[A-Za-z0-9_]+`)*)/
  }

  /// One name in backticks.
  static var name: Regex<(Substring, name: Substring)> {
    /`(?<name>[A-Za-z0-9_]+)`/
  }

  /// The error when a Markdown text has no section with a heading.
  struct MissingSection: Error {
    /// The heading that the text does not have.
    let heading: String
  }

  /// The lines of a Markdown text from the line `heading` to the next line
  /// that starts with `endPrefix`.
  ///
  /// - Parameters:
  ///   - heading: The heading line, such as `## Components`.
  ///   - markdown: The Markdown text.
  ///   - endPrefix: The prefix of the line that ends the section. The default
  ///     is ``sectionPrefix``, the next heading of level 2.
  /// - Returns: The lines after the heading, before the next line that starts
  ///   with `endPrefix`.
  /// - Throws: ``MissingSection`` when no line is `heading`.
  static func section(_ heading: String, of markdown: String, endingAt endPrefix: String = sectionPrefix) throws
    -> [String]
  {
    let lines = markdown.components(separatedBy: "\n")
    guard let start = lines.firstIndex(of: heading) else {
      throw MissingSection(heading: heading)
    }
    let body = lines[(start + 1)...]
    return Array(body.prefix { !$0.hasPrefix(endPrefix) })
  }

  /// The component names of the bullets of some lines.
  ///
  /// - Parameter lines: The lines of a section.
  /// - Returns: The names, in line order, with a repeat for a name that two
  ///   bullets have.
  static func componentNames(in lines: [String]) -> [String] {
    lines.flatMap { line -> [String] in
      guard let match = line.firstMatch(of: bullet) else { return [] }
      return match.output.names.matches(of: name).map { String($0.output.name) }
    }
  }

  /// The component names of plan.md §9.
  static func planNames() throws -> [String] {
    componentNames(in: try section(planHeading, of: PackageFiles.text(of: "plan.md")))
  }

  /// The component names of the README list.
  static func readmeNames() throws -> [String] {
    componentNames(in: try section(readmeHeading, of: PackageFiles.text(of: "README.md")))
  }

  @Test func thePlanInventoryNamesTheDropInView() throws {
    let names = try Self.planNames()

    #expect(names.contains("AgentThreadView"), "The plan inventory reads as empty: \(names)")
  }

  @Test func theReadmeListsEachComponentOfThePlan() throws {
    let missing = Set(try Self.planNames()).subtracting(try Self.readmeNames())

    #expect(missing.isEmpty, "README.md does not list \(missing.sorted())")
  }

  @Test func theReadmeListsNoComponentOutsideThePlan() throws {
    let extra = Set(try Self.readmeNames()).subtracting(try Self.planNames())

    #expect(extra.isEmpty, "README.md lists \(extra.sorted()), which plan.md §9 does not have")
  }

  @Test func theReadmeListsEachComponentOneTime() throws {
    let names = try Self.readmeNames()

    #expect(Set(names).count == names.count, "README.md lists a component two times: \(names)")
  }

  /// The names of the quick start snippets of the README: the ACP client
  /// and the in-process agent (plan.md §1).
  static let quickStartNames: Set = ["ACPQuickStart", "InProcessQuickStart"]

  /// The symbols of the thread path that no Swift block of the README uses.
  /// The views bind to the client models directly.
  static let threadPathSymbols = ["ACPThreadSource", "AgentThread"]

  @Test func theReadmeHasEachQuickStart() throws {
    let names = Set(try ReadmeSnippets.readmeSnippets().map(\.name))

    #expect(Self.quickStartNames.isSubset(of: names), "README.md has the snippets \(names.sorted())")
  }

  @Test func noSwiftBlockOfTheReadmeUsesTheThreadPath() throws {
    let blocks = ReadmeSnippets.swiftBlocks(in: try ReadmeSnippets.readme())

    for (position, block) in blocks.enumerated() {
      let symbols = Self.threadPathSymbols.filter { block.contains(RemovedVocabularyTests.wholeWord($0)) }
      #expect(symbols.isEmpty, "The Swift block \(position) of README.md uses \(symbols)")
      #expect(
        !block.contains(RemovedVocabularyTests.threadInitializerCall()), "The Swift block \(position) of README.md uses the thread path")
    }
  }

  @Test func sectionTakesTheLinesBeforeTheNextHeading() throws {
    let markdown = "# Title\n\n## One\n- `A`: a\n### Sub\n- `B`: b\n\n## Two\n- `C`: c\n"

    #expect(try Self.section("## One", of: markdown) == ["- `A`: a", "### Sub", "- `B`: b", ""])
  }

  @Test func sectionEndsAtTheGivenPrefix() throws {
    let markdown = "## One\n### One.1\n- `A`: a\n### One.2\n- `B`: b\n"

    #expect(try Self.section("### One.1", of: markdown, endingAt: "#") == ["- `A`: a"])
  }

  @Test func sectionThrowsForAMissingHeading() {
    #expect(throws: MissingSection.self) {
      try Self.section("## None", of: "## One\n")
    }
  }

  @Test func componentNamesReadsTheLeadingNamesOfEachBullet() {
    let lines = [
      "- `AgentThreadView`: the drop-in. *net-new*",
      "- `UserMessageView` and `AssistantMessageView`: content-block based.",
      "- `AgentThread`, `ThreadItem`, `ThreadChange`, the three `ThreadSource`s (§3).",
      "- `ElicitationView`, the `ElicitationFieldView` family, `ElicitationURLConsentView`.",
      "- `ErrorView` renders one block per error kind. `contextSizeExceeded(contextSize:tokenCount:)`: show the counts.",
      "- `ReasoningView`: see group B. `ToolCallView`: see group C.",
      "**A. Thread**",
      "Source: native (build on stock), `reuse`, net-new.",
      "",
    ]

    #expect(
      Self.componentNames(in: lines) == [
        "AgentThreadView",
        "UserMessageView", "AssistantMessageView",
        "AgentThread", "ThreadItem", "ThreadChange",
        "ElicitationView",
        "ErrorView",
        "ReasoningView",
      ])
  }
}
