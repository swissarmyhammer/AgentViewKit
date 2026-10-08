import FoundationModelsACP
import Testing

@testable import AgentViewKit

/// The JSON text of an ACP value, and the text of an ACP location.
@Suite struct ACPValueBridgeTests {
  /// The relative path of the location of the bridge test.
  static let relativePath = "Sources/main.swift"

  /// The line of the location of the bridge test.
  static let locationLine = 12

  @Test func theACPJSONTextSortsTheKeysAndIndents() {
    let value = FoundationModelsACP.JSONValue.object(["b": .number(1), "a": .string("x/y")])

    #expect(value.prettyPrinted == "{\n  \"a\" : \"x/y\",\n  \"b\" : 1\n}")
  }

  @Test func aLocationTextWithALineJoinsThePathAndTheLine() {
    #expect(
      FoundationModelsACP.ToolCallLocation.text(path: Self.relativePath, line: Self.locationLine)
        == "\(Self.relativePath):\(Self.locationLine)")
  }

  @Test func aLocationTextWithNoLineIsThePath() {
    #expect(
      FoundationModelsACP.ToolCallLocation.text(path: Self.relativePath, line: nil)
        == Self.relativePath)
  }
}
