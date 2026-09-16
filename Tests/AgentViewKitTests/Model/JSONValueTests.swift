import AgentViewKit
import Foundation
import Testing

@Suite struct JSONValueTests {
  /// A nested value that has each case of `JSONValue`.
  private let nested: JSONValue = .object([
    "name": .string("tool"),
    "enabled": .bool(true),
    "count": .number(3),
    "ratio": .number(0.5),
    "missing": .null,
    "tags": .array([.string("a"), .number(1), .null, .object(["deep": .bool(false)])]),
  ])

  // MARK: - Codable

  @Test func aNestedObjectRoundTripsThroughCodable() throws {
    let data = try JSONEncoder().encode(nested)
    let decoded = try JSONDecoder().decode(JSONValue.self, from: data)

    #expect(decoded == nested)
  }

  @Test func eachScalarDecodesToItsCase() throws {
    #expect(try JSONValue(json: "null") == .null)
    #expect(try JSONValue(json: "true") == .bool(true))
    #expect(try JSONValue(json: "false") == .bool(false))
    #expect(try JSONValue(json: "42") == .number(42))
    #expect(try JSONValue(json: "-1.25") == .number(-1.25))
    #expect(try JSONValue(json: "\"hi\"") == .string("hi"))
  }

  @Test func containersDecodeToTheirCases() throws {
    #expect(try JSONValue(json: "[]") == .array([]))
    #expect(try JSONValue(json: "{}") == .object([:]))
    #expect(try JSONValue(json: "[1, \"x\"]") == .array([.number(1), .string("x")]))
  }

  @Test func objectKeyOrderIsNotSignificantForEquality() throws {
    let first = try JSONValue(json: #"{"a": 1, "b": [true]}"#)
    let second = try JSONValue(json: #"{"b": [true], "a": 1}"#)

    #expect(first == second)
    #expect(first.hashValue == second.hashValue)
  }

  @Test func aDecodedValueInsideAnotherCodableTypeKeepsNull() throws {
    struct Envelope: Codable, Equatable {
      var meta: JSONValue
    }
    let decoded = try JSONDecoder().decode(Envelope.self, from: Data(#"{"meta": null}"#.utf8))

    #expect(decoded == Envelope(meta: .null))
  }

  // MARK: - Parsing

  @Test func malformedJSONThrows() {
    #expect(throws: (any Error).self) { try JSONValue(json: "{bad") }
  }

  @Test func emptyTextThrows() {
    #expect(throws: (any Error).self) { try JSONValue(json: "") }
  }

  // MARK: - Subscripts

  @Test func theKeySubscriptReadsAnObjectMember() {
    #expect(nested["name"] == .string("tool"))
    #expect(nested["missing"] == .null)
    #expect(nested["absent"] == nil)
  }

  @Test func theKeySubscriptIsNilForANonObject() {
    #expect(JSONValue.array([.null])["key"] == nil)
    #expect(JSONValue.string("text")["key"] == nil)
  }

  @Test func theIndexSubscriptReadsAnArrayElement() {
    #expect(nested["tags"]?[0] == .string("a"))
    #expect(nested["tags"]?[3]?["deep"] == .bool(false))
  }

  @Test func theIndexSubscriptIsNilOutOfBoundsOrForANonArray() {
    #expect(nested["tags"]?[4] == nil)
    #expect(nested["tags"]?[-1] == nil)
    #expect(nested[0] == nil)
  }

  // MARK: - Conversions

  @Test func boolValueReadsOnlyABool() {
    #expect(JSONValue.bool(true).boolValue == true)
    #expect(JSONValue.number(1).boolValue == nil)
    #expect(JSONValue.string("true").boolValue == nil)
  }

  @Test func doubleValueReadsOnlyANumber() {
    #expect(JSONValue.number(2.5).doubleValue == 2.5)
    #expect(JSONValue.string("2.5").doubleValue == nil)
    #expect(JSONValue.bool(true).doubleValue == nil)
  }

  @Test func intValueReadsOnlyAWholeNumberInRange() {
    #expect(JSONValue.number(7).intValue == 7)
    #expect(JSONValue.number(-3).intValue == -3)
    #expect(JSONValue.number(7.5).intValue == nil)
    #expect(JSONValue.number(1e300).intValue == nil)
    #expect(JSONValue.number(.nan).intValue == nil)
    #expect(JSONValue.string("7").intValue == nil)
  }

  @Test func stringValueReadsOnlyAString() {
    #expect(JSONValue.string("x").stringValue == "x")
    #expect(JSONValue.number(1).stringValue == nil)
    #expect(JSONValue.null.stringValue == nil)
  }

  // MARK: - Printing

  @Test func jsonStringIsCompactWithSortedKeys() {
    let value = JSONValue.object(["b": .array([.bool(true), .null]), "a": .string("x/y")])

    #expect(value.jsonString == #"{"a":"x/y","b":[true,null]}"#)
  }

  @Test func jsonStringOfAScalarIsTheBareFragment() {
    #expect(JSONValue.null.jsonString == "null")
    #expect(JSONValue.string("hi").jsonString == #""hi""#)
    #expect(JSONValue.bool(false).jsonString == "false")
  }

  @Test func jsonStringRoundTripsThroughTheParser() throws {
    #expect(try JSONValue(json: nested.jsonString) == nested)
  }

  @Test func aNonFiniteNumberPrintsAsNull() {
    let value = JSONValue.array([.number(.infinity), .number(.nan), .number(-.infinity)])

    #expect(value.jsonString == "[null,null,null]")
  }

  @Test func prettyPrintedSortsKeysAndIndents() {
    let value = JSONValue.object(["b": .number(1), "a": .object(["d": .null, "c": .bool(true)])])

    let expected = """
      {
        "a" : {
          "c" : true,
          "d" : null
        },
        "b" : 1
      }
      """
    #expect(value.prettyPrinted == expected)
  }

  @Test func prettyPrintedIsStableForTheSameValue() throws {
    let rebuilt = try JSONValue(json: nested.jsonString)
    let outputs = Set((0..<20).map { _ in nested.prettyPrinted } + [rebuilt.prettyPrinted])

    #expect(outputs.count == 1)
  }
}
