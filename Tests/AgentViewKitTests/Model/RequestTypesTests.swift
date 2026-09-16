import AgentViewKit
import Foundation
import Testing

@Suite struct RequestTypesTests {
  /// Each known ACP permission option kind and the case that it gives.
  nonisolated private static let knownKinds: [(wireValue: String, kind: PermissionOption.Kind)] = [
    ("allow_once", .allowOnce),
    ("allow_always", .allowAlways),
    ("reject_once", .rejectOnce),
    ("reject_always", .rejectAlways),
  ]

  /// A permission option in the ACP v2 `PermissionOption` shape.
  nonisolated private static let optionFixture = """
    {"optionId": "allow-1", "name": "Allow once", "kind": "allow_once"}
    """

  /// The mode fields of a form request in the ACP v2 `elicitation/create`
  /// shape.
  nonisolated private static let formModeFixture = """
    {
      "sessionId": "s1",
      "message": "Which branch?",
      "mode": "form",
      "requestedSchema": {
        "type": "object",
        "properties": {"branch": {"type": "string"}},
        "required": ["branch"]
      }
    }
    """

  /// The mode fields of a URL request in the ACP v2 `elicitation/create`
  /// shape.
  nonisolated private static let urlModeFixture = """
    {
      "sessionId": "s1",
      "toolCallId": "call-1",
      "message": "Sign in to continue.",
      "mode": "url",
      "url": "https://example.com/auth?state=abc",
      "elicitationId": "el-7"
    }
    """

  /// An agent method in the ACP v2 `AuthMethod` shape.
  nonisolated private static let agentMethodFixture = """
    {"type": "agent", "methodId": "oauth", "name": "Sign in", "description": "Use your account."}
    """

  /// A terminal method in the ACP v2 `AuthMethod` shape.
  nonisolated private static let terminalMethodFixture = """
    {
      "type": "terminal",
      "methodId": "tui",
      "name": "Sign in with the terminal",
      "args": ["--login", "--no-browser"],
      "env": [
        {"name": "LOGIN_MODE", "value": "device"},
        {"name": "HOME_HINT", "value": "/tmp/h"}
      ]
    }
    """

  // MARK: - Permission

  @Test(arguments: knownKinds)
  func aKnownOptionKindGivesItsCase(wireValue: String, kind: PermissionOption.Kind) {
    #expect(PermissionOption.Kind(wireValue: wireValue) == kind)
    #expect(kind.wireValue == wireValue)
  }

  @Test(arguments: ["_allow_folder", "Allow_Once", "allow", ""])
  func anUnknownOptionKindGivesUnknown(wireValue: String) {
    let kind = PermissionOption.Kind(wireValue: wireValue)

    #expect(kind == .unknown(wireValue))
    #expect(kind.wireValue == wireValue)
  }

  @Test func theKnownOptionKindsHaveDistinctWireValues() {
    let wireValues = PermissionOption.Kind.knownCases.map(\.wireValue)

    #expect(Set(wireValues).count == wireValues.count)
    #expect(wireValues.count == Self.knownKinds.count)
  }

  @Test func anOptionDecodesTheACPWireForm() throws {
    let option = try decode(PermissionOption.self, from: Self.optionFixture)

    #expect(option == PermissionOption(id: PermissionOptionID("allow-1"), name: "Allow once", kind: .allowOnce))
  }

  @Test func anOptionRoundTripsThroughJSON() throws {
    let option = PermissionOption(id: PermissionOptionID("x"), name: "Always", kind: .unknown("_folder"))

    #expect(try roundTrip(option) == option)
  }

  @Test func aDecisionHasNoCommentByDefault() {
    let decision = PermissionDecision(outcome: .selected(PermissionOptionID("allow-1")))

    #expect(decision.comment == nil)
    #expect(decision != PermissionDecision(outcome: .cancelled))
  }

  // MARK: - Elicitation

  @Test func aFormModeDecodesItsSchema() throws {
    let mode = try decode(ElicitationRequest.Mode.self, from: Self.formModeFixture)
    let schema = try JSONValue(
      json: #"{"type": "object", "properties": {"branch": {"type": "string"}}, "required": ["branch"]}"#
    )

    #expect(mode == .form(requestedSchema: schema))
  }

  @Test func aURLModeDecodesItsURLAndElicitationID() throws {
    let mode = try decode(ElicitationRequest.Mode.self, from: Self.urlModeFixture)
    let url = try #require(URL(string: "https://example.com/auth?state=abc"))

    #expect(mode == .url(url, elicitationId: "el-7"))
  }

  @Test(arguments: [formModeFixture, urlModeFixture])
  func aModeRoundTripsThroughJSON(fixture: String) throws {
    let mode = try decode(ElicitationRequest.Mode.self, from: fixture)

    #expect(try roundTrip(mode) == mode)
  }

  @Test(arguments: [
    #"{"mode": "_wizard", "message": "Go"}"#,
    #"{"message": "Go", "requestedSchema": {}}"#,
    #"{"mode": "url", "url": "https://example.com"}"#,
  ])
  func aModeWithAnUnknownOrIncompleteShapeDoesNotDecode(fixture: String) {
    #expect(throws: DecodingError.self) {
      try decode(ElicitationRequest.Mode.self, from: fixture)
    }
  }

  // MARK: - Auth methods

  @Test func anAgentMethodDecodesItsFields() throws {
    let method = try decode(AuthMethod.self, from: Self.agentMethodFixture)

    #expect(
      method == .agent(.init(id: AuthMethodID("oauth"), name: "Sign in", description: "Use your account."))
    )
  }

  @Test func aTerminalMethodKeepsItsArgsAndEnv() throws {
    let method = try decode(AuthMethod.self, from: Self.terminalMethodFixture)

    #expect(
      method
        == .terminal(
          .init(
            id: AuthMethodID("tui"),
            name: "Sign in with the terminal",
            args: ["--login", "--no-browser"],
            env: ["LOGIN_MODE": "device", "HOME_HINT": "/tmp/h"]
          )
        )
    )
  }

  @Test func aTerminalMethodSkipsItemsWithTheWrongShape() throws {
    let json = """
      {
        "type": "terminal", "methodId": "tui", "name": "TUI", "description": 4,
        "args": ["--a", 3],
        "env": [{"name": "A", "value": "1"}, {"name": "B"}, "C", {"name": "A", "value": "2"}]
      }
      """
    let method = try decode(AuthMethod.self, from: json)

    #expect(method == .terminal(.init(id: AuthMethodID("tui"), name: "TUI", args: ["--a"], env: ["A": "2"])))
  }

  @Test func aTerminalMethodWithAMissingOrWrongTypeListHasEmptyValues() throws {
    let json = #"{"type": "terminal", "methodId": "tui", "name": "TUI", "args": "--a"}"#
    let method = try decode(AuthMethod.self, from: json)

    #expect(method == .terminal(.init(id: AuthMethodID("tui"), name: "TUI")))
  }

  @Test func anUnknownMethodTypeGivesUnknown() throws {
    let method = try decode(AuthMethod.self, from: #"{"type": "_passkey", "methodId": "p", "name": "P"}"#)

    #expect(method == .unknown("_passkey"))
  }

  @Test(arguments: [agentMethodFixture, terminalMethodFixture, #"{"type": "_passkey"}"#])
  func aMethodRoundTripsThroughJSON(fixture: String) throws {
    let method = try decode(AuthMethod.self, from: fixture)

    #expect(try roundTrip(method) == method)
  }

  @Test func aTerminalMethodEncodesEnvAsANameOrderedList() throws {
    let method = AuthMethod.terminal(.init(id: AuthMethodID("t"), name: "T", env: ["B": "2", "A": "1"]))
    let json = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(method))

    #expect(
      json["env"]
        == .array([
          .object(["name": .string("A"), "value": .string("1")]),
          .object(["name": .string("B"), "value": .string("2")]),
        ])
    )
    #expect(json["type"] == .string("terminal"))
    #expect(json["methodId"] == .string("t"))
  }

  @Test(arguments: [
    #"{"methodId": "oauth", "name": "Sign in"}"#,
    #"{"type": "agent", "name": "Sign in"}"#,
    #"{"type": "terminal", "methodId": "tui"}"#,
  ])
  func aMethodWithAMissingRequiredKeyDoesNotDecode(fixture: String) {
    #expect(throws: DecodingError.self) {
      try decode(AuthMethod.self, from: fixture)
    }
  }

  // MARK: - Helpers

  /// Decodes a value from JSON text.
  private func decode<Value: Decodable>(_ type: Value.Type, from json: String) throws -> Value {
    try JSONDecoder().decode(type, from: Data(json.utf8))
  }

  /// Encodes a value to JSON and decodes it again.
  private func roundTrip<Value: Codable>(_ value: Value) throws -> Value {
    try JSONDecoder().decode(Value.self, from: JSONEncoder().encode(value))
  }
}
