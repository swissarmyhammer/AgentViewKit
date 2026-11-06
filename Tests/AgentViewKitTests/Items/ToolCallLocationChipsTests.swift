@testable import AgentViewKit
import Testing

/// The location of a tool call chip: its identity.
@Suite struct ToolCallLocationChipsTests {
  /// The path of the sample file.
  static let path = "/Users/sample/Sources/main.swift"

  /// The line of the sample location.
  static let line = 12

  @Test func theIdentityOfALocationIsTheIdentifierOfItsChip() {
    let location = ToolCallLocationChips.Location(path: Self.path, line: Self.line, identifier: "location-0")

    #expect(location.id == "location-0")
  }
}
