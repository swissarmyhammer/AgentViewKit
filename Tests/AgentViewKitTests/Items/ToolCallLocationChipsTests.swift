@testable import AgentViewKit
import Testing

/// The location of a tool call chip: its text, which the inspector also
/// shows, and its identity.
@Suite struct ToolCallLocationChipsTests {
  /// The path of the sample file.
  static let path = "/Users/sample/Sources/main.swift"

  /// The line of the sample location.
  static let line = 12

  @Test func aLocationTextWithALineJoinsThePathAndTheLine() {
    #expect(ToolCallLocationChips.Location.text(path: Self.path, line: Self.line) == "\(Self.path):\(Self.line)")
  }

  @Test func aLocationTextWithNoLineIsThePath() {
    #expect(ToolCallLocationChips.Location.text(path: Self.path, line: nil) == Self.path)
  }

  @Test func theIdentityOfALocationIsTheIdentifierOfItsChip() {
    let location = ToolCallLocationChips.Location(path: Self.path, line: Self.line, identifier: "location-0")

    #expect(location.id == "location-0")
  }
}
