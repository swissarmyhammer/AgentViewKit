import AgentViewKitTestSupport
import AgentViewKitDemoSupport
import EditorCommandsUI
import EditorInspector
import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// The config views over a `SessionModel` (plan.md §3.2 "Last-value
/// state", "Other requests").
///
/// Each test shows a ``ConfigOptionsView`` or a ``PermissionModePicker`` over
/// the model of a ``ScriptedSession``. The scripted agent gives the options
/// in the `session/new` response or in a `config_option_update`. A change in
/// a view sends `session/set_config_option`, and the test reads the frame
/// that the agent got. The test waits for the frame, or for the model value
/// that a frame of the agent is certain to change, and then makes one render
/// pass before it reads the view.
///
/// The form style is an EditorKit `InspectorView`, so the tests read and press
/// its rows by EditorKit's accessibility identifiers (``row(_:_:)``). A test
/// reads the choice of a choice row from its accessibility value. The harness
/// cannot choose an item of a pop-up or press a segment, so a test chooses a
/// value through its named accessibility action: each value of an EditorKit
/// `ChoiceField` is an action named by the value.
@Suite(.serialized, .hostedSerially) @MainActor struct ConfigOptionsSessionModelHostedTests {
  /// A size that shows the full form.
  static let size = CGSize(width: 480, height: 600)

  /// The method of the set-config-option request.
  static let setMethod = "session/set_config_option"

  /// The accessibility value of a selected choice.
  static let selected = "1"

  /// The accessibility value of a choice that is not selected.
  static let notSelected = "0"

  /// The id of the model option.
  static let modelID = SessionConfigId(rawValue: "model")

  /// The id of the web search option.
  static let webID = SessionConfigId(rawValue: "web")

  /// The id of the mode option.
  static let modeID = SessionConfigId(rawValue: "mode")

  /// A model option with its values in two groups, `fast-1` selected.
  static let modelOption = #"""
    {"configId": "model", "name": "Model", "category": "model", "type": "select",
     "currentValue": "fast-1",
     "options": [
       {"groupId": "fast", "name": "Fast Models", "options": [{"value": "fast-1", "name": "Fast One"}]},
       {"groupId": "deep", "name": "Deep Models", "options": [{"value": "deep-1", "name": "Deep One"}]}]}
    """#

  /// A boolean option with no category, set off.
  static let webOption = #"{"configId": "web", "name": "Web Search", "type": "boolean", "currentValue": false}"#

  /// A mode option with two flat values.
  ///
  /// - Parameter current: The id of the selected value.
  /// - Returns: The JSON text of the option.
  static func modeOption(current: String) -> String {
    #"""
    {"configId": "mode", "name": "Mode", "category": "mode", "type": "select",
     "currentValue": "\#(current)",
     "options": [{"value": "ask", "name": "Ask"}, {"value": "auto", "name": "Auto"}]}
    """#
  }

  /// The `session/new` result with options.
  ///
  /// - Parameter options: The JSON text of each option.
  /// - Returns: The JSON text of the result.
  static func newSessionResult(options: [String]) -> String {
    #"{"sessionId": "\#(ScriptedSession.sessionID)", "configOptions": [\#(options.joined(separator: ","))]}"#
  }

  /// A `config_option_update` value with options.
  ///
  /// - Parameter options: The JSON text of each option.
  /// - Returns: The JSON text of the update.
  static func configUpdate(options: [String]) -> String {
    #"{"sessionUpdate": "config_option_update", "configOptions": [\#(options.joined(separator: ","))]}"#
  }

  /// The options of the most tests: model, web search, and mode `ask`.
  static let allOptions = [modelOption, webOption, modeOption(current: "ask")]

  /// The `session/update` frame of a `config_option_update` for the session.
  ///
  /// - Parameter options: The JSON text of each option.
  /// - Returns: The JSON text of the frame.
  /// - Throws: The error of the JSON parser when an option is not valid JSON.
  static func configUpdateFrame(options: [String]) throws -> String {
    try ScriptedSession.sessionUpdateFrame(update: JSONValue(json: configUpdate(options: options)))
  }

  /// Opens a scripted session whose `session/new` result has options.
  ///
  /// - Parameters:
  ///   - options: The JSON text of each option.
  ///   - configure: Changes the agent before it starts.
  /// - Returns: The session.
  /// - Throws: The error of `initialize` or of `session/new`.
  static func openSession(
    options: [String] = allOptions, configure: (ScriptedWireAgent) -> Void = { _ in }
  ) async throws -> ScriptedSession {
    try await ScriptedSession.open { agent in
      agent.results["session/new"] = newSessionResult(options: options)
      configure(agent)
    }
  }

  /// Shows the form and the mode picker of a session.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - requestStartReport: The report that gets the method of each request
  ///     that a view starts, or `nil`.
  /// - Returns: The harness, after one render pass.
  static func mount(
    session: ScriptedSession, requestStartReport: ObservationReport<String>? = nil
  ) -> HostedViewHarness<some View> {
    let harness = HostedViewHarness(size: size) {
      VStack {
        ConfigOptionsView(session: session.model, style: .form)
        PermissionModePicker(session: session.model)
      }
      .environment(\.requestStartReport, requestStartReport)
    }
    harness.render()
    return harness
  }

  /// The name of the value `fast-1` of the model option.
  static let fastChoice = "Fast One"

  /// The name of the value `deep-1` of the model option.
  static let deepChoice = "Deep One"

  /// The name of the value `ask` of the mode option.
  static let askChoice = "Ask"

  /// The name of the value `auto` of the mode option.
  static let autoChoice = "Auto"

  /// The object id of the block of the form: EditorKit names a block of an
  /// `Identifiable` object by the description of its id, the `SessionId` of
  /// the scripted session.
  static let sessionObject = InspectorScheme.escaped(
    String(describing: SessionId(rawValue: ScriptedSession.sessionID)))

  /// The EditorKit identifier of the block of the form: the view and the
  /// session.
  static let block = InspectorScheme.blockIdentifier(view: ConfigOptionsView.viewIdentifier, object: sessionObject)

  /// The EditorKit accessibility identifier of the row of an option in the
  /// form: the view, the session, the category section and the option.
  ///
  /// - Parameters:
  ///   - section: The id of the category section, such as `model`.
  ///   - id: The id of the option.
  /// - Returns: The identifier, such as
  ///   `inspection:config-options/object:…/field:model.model`.
  static func row(_ section: String, _ id: SessionConfigId) -> String {
    InspectorScheme.rowIdentifier(
      view: ConfigOptionsView.viewIdentifier, object: sessionObject, group: section, field: id.rawValue)
  }

  /// The name row of the form, which EditorKit adds above the rows.
  static let nameRow = InspectorScheme.identifier(of: "name", inRow: block)

  /// The row of the model option.
  static let modelRow = row("model", modelID)

  /// The row of the mode option.
  static let modeRow = row("mode", modeID)

  /// The row of the web search option.
  static let webRow = row(ConfigOptionsView.uncategorizedSectionID, webID)

  /// The choice that the picker row of `identifier` shows, or the state of
  /// its toggle row: `1` on and `0` off.
  ///
  /// - Parameters:
  ///   - identifier: The identifier of the row.
  ///   - harness: The harness of the view.
  /// - Returns: The accessibility value of the row, or `nil` when no row has
  ///   the identifier.
  static func rowValue(_ identifier: String, in harness: HostedViewHarness<some View>) -> String? {
    harness.element(identifier: identifier)?.value
  }

  /// Presses the toggle row of the web search option, and waits for the
  /// request that the commit of the row starts.
  ///
  /// - Parameters:
  ///   - harness: The harness of the view.
  ///   - starts: The recorder of the request starts.
  /// - Throws: When the row is not there or does not press.
  static func pressWebSearch(in harness: HostedViewHarness<some View>, starts: ReportRecorder<String>) async throws {
    try harness.press(identifier: webRow)
    // The row commits in a task of its own, which starts the request.
    await ObservationWait.until { !starts.values.isEmpty }
    try #require(starts.values == [setMethod])
  }

  /// Chooses the value `name` of the choice field of `identifier` through
  /// its named accessibility action, and waits for the request that the
  /// change starts.
  ///
  /// - Parameters:
  ///   - name: The name of the value.
  ///   - identifier: The identifier of the field.
  ///   - harness: The harness of the view.
  ///   - session: The scripted session that gets the request.
  /// - Returns: The `params` of the request.
  /// - Throws: When the field is not there, has no action `name`, or sends
  ///   no request.
  static func choose(
    _ name: String, in identifier: String, harness: HostedViewHarness<some View>, session: ScriptedSession
  ) async throws -> JSONValue {
    try harness.performCustomAction(named: name, identifier: identifier)
    await ObservationWait.until { !setParams(in: session).isEmpty }
    return try #require(setParams(in: session).first)
  }

  /// The segment of the value `name` in the permission-mode picker.
  ///
  /// - Parameters:
  ///   - name: The name of the value.
  ///   - harness: The harness of the view.
  /// - Returns: The segment, or `nil` when the picker has none of the name.
  static func modeSegment(_ name: String, in harness: HostedViewHarness<some View>) -> AccessibilityElementSnapshot? {
    harness.elements(under: PermissionModePicker.pickerIdentifier).first { $0.label == name }
  }

  /// Shows the menu control of each option of a session, as the menu of
  /// ``ConfigOptionsView/Style/menu`` holds them. A hosted window cannot
  /// open the menu, so the test shows its controls.
  ///
  /// - Parameter session: The scripted session.
  /// - Returns: The harness, after one render pass.
  static func mountMenuControls(session: ScriptedSession) -> HostedViewHarness<some View> {
    let options = session.model.configOptions ?? []
    let harness = HostedViewHarness(size: size) {
      VStack {
        ForEach(options, id: \.configId) { option in
          ConfigOptionControl(option: option, session: session.model)
        }
      }
    }
    harness.render()
    return harness
  }

  /// The `params` of each set-config-option frame that the agent got.
  ///
  /// - Parameter session: The scripted session.
  /// - Returns: The params, in arrival order.
  static func setParams(in session: ScriptedSession) -> [JSONValue] {
    session.agent.messages(method: setMethod).compactMap { $0["params"] }
  }

  // MARK: - Grouping

  @Test func sectionsFollowTheCategoryOrderAndDropUnknownTypes() {
    let boolean = SessionConfigOption.Payload.boolean(SessionConfigBoolean(currentValue: true))
    let options = [
      SessionConfigOption(configId: Self.webID, name: "Web Search", type: boolean),
      SessionConfigOption(
        configId: SessionConfigId(rawValue: "temperature"), name: "Temperature",
        category: .modelConfig, type: boolean),
      SessionConfigOption(
        configId: SessionConfigId(rawValue: "style"), name: "Style", category: .unknown("style"),
        type: boolean),
      SessionConfigOption(
        configId: SessionConfigId(rawValue: "thought"), name: "Thought", category: .thoughtLevel,
        type: boolean),
      SessionConfigOption(
        configId: SessionConfigId(rawValue: "range"), name: "Range", category: .model,
        type: .unknown("range", .null)),
      SessionConfigOption(configId: Self.modeID, name: "Mode", category: .mode, type: boolean),
    ]

    let sections = ConfigOptionsView.sections(for: options)

    #expect(sections.map(\.id) == ["mode", "thought_level", "model_config", "uncategorized"])
    #expect(
      sections.map { $0.options.map(\.configId.rawValue) } == [
        ["mode"], ["thought"], ["temperature"], ["web", "style"],
      ])
    #expect(sections.map(\.title) == ["Mode", "Thought Level", "Model Settings", "Other"])
  }

  // MARK: - Hidden

  @Test func withNoReportedOptionsTheControlsAreHidden() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = Self.mount(session: session)
    defer { harness.close() }

    #expect(session.model.configOptions == nil)
    #expect(harness.element(identifier: Self.webRow) == nil)
    #expect(harness.element(identifier: PermissionModePicker.pickerIdentifier) == nil)
  }

  @Test func withAnEmptyOptionListTheControlsAreHidden() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = Self.mount(session: session)
    defer { harness.close() }
    let model = session.model
    #expect(harness.element(identifier: Self.webRow) != nil)

    try await session.sendUpdate(Self.configUpdate(options: []))
    await harness.render { model.configOptions?.isEmpty == true }

    #expect(harness.element(identifier: Self.webRow) == nil)
    #expect(harness.element(identifier: PermissionModePicker.pickerIdentifier) == nil)
  }

  // MARK: - Form

  @Test func theFormShowsOneRowForEachOptionInTheCategoryOrder() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = Self.mount(session: session)
    defer { harness.close() }

    let rows = harness.accessibilityElements().compactMap(\.identifier).filter {
      $0.hasPrefix(Self.block) && $0 != Self.nameRow
    }
    #expect(rows == [Self.modeRow, Self.modelRow, Self.webRow])
  }

  @Test func aSelectRowShowsTheNameOfItsValue() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = Self.mount(session: session)
    defer { harness.close() }

    #expect(Self.rowValue(Self.modelRow, in: harness) == Self.fastChoice)
  }

  @Test func aSelectRowWithGroupsOffersEachValueAsANamedAction() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = Self.mount(session: session)
    defer { harness.close() }

    #expect(harness.element(identifier: Self.modelRow)?.customActions == [Self.fastChoice, Self.deepChoice])
  }

  // MARK: - Set config option

  /// The agent holds its answer, and after the answer it sends the option
  /// value that it reports. The report changes the options of the model, so
  /// the test waits for that change, and then renders the view.
  @Test func aChangeSendsSetConfigOptionAndTheViewShowsTheValueThatTheModelReports() async throws {
    let reported = Self.webOption.replacingOccurrences(of: #""currentValue": false"#, with: #""currentValue": true"#)
    let reportedFrame = try Self.configUpdateFrame(options: [Self.modelOption, reported, Self.modeOption(current: "ask")])
    let session = try await Self.openSession { agent in
      agent.heldMethods = [Self.setMethod]
      agent.followUps[Self.setMethod] = { _, _ in [reportedFrame] }
    }
    defer { session.close() }
    let starts = ReportRecorder<String>()
    let harness = Self.mount(session: session, requestStartReport: starts.report)
    defer { harness.close() }
    let model = session.model

    try await Self.pressWebSearch(in: harness, starts: starts)
    await harness.render { !Self.setParams(in: session).isEmpty }

    let params = try #require(Self.setParams(in: session).first)
    #expect(params["sessionId"]?.stringValue == ScriptedSession.sessionID)
    #expect(params["configId"]?.stringValue == "web")
    #expect(params["type"]?.stringValue == "boolean")
    #expect(params["value"] == .bool(true))
    #expect(Self.rowValue(Self.webRow, in: harness) == Self.notSelected)

    let optionsBefore = model.configOptions
    session.agent.releaseHeldAnswer()
    await harness.render { model.configOptions != optionsBefore }

    #expect(Self.rowValue(Self.webRow, in: harness) == Self.selected)
  }

  @Test func aChoiceInASelectRowSendsSetConfigOptionWithTheChosenValue() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = Self.mount(session: session)
    defer { harness.close() }

    let params = try await Self.choose(Self.deepChoice, in: Self.modelRow, harness: harness, session: session)

    #expect(params["configId"]?.stringValue == "model")
    #expect(params["value"]?.stringValue == "deep-1")
  }

  /// The test does not press a segment. A press on an AppKit segmented
  /// control stops the test process before the other tests run, as a press
  /// on a stepper does. Thus the test sets the binding that the picker uses.
  @Test func theModeBindingSendsOnlyANewValueAndKeepsTheModelValue() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let selection = session.model.makeConfigBinding(
      for: Self.modeID, current: SessionConfigValueId(rawValue: "ask"),
      send: SetSessionConfigOptionRequest.Value.id)

    selection.wrappedValue = SessionConfigValueId(rawValue: "ask")
    selection.wrappedValue = SessionConfigValueId(rawValue: "auto")
    await ObservationWait.until { !Self.setParams(in: session).isEmpty }

    #expect(selection.wrappedValue.rawValue == "ask")
    #expect(Self.setParams(in: session).map { $0["value"]?.stringValue } == ["auto"])
  }

  @Test func aFailedCallKeepsTheModelValueAndAddsAnErrorEntry() async throws {
    let session = try await Self.openSession { $0.failingMethods = [Self.setMethod] }
    defer { session.close() }
    let starts = ReportRecorder<String>()
    let harness = Self.mount(session: session, requestStartReport: starts.report)
    defer { harness.close() }
    let model = session.model

    try await Self.pressWebSearch(in: harness, starts: starts)
    await harness.render { TranscriptChecks.hasErrorEntry(model) }

    #expect(TranscriptChecks.hasErrorEntry(model))
    #expect(Self.rowValue(Self.webRow, in: harness) == Self.notSelected)
  }

  // MARK: - Agent updates

  @Test func anAgentConfigOptionUpdateChangesTheShownValue() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = Self.mount(session: session)
    defer { harness.close() }
    let model = session.model
    #expect(Self.modeSegment(Self.autoChoice, in: harness)?.value == Self.notSelected)

    let optionsBefore = model.configOptions
    try await session.sendUpdate(
      Self.configUpdate(options: [Self.modelOption, Self.webOption, Self.modeOption(current: "auto")]))
    await harness.render { model.configOptions != optionsBefore }

    #expect(Self.modeSegment(Self.autoChoice, in: harness)?.value == Self.selected)
    #expect(Self.rowValue(Self.modeRow, in: harness) == Self.autoChoice)
  }

  // MARK: - Menu

  @Test func theMenuStyleShowsOneMenuButton() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = HostedViewHarness(size: Self.size) {
      ConfigOptionsView(session: session.model, style: .menu)
    }
    defer { harness.close() }
    harness.render()

    #expect(harness.element(identifier: ConfigOptionsView.menuIdentifier) != nil)
    #expect(harness.element(identifier: Self.webRow) == nil)
  }

  @Test func aChoiceInTheMenuSendsSetConfigOptionWithTheChosenValue() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = Self.mountMenuControls(session: session)
    defer { harness.close() }

    let params = try await Self.choose(
      Self.deepChoice, in: ConfigOptionsView.controlIdentifier(for: Self.modelID), harness: harness, session: session)

    #expect(params["configId"]?.stringValue == "model")
    #expect(params["value"]?.stringValue == "deep-1")
  }

  @Test func aToggleInTheMenuSendsSetConfigOptionWithTheNewValue() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = Self.mountMenuControls(session: session)
    defer { harness.close() }

    try harness.press(identifier: ConfigOptionsView.controlIdentifier(for: Self.webID))
    await ObservationWait.until { !Self.setParams(in: session).isEmpty }

    let params = try #require(Self.setParams(in: session).first)
    #expect(params["configId"]?.stringValue == "web")
    #expect(params["value"] == .bool(true))
  }

  // MARK: - Permission mode

  @Test func thePermissionModePickerIsAbsentWithNoModeOption() async throws {
    let session = try await Self.openSession(options: [Self.modelOption, Self.webOption])
    defer { session.close() }
    let harness = Self.mount(session: session)
    defer { harness.close() }

    #expect(harness.element(identifier: PermissionModePicker.pickerIdentifier) == nil)
    #expect(PermissionModePicker.modeOption(in: session.model.configOptions ?? []) == nil)
  }

  @Test func thePermissionModePickerShowsOneSegmentForEachValue() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = Self.mount(session: session)
    defer { harness.close() }

    let segments = harness.elements(under: PermissionModePicker.pickerIdentifier)
    #expect(segments.map(\.label) == [Self.askChoice, Self.autoChoice])
    #expect(segments.map(\.value) == [Self.selected, Self.notSelected])
  }

  @Test func thePermissionModePickerOffersEachValueAsANamedAction() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = Self.mount(session: session)
    defer { harness.close() }

    let picker = harness.element(identifier: PermissionModePicker.pickerIdentifier)
    #expect(picker?.customActions == [Self.askChoice, Self.autoChoice])
  }

  @Test func aChoiceInThePermissionModePickerSendsSetConfigOptionWithTheChosenValue() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = Self.mount(session: session)
    defer { harness.close() }

    let params = try await Self.choose(
      Self.autoChoice, in: PermissionModePicker.pickerIdentifier, harness: harness, session: session)

    #expect(params["configId"]?.stringValue == "mode")
    #expect(params["value"]?.stringValue == "auto")
  }
}
