import AgentViewKit
import FoundationModelsACP
import PackageFileSupport
import Testing

/// Checks that the R8 tables in `Docs/decisions/permission-ux.md` and
/// `PermissionPresentation` agree, and checks the three functions.
@Suite struct PermissionPresentationTests {
  /// The decision file, relative to the package root.
  private static let decisionPath = "Docs/decisions/permission-ux.md"

  /// The header row of the option table.
  private static let optionHeader = "| kind | position | secondary |"

  /// The header row of the switch-to-auto table.
  private static let switchHeader = "| mode state | shows switch to auto |"

  /// The number of cells in one row of the option table.
  private static let optionColumnCount = 3

  /// The number of cells in one row of the switch-to-auto table.
  private static let switchColumnCount = 2

  /// The name that the option table uses for each kind that the kit does not
  /// know.
  private static let unknownKindName = "unknown"

  /// A wire string that no ACP kind has, as a source-defined fifth option
  /// would send.
  private static let sourceDefinedKind = PermissionOptionKind.unknown("allow_directory")

  /// The four kinds that ACP defines, in the order of the card.
  private static let knownKinds: [PermissionOptionKind] = [.allowOnce, .allowAlways, .rejectOnce, .rejectAlways]

  /// One parsed row of the option table.
  private struct OptionRow: Equatable {
    /// The kind name, without backticks.
    let kind: String
    /// The value of the `position` cell.
    let position: Int
    /// The value of the `secondary` cell.
    let isSecondary: Bool
  }

  /// One parsed row of the switch-to-auto table.
  private struct SwitchRow: Equatable {
    /// The mode state name, without backticks.
    let state: String
    /// The value of the `shows switch to auto` cell.
    let showsSwitchToAuto: Bool
  }

  /// The errors that the row mapping can report.
  private enum TableError: Error {
    /// A row does not have the expected number of cells.
    case wrongCellCount([String])
    /// A yes-or-no cell has a different value.
    case notYesOrNo(String)
    /// A position cell is not an integer.
    case notAnInteger(String)
  }

  // MARK: - Fixtures

  /// The mode state names of the switch-to-auto table, each with the config
  /// options that make that state.
  private static let modeStates: [String: [SessionConfigOption]] = [
    "no mode option": [modelOption],
    "no auto choice": [modeOption(current: "default", values: ["default", "plan"])],
    "current auto": [modeOption(current: "auto", values: claudeCodeModes)],
    "current plan": [modeOption(current: "plan", values: claudeCodeModes)],
    "current other": [modeOption(current: "acceptEdits", values: claudeCodeModes)],
  ]

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

  // MARK: - Table parsing

  /// Reads a `yes` or `no` cell.
  ///
  /// - Parameter cell: The cell value.
  /// - Returns: `true` for `yes`, `false` for `no`.
  /// - Throws: ``TableError/notYesOrNo(_:)`` for a different value.
  private static func flag(_ cell: String) throws -> Bool {
    switch cell {
    case "yes": return true
    case "no": return false
    default: throw TableError.notYesOrNo(cell)
    }
  }

  /// Parses the body rows of one table of the decision file.
  ///
  /// - Parameters:
  ///   - header: The exact header row.
  ///   - columnCount: The number of cells in each row.
  /// - Returns: The cells of each row, in file order.
  /// - Throws: ``MarkdownTable/MissingTable`` when the file has no such
  ///   table, or ``TableError/wrongCellCount(_:)`` for a row of a different
  ///   width.
  private static func cells(header: String, columnCount: Int) throws -> [[String]] {
    let text = try PackageFiles.text(of: decisionPath)
    let rows = try MarkdownTable.rows(in: text, header: header)
    for row in rows where row.count != columnCount {
      throw TableError.wrongCellCount(row)
    }
    return rows
  }

  /// Parses the rows of the option table.
  ///
  /// - Returns: The rows, in file order.
  /// - Throws: An error when the table is missing or a row is not in the
  ///   expected form.
  private static func optionRows() throws -> [OptionRow] {
    try cells(header: optionHeader, columnCount: optionColumnCount).map { cells in
      guard let position = Int(cells[1]) else { throw TableError.notAnInteger(cells[1]) }
      return OptionRow(kind: cells[0], position: position, isSecondary: try flag(cells[2]))
    }
  }

  /// Parses the rows of the switch-to-auto table.
  ///
  /// - Returns: The rows, in file order.
  /// - Throws: An error when the table is missing or a row is not in the
  ///   expected form.
  private static func switchRows() throws -> [SwitchRow] {
    try cells(header: switchHeader, columnCount: switchColumnCount).map { cells in
      SwitchRow(state: cells[0], showsSwitchToAuto: try flag(cells[1]))
    }
  }

  // MARK: - Decision file

  @Test func optionTableHasOneRowForEachKnownKindAndOneUnknownRow() throws {
    let names = try Self.optionRows().map(\.kind)
    let expected = Self.knownKinds.map(\.wireValue) + [Self.unknownKindName]
    #expect(names.sorted() == expected.sorted())
  }

  @Test func eachOptionRowMatchesThePresentation() throws {
    for row in try Self.optionRows() {
      // The `unknown` row name is not a known wire value, so it reads as an
      // unknown kind.
      let kind = PermissionOptionKind(wireValue: row.kind)
      let actual = OptionRow(
        kind: row.kind,
        position: PermissionPresentation.position(of: kind),
        isSecondary: PermissionPresentation.isSecondary(kind: kind)
      )
      #expect(actual == row)
    }
  }

  @Test func optionTableListsTheRowsInPositionOrder() throws {
    let positions = try Self.optionRows().map(\.position)
    #expect(positions == positions.sorted())
    #expect(Set(positions).count == positions.count)
  }

  @Test func switchTableHasOneRowForEachModeState() throws {
    let states = try Self.switchRows().map(\.state)
    #expect(states.sorted() == Self.modeStates.keys.sorted())
  }

  @Test func eachSwitchRowMatchesThePresentation() throws {
    for row in try Self.switchRows() {
      let options = try #require(Self.modeStates[row.state])
      #expect(
        PermissionPresentation.showsSwitchToAuto(configOptions: options) == row.showsSwitchToAuto,
        "mode state \(row.state)"
      )
    }
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
