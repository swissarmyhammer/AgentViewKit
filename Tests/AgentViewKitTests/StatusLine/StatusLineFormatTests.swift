@testable import AgentViewKit
import Testing

/// The format strings of the status line (D194 (e)).
@Suite struct StatusLineFormatTests {
  typealias Node = StatusLineFormat.Node

  @Test func referencesAndLiteralsParseInOrder() throws {
    let format = try StatusLineFormat(parsing: "$directory on $git_branch$git_status")
    #expect(
      format.nodes == [
        .reference("directory"), .literal(" on "), .reference("git_branch"), .reference("git_status"),
      ])
  }

  @Test func braceReferenceEndsAtTheBrace() throws {
    let format = try StatusLineFormat(parsing: "+${count}x")
    #expect(format.nodes == [.literal("+"), .reference("count"), .literal("x")])
  }

  @Test func escapesAreLiteralCharacters() throws {
    let format = try StatusLineFormat(parsing: #"\$5 \(a\) \\"#)
    #expect(format.nodes == [.literal(#"$5 (a) \"#)])
  }

  @Test func dollarWithNoNameIsLiteral() throws {
    let format = try StatusLineFormat(parsing: "a $ b")
    #expect(format.nodes == [.literal("a $ b")])
  }

  @Test func groupsNest() throws {
    let format = try StatusLineFormat(parsing: "($state( $current/$total))")
    #expect(
      format.nodes == [
        .group([
          .reference("state"),
          .group([.literal(" "), .reference("current"), .literal("/"), .reference("total")]),
        ])
      ])
    #expect(format.references == ["state", "current", "total"])
  }

  @Test(arguments: ["(a", "a)", "${count", "${}", "${a-b}", "end\\"])
  func wrongFormatIsAParseError(text: String) {
    #expect(throws: StatusLineFormat.ParseError.self) { try StatusLineFormat(parsing: text) }
  }

  @Test func unknownReferenceFailsTheCheck() throws {
    let format = try StatusLineFormat(parsing: "$path $nope")
    #expect(throws: StatusLineFormat.ParseError.self) { try format.validate(references: ["path"]) }
    try format.validate(references: ["path", "nope"])
  }

  @Test func groupWithNoValueShowsNothing() {
    let format: StatusLineFormat = "a($b c)d"
    #expect(format.renderText { _ in nil } == "ad")
    #expect(format.renderText { $0 == "b" ? "B" : nil } == "aB cd")
  }

  @Test func groupShowsWhenANestedReferenceHasAValue() {
    let format: StatusLineFormat = "($state( $current/$total))"
    #expect(format.renderText { _ in nil } == "")
    #expect(format.renderText { $0 == "state" ? "MERGING" : nil } == "MERGING")
    #expect(
      format.renderText { ["state": "REBASING", "current": "1", "total": "3"][$0] } == "REBASING 1/3")
  }

  @Test func missingModulesLeaveNoDoubleSpace() {
    let format: StatusLineFormat = "$directory $git_branch$git_status $languages $session"
    let values = ["directory": "~/code", "session": "Chat"]
    #expect(format.renderText { values[$0] } == "~/code Chat")
  }

  @Test func lineHasNoSpaceAtItsEnds() {
    let format: StatusLineFormat = "$a $b $c"
    #expect(format.renderText { $0 == "b" ? "B" : nil } == "B")
  }

  @Test func emptyTextIsNoValue() {
    let format: StatusLineFormat = "($a)x"
    #expect(format.renderText { _ in "" } == "x")
  }

  @Test func formatCodesAsItsText() throws {
    let format: StatusLineFormat = "$a ($b)"
    let decoded = try StatusLineTestCoding.roundTrip(format)
    #expect(decoded == format)
    #expect(try StatusLineTestCoding.jsonText(format) == #""$a ($b)""#)
  }
}
