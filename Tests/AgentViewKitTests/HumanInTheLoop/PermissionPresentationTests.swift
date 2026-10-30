import AgentViewKit
import AgentViewKitTestSupport
import EditorTestSupport
import FoundationModelsACP
import Testing

/// Checks the three functions of `PermissionPresentation`.
@Suite struct PermissionPresentationTests {
  /// A wire string that no ACP kind has, as a source-defined fifth option
  /// would send.
  private static let sourceDefinedKind = PermissionOptionKind.unknown("allow_directory")

  // MARK: - Fixtures

  /// The Claude Code permission modes that the default mode cycle shows.
  private static let claudeCodeModes = ["default", "acceptEdits", "plan", "auto"]

  /// A config option of the `model` category.
  private static let modelOption = SessionConfigOption(
    configId: SessionConfigId(rawValue: "model"),
    name: "Model",
    category: .model,
    type: makeSelect(current: "fast", options: makeValues(["fast"]))
  )

  /// Makes the JSON value of a flat list of select values.
  ///
  /// - Parameter values: The ids of the values, in order. Each value has its
  ///   id as its name.
  /// - Returns: The JSON array of the values.
  private static func makeValues(_ values: [String]) -> FoundationModelsACP.JSONValue {
    .array(values.map { .object(["value": .string($0), "name": .string($0)]) })
  }

  /// Makes the payload of a select config option.
  ///
  /// - Parameters:
  ///   - current: The id of the selected value.
  ///   - options: The JSON value of the values, flat or in groups.
  /// - Returns: The payload.
  private static func makeSelect(
    current: String, options: FoundationModelsACP.JSONValue
  ) -> SessionConfigOption.Payload {
    .select(SessionConfigSelect(currentValue: SessionConfigValueId(rawValue: current), options: options))
  }

  /// Makes a select config option of the `mode` category with flat choices.
  ///
  /// - Parameters:
  ///   - current: The id of the selected value.
  ///   - values: The ids of the values, in order.
  ///   - id: The id of the option.
  /// - Returns: The config option.
  private static func modeOption(
    current: String,
    values: [String],
    id: String = "mode"
  ) -> SessionConfigOption {
    SessionConfigOption(
      configId: SessionConfigId(rawValue: id),
      name: "Mode",
      category: .mode,
      type: makeSelect(current: current, options: makeValues(values))
    )
  }

  // MARK: - order(for:)

  @Test func orderPutsTheKnownKindsFirstAndKeepsTheUnknownKindsInRequestOrder() {
    let kinds: [PermissionOptionKind] = [
      .rejectAlways, .unknown("second"), .allowOnce, .rejectOnce, .unknown("first"), .allowAlways,
    ]
    let expected: [PermissionOptionKind] = [
      .allowOnce, .allowAlways, .rejectOnce, .rejectAlways, .unknown("second"), .unknown("first"),
    ]
    #expect(PermissionPresentation.order(for: kinds) == expected)
  }

  @Test func orderKeepsRepeatedKinds() {
    let kinds: [PermissionOptionKind] = [.rejectOnce, .allowOnce, .rejectOnce]
    #expect(PermissionPresentation.order(for: kinds) == [.allowOnce, .rejectOnce, .rejectOnce])
  }

  @Test func orderOfNoKindsIsEmpty() {
    #expect(PermissionPresentation.order(for: []).isEmpty)
  }

  @Test func orderOfTheCodexShapeKeepsItsOwnOrder() {
    let kinds: [PermissionOptionKind] = [.allowOnce, .allowAlways, .rejectOnce]
    #expect(PermissionPresentation.order(for: kinds) == kinds)
  }

  // MARK: - isSecondary(kind:)

  @Test func oneTimeKindsArePrimary() {
    #expect(!PermissionPresentation.isSecondary(kind: .allowOnce))
    #expect(!PermissionPresentation.isSecondary(kind: .rejectOnce))
  }

  @Test func keptKindsAndUnknownKindsAreSecondary() {
    #expect(PermissionPresentation.isSecondary(kind: .allowAlways))
    #expect(PermissionPresentation.isSecondary(kind: .rejectAlways))
    #expect(PermissionPresentation.isSecondary(kind: Self.sourceDefinedKind))
  }

  // MARK: - showsSwitchToAuto(configOptions:)

  @Test func noConfigOptionsShowNoSwitch() {
    #expect(!PermissionPresentation.showsSwitchToAuto(configOptions: []))
    #expect(PermissionPresentation.autoModeOption(in: []) == nil)
  }

  @Test func aReadOnlyModeShowsTheSwitch() {
    let option = Self.modeOption(current: "read-only", values: ["read-only", "auto", "full-access"])
    #expect(PermissionPresentation.showsSwitchToAuto(configOptions: [option]))
  }

  @Test func groupedModeChoicesShowTheSwitch() {
    let groups: FoundationModelsACP.JSONValue = .array([
      .object(["groupId": .string("ask"), "name": .string("Ask"), "options": Self.makeValues(["default"])]),
      .object(["groupId": .string("review"), "name": .string("Review"), "options": Self.makeValues(["auto"])]),
    ])
    let option = SessionConfigOption(
      configId: SessionConfigId(rawValue: "mode"),
      name: "Mode",
      category: .mode,
      type: Self.makeSelect(current: "default", options: groups)
    )
    #expect(PermissionPresentation.showsSwitchToAuto(configOptions: [option]))
  }

  @Test func aBooleanModeOptionShowsNoSwitch() {
    let option = SessionConfigOption(
      configId: SessionConfigId(rawValue: "auto"),
      name: "Auto",
      category: .mode,
      type: .boolean(SessionConfigBoolean(currentValue: false))
    )
    #expect(!PermissionPresentation.showsSwitchToAuto(configOptions: [option]))
  }

  @Test func anUnknownModeOptionShowsNoSwitch() {
    let option = SessionConfigOption(
      configId: SessionConfigId(rawValue: "mode"),
      name: "Mode",
      category: .mode,
      type: .unknown("slider", .object([:]))
    )
    #expect(!PermissionPresentation.showsSwitchToAuto(configOptions: [option]))
  }

  @Test func anAutoChoiceOutsideTheModeCategoryShowsNoSwitch() {
    var option = Self.modeOption(current: "default", values: Self.claudeCodeModes)
    option.category = nil
    #expect(!PermissionPresentation.showsSwitchToAuto(configOptions: [option]))
    option.category = .unknown("permissions")
    #expect(!PermissionPresentation.showsSwitchToAuto(configOptions: [option]))
  }

  @Test func theFirstModeOptionDecides() {
    let first = Self.modeOption(current: "default", values: ["default", "plan"], id: "first")
    let second = Self.modeOption(current: "default", values: Self.claudeCodeModes, id: "second")
    #expect(!PermissionPresentation.showsSwitchToAuto(configOptions: [Self.modelOption, first, second]))
    #expect(
      PermissionPresentation.autoModeOption(in: [second, first])?.configId == SessionConfigId(rawValue: "second"))
  }

  @Test func autoModeOptionGivesTheOptionThatTheSwitchSets() {
    let option = Self.modeOption(current: "default", values: Self.claudeCodeModes)
    #expect(PermissionPresentation.autoModeOption(in: [Self.modelOption, option]) == option)
    #expect(
      PermissionPresentation.autoModeValue
        == .id(SessionConfigValueId(rawValue: PermissionPresentation.autoModeID)))
  }
}
