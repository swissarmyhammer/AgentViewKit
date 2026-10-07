import FoundationModelsACP
import Testing

@testable import AgentViewKit

/// The ACP value of a kit JSON value, the JSON text of an ACP value, and the
/// text of an ACP location.
@Suite struct ACPValueBridgeTests {
  /// The relative path of the location of the bridge test.
  static let relativePath = "Sources/main.swift"

  /// The line of the location of the bridge test.
  static let locationLine = 12

  @Test func aKitJSONValueGivesTheACPValueWithTheSameJSONForm() {
    let kit = AgentViewKit.JSONValue.object([
      "name": .string("tool"),
      "ratio": .number(0.5),
      "items": .array([.bool(true), .null]),
    ])
    let wire = FoundationModelsACP.JSONValue.object([
      "name": .string("tool"),
      "ratio": .number(0.5),
      "items": .array([.bool(true), .null]),
    ])

    #expect(kit.acpValue == wire)
  }

  @Test func aNumberThatIsNotFiniteGivesTheACPNull() {
    #expect(AgentViewKit.JSONValue.number(.infinity).acpValue == .null)
    #expect(AgentViewKit.JSONValue.array([.number(.nan)]).acpValue == .array([.null]))
  }

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
