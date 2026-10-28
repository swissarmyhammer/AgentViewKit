import FoundationModelsACP
import Testing

@testable import AgentViewKit

/// The JSON text of an ACP value. The text of a location is a part of the
/// style library (`ToolCallLocationChips.Location`), and its tests are in
/// `AgentViewKitStyleTests`.
@Suite struct ACPValueBridgeTests {
  @Test func theACPJSONTextSortsTheKeysAndIndents() {
    let value = FoundationModelsACP.JSONValue.object(["b": .number(1), "a": .string("x/y")])

    #expect(value.prettyPrinted == "{\n  \"a\" : \"x/y\",\n  \"b\" : 1\n}")
  }
}
