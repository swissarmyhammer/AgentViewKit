import AgentViewKit
import Foundation
import Testing

@Suite struct IdentifierTests {
  @Test func anIdentifierEncodesAsItsString() throws {
    let data = try JSONEncoder().encode(ConfigOptionID("mode"))

    #expect(String(decoding: data, as: UTF8.self) == #""mode""#)
    #expect(try JSONDecoder().decode(ConfigOptionID.self, from: data) == ConfigOptionID("mode"))
  }

  @Test func theDescriptionNamesTheIdentifiedType() {
    #expect(ConfigOptionID("mode").description == "ConfigOption(mode)")
  }

  @Test func bothInitializersGiveTheSameIdentifier() {
    #expect(ConfigOptionID("mode") == ConfigOptionID(rawValue: "mode"))
    #expect(ConfigOptionID("mode").rawValue == "mode")
  }
}
