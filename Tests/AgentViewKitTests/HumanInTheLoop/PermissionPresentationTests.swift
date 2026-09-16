import AgentViewKit
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
  private static let sourceDefinedKind = PermissionOption.Kind.unknown("allow_directory")

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
  private static let modeStates: [String: [ConfigOption]] = [
    "no mode option": [modelOption],
    "no auto choice": [modeOption(current: "default", values: ["default", "plan"])],
    "current auto": [modeOption(current: "auto", values: claudeCodeModes)],
    "current plan": [modeOption(current: "plan", values: claudeCodeModes)],
    "current other": [modeOption(current: "acceptEdits", values: claudeCodeModes)],
  ]

  /// The Claude Code permission modes that the default mode cycle shows.
  private static let claudeCodeModes = ["default", "acceptEdits", "plan", "auto"]

  /// A config option of the `model` category.
  private static let modelOption = ConfigOption(
    id: ConfigOptionID("model"),
    name: "Model",
    category: .model,
    kind: .select(current: "fast", choices: .flat([SelectOption(id: "fast", name: "Fast")]))
  )

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
  ) -> ConfigOption {
    ConfigOption(
      id: ConfigOptionID(id),
      name: "Mode",
      category: .mode,
      kind: .select(current: current, choices: .flat(values.map { SelectOption(id: $0, name: $0) }))
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
    let expected = PermissionOption.Kind.knownCases.map(\.wireValue) + [Self.unknownKindName]
    #expect(names.sorted() == expected.sorted())
  }

  @Test func eachOptionRowMatchesThePresentation() throws {
    for row in try Self.optionRows() {
      // The `unknown` row name is not a known wire value, so it reads as an
      // unknown kind.
      let kind = PermissionOption.Kind(wireValue: row.kind)
      let actual = OptionRow(
        kind: row.kind,
        position: PermissionPresentation.position(of: kind),
        isSecondary: PermissionPresentation.isSecondary(kind)
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
    let kinds: [PermissionOption.Kind] = [
      .rejectAlways, .unknown("second"), .allowOnce, .rejectOnce, .unknown("first"), .allowAlways,
    ]
    let expected: [PermissionOption.Kind] = [
      .allowOnce, .allowAlways, .rejectOnce, .rejectAlways, .unknown("second"), .unknown("first"),
    ]
    #expect(PermissionPresentation.order(for: kinds) == expected)
  }

  @Test func orderKeepsRepeatedKinds() {
    let kinds: [PermissionOption.Kind] = [.rejectOnce, .allowOnce, .rejectOnce]
    #expect(PermissionPresentation.order(for: kinds) == [.allowOnce, .rejectOnce, .rejectOnce])
  }

  @Test func orderOfNoKindsIsEmpty() {
    #expect(PermissionPresentation.order(for: []).isEmpty)
  }

  @Test func orderOfTheCodexShapeKeepsItsOwnOrder() {
    let kinds: [PermissionOption.Kind] = [.allowOnce, .allowAlways, .rejectOnce]
    #expect(PermissionPresentation.order(for: kinds) == kinds)
  }

  // MARK: - isSecondary(_:)

  @Test func oneTimeKindsArePrimary() {
    #expect(!PermissionPresentation.isSecondary(.allowOnce))
    #expect(!PermissionPresentation.isSecondary(.rejectOnce))
  }

  @Test func keptKindsAndUnknownKindsAreSecondary() {
    #expect(PermissionPresentation.isSecondary(.allowAlways))
    #expect(PermissionPresentation.isSecondary(.rejectAlways))
    #expect(PermissionPresentation.isSecondary(Self.sourceDefinedKind))
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
    let option = ConfigOption(
      id: ConfigOptionID("mode"),
      name: "Mode",
      category: .mode,
      kind: .select(
        current: "default",
        choices: .grouped([
          SelectGroup(id: "ask", name: "Ask", options: [SelectOption(id: "default", name: "Manual")]),
          SelectGroup(id: "review", name: "Review", options: [SelectOption(id: "auto", name: "Auto")]),
        ])
      )
    )
    #expect(PermissionPresentation.showsSwitchToAuto(configOptions: [option]))
  }

  @Test func aBooleanModeOptionShowsNoSwitch() {
    let option = ConfigOption(
      id: ConfigOptionID("auto"),
      name: "Auto",
      category: .mode,
      kind: .boolean(current: false)
    )
    #expect(!PermissionPresentation.showsSwitchToAuto(configOptions: [option]))
  }

  @Test func anUnknownModeOptionShowsNoSwitch() {
    let option = ConfigOption(
      id: ConfigOptionID("mode"),
      name: "Mode",
      category: .mode,
      kind: .unknown(type: "slider", raw: .object([:]))
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
    #expect(PermissionPresentation.autoModeOption(in: [second, first])?.id == ConfigOptionID("second"))
  }

  @Test func autoModeOptionGivesTheOptionThatTheSwitchSets() {
    let option = Self.modeOption(current: "default", values: Self.claudeCodeModes)
    #expect(PermissionPresentation.autoModeOption(in: [Self.modelOption, option]) == option)
    #expect(PermissionPresentation.autoModeValue == ConfigValue.id("auto"))
  }
}
