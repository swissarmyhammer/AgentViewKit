import AgentViewKit
import Foundation
import Testing

@Suite struct IdentifierTests {
  @Test func anIdentifierEncodesAsItsString() throws {
    let data = try JSONEncoder().encode(ToolToggleID("mode"))

    #expect(String(decoding: data, as: UTF8.self) == #""mode""#)
    #expect(try JSONDecoder().decode(ToolToggleID.self, from: data) == ToolToggleID("mode"))
  }

  @Test func theDescriptionNamesTheIdentifiedType() {
    #expect(ToolToggleID("mode").description == "ToolToggle(mode)")
  }

  @Test func bothInitializersGiveTheSameIdentifier() {
    #expect(ToolToggleID("mode") == ToolToggleID(rawValue: "mode"))
    #expect(ToolToggleID("mode").rawValue == "mode")
  }
}
