@testable import AgentViewKit
import Foundation
import Testing

/// The styles and the symbols of the status line (D194 (i)).
@Suite struct StatusLineStyleTests {
  @Test func colorAndModifiersParseInAnyOrder() throws {
    let style = try StatusLineStyle(parsing: "bold  cyan italic")
    #expect(style.color == .ansi(.cyan))
    #expect(style.modifiers == [.bold, .italic])
    #expect(style.text == "cyan bold italic")
  }

  @Test func brightColorAndRoleParse() throws {
    #expect(try StatusLineStyle(parsing: "bright_blue").color == .ansi(.brightBlue))
    #expect(try StatusLineStyle(parsing: "dimmed secondary").color == .role(.secondary))
    #expect(try StatusLineStyle(parsing: "dim").modifiers == [.dimmed])
  }

  @Test func emptyTextIsThePlainStyle() throws {
    #expect(try StatusLineStyle(parsing: "") == .plain)
  }

  @Test(arguments: ["blink", "red green", "#ff0000", "bg:red"])
  func wrongWordIsAParseError(text: String) {
    #expect(throws: StatusLineStyle.ParseError.self) { try StatusLineStyle(parsing: text) }
  }

  @Test func wrongStyleIsADecodeError() {
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(StatusLineStyle.self, from: Data(#""rainbow""#.utf8))
    }
  }

  @Test func symbolKindsComeFromTheirPrefix() {
    #expect(StatusLineSymbol(text: "sf:folder") == .sfSymbol("folder"))
    #expect(StatusLineSymbol(text: "icon:swift") == .icon("swift"))
    #expect(StatusLineSymbol(text: "⎇ ") == .text("⎇ "))
    #expect(StatusLineSymbol.icon("rust").text == "icon:rust")
  }

  @Test func symbolCodesAsItsText() throws {
    let symbol = StatusLineSymbol.sfSymbol("cpu")
    #expect(try StatusLineTestCoding.roundTrip(symbol) == symbol)
    #expect(try StatusLineTestCoding.jsonText(symbol) == #""sf:cpu""#)
  }
}

/// The JSON coding helpers of the status line tests.
enum StatusLineTestCoding {
  /// Encodes and decodes a value.
  static func roundTrip<T: Codable>(_ value: T) throws -> T {
    try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value))
  }

  /// The JSON text of a value.
  static func jsonText<T: Encodable>(_ value: T) throws -> String {
    String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
  }
}
