import FoundationModelsACP
import Testing

@testable import AgentViewKit

/// The ACP values that the records of the old thread path give to the views,
/// and the JSON text of an ACP value.
@Suite struct ACPValueBridgeTests {
  /// The text of the plan entry of the bridge test.
  static let entryText = "Read the file"

  /// The wire string of a priority that the kit does not know.
  static let unknownPriority = "urgent"

  /// The relative path of the location of the bridge test. A record path can
  /// be relative.
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

  @Test func aKitPlanEntryGivesTheACPEntryWithTheSameValues() {
    let kit = AgentViewKit.PlanEntry(
      content: Self.entryText, priority: .unknown(Self.unknownPriority), status: .inProgress)

    #expect(
      kit.acpEntry
        == FoundationModelsACP.PlanEntry(
          content: Self.entryText, priority: .unknown(Self.unknownPriority), status: .inProgress))
  }

  @Test func aKitLocationGivesTheACPLocationWithTheSamePathAndLine() {
    let kit = AgentViewKit.ToolCallLocation(path: Self.relativePath, line: Self.locationLine)

    #expect(
      kit.acpLocation
        == FoundationModelsACP.ToolCallLocation(
          path: AbsolutePath(rawValue: Self.relativePath), line: Self.locationLine))
  }

  @Test func theACPJSONTextSortsTheKeysAndIndents() {
    let value = FoundationModelsACP.JSONValue.object(["b": .number(1), "a": .string("x/y")])

    #expect(value.prettyPrinted == "{\n  \"a\" : \"x/y\",\n  \"b\" : 1\n}")
  }
}
