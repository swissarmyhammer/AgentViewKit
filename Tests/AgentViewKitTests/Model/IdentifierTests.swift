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
    #expect(TerminalID("t1").description == "TerminalRecord(t1)")
    #expect(ConfigOptionID("mode").description == "ConfigOption(mode)")
    #expect(PlanID("p1").description == "Plan(p1)")
  }

  @Test func bothInitializersGiveTheSameIdentifier() {
    #expect(TerminalID("t1") == TerminalID(rawValue: "t1"))
    #expect(TerminalID("t1").rawValue == "t1")
  }
}
