import Foundation
import FoundationModelsACP
import Testing

@testable import AgentViewKit

/// The members that the kit adds to the ACP `JSONValue`: the parse and encode
/// initializers, the subscripts, the scalar readers and the compact text.
@Suite struct ACPJSONValueMembersTests {
  /// A nested value that has each case of `JSONValue`.
  private let nested: JSONValue = .object([
    "name": .string("tool"),
    "enabled": .bool(true),
    "count": .number(3),
    "ratio": .number(0.5),
    "missing": .null,
    "tags": .array([.string("a"), .number(1), .null, .object(["deep": .bool(false)])]),
  ])

  // MARK: - Encoding

  /// A value that always fails to encode.
  private struct FailingValue: Encodable {
    func encode(to encoder: any Encoder) throws {
      throw EncodingError.invalidValue(
        self, EncodingError.Context(codingPath: [], debugDescription: "The value does not encode."))
    }
  }

  /// A value that encodes as an object.
  private struct Pair: Encodable {
    var name = "tool"
    var enabled = true
  }

  @Test func anEncodableValueGivesItsJSONForm() throws {
    let expected: JSONValue = .object(["name": .string("tool"), "enabled": .bool(true)])

    #expect(try JSONValue(encoding: Pair()) == expected)
    #expect(JSONValue.encodedOrNull(Pair()) == expected)
  }

  @Test func aValueThatDoesNotEncodeThrowsOrGivesNull() {
    #expect(throws: EncodingError.self) {
      try JSONValue(encoding: FailingValue())
    }
    #expect(JSONValue.encodedOrNull(FailingValue()) == .null)
  }

  // MARK: - Parsing

  @Test func eachScalarParsesToItsCase() throws {
    #expect(try JSONValue(json: "null") == .null)
    #expect(try JSONValue(json: "true") == .bool(true))
    #expect(try JSONValue(json: "42") == .number(42))
    #expect(try JSONValue(json: "\"hi\"") == .string("hi"))
  }

  @Test func containersParseToTheirCases() throws {
    #expect(try JSONValue(json: "[]") == .array([]))
    #expect(try JSONValue(json: "{}") == .object([:]))
    #expect(try JSONValue(json: "[1, \"x\"]") == .array([.number(1), .string("x")]))
  }

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

  // MARK: - Scalar readers

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

  // MARK: - Compact text

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
}
