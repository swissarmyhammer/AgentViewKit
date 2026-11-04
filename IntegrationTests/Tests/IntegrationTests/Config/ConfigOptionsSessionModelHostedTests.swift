import AgentViewKitTestSupport
import AgentViewKitDemoSupport
import EditorCommandsUI
import EditorInspector
import EditorInspectorTestSupport
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
/// its rows with EditorKit's `InspectorDriver`, by their scheme ids
/// (``row(_:_:of:)``): it reads the value of a row, presses a toggle row and
/// chooses a choice of a picker row with no pop-up.
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

  /// The text of the choice `Deep One` of the model option.
  static let deepChoice = "Deep One (Deep Models)"

  /// The text of the choice `Fast One` of the model option.
  static let fastChoice = "Fast One (Fast Models)"

  /// The scheme id of the block of the form of `model`: the view and the
  /// object.
  ///
  /// - Parameter model: The session model of the form.
  /// - Returns: The id, such as `inspection:config-options/object:<session>`.
  static func block(of model: SessionModel) -> String {
    InspectorScheme.blockIdentifier(
      view: ConfigOptionsView.viewIdentifier, object: InspectorScheme.objectID(of: [model], key: ""))
  }

  /// The scheme id of the row of an option in the form of `model`: the
  /// view, the session, the category section and the option.
  ///
  /// - Parameters:
  ///   - section: The id of the category section, such as `model`.
  ///   - id: The id of the option.
  ///   - model: The session model of the form.
  /// - Returns: The id that the row carries.
  static func row(_ section: String, _ id: SessionConfigId, of model: SessionModel) -> String {
    InspectorDriver.field(
      view: ConfigOptionsView.viewIdentifier, object: InspectorScheme.objectID(of: [model], key: ""),
      group: section, field: id.rawValue)
  }

  /// The row of the model option.
  static func modelRow(_ model: SessionModel) -> String { row("model", modelID, of: model) }

  /// The row of the mode option.
  static func modeRow(_ model: SessionModel) -> String { row("mode", modeID, of: model) }

  /// The row of the web search option.
  static func webRow(_ model: SessionModel) -> String {
    row(ConfigOptionsView.uncategorizedSectionID, webID, of: model)
  }

  /// The driver of the inspector rows of `harness`.
  ///
  /// - Parameter harness: The harness of the view.
  /// - Returns: EditorKit's `InspectorDriver` over the hosting view.
  static func driver(of harness: HostedViewHarness<some View>) -> InspectorDriver {
    InspectorDriver(window: harness.window, root: harness.hostingView)
  }

  /// The choice that the picker row of `identifier` shows, or the state of
  /// its toggle row: `1` on and `0` off.
  ///
  /// - Parameters:
  ///   - identifier: The scheme id of the row.
  ///   - harness: The harness of the view.
  /// - Returns: The value of the row, or `nil` when no row has the id.
  static func rowValue(_ identifier: String, in harness: HostedViewHarness<some View>) -> String? {
    driver(of: harness).value(of: identifier)
  }

  /// Whether the form of `harness` shows the row of `identifier`.
  ///
  /// - Parameters:
  ///   - identifier: The scheme id of the row.
  ///   - harness: The harness of the view.
  /// - Returns: `true` when an element carries the id.
  static func showsRow(_ identifier: String, in harness: HostedViewHarness<some View>) -> Bool {
    !driver(of: harness).elements(identifier).isEmpty
  }

  /// Presses the toggle row of the web search option of `model`, and waits
  /// for the request that the commit of the row starts.
  ///
  /// - Parameters:
  ///   - model: The session model of the form.
  ///   - harness: The harness of the view.
  ///   - starts: The recorder of the request starts.
  /// - Throws: When the row is not there or does not press.
  static func pressWebSearch(
    of model: SessionModel, in harness: HostedViewHarness<some View>, starts: ReportRecorder<String>
  ) async throws {
    try driver(of: harness).press(webRow(model))
    // The row commits in a task of its own, which starts the request.
    await ObservationWait.until { !starts.values.isEmpty }
    try #require(starts.values == [setMethod])
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
    #expect(!Self.showsRow(Self.webRow(session.model), in: harness))
    #expect(harness.element(identifier: PermissionModePicker.pickerIdentifier) == nil)
  }

  @Test func withAnEmptyOptionListTheControlsAreHidden() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = Self.mount(session: session)
    defer { harness.close() }
    let model = session.model
    #expect(Self.showsRow(Self.webRow(session.model), in: harness))

    try await session.sendUpdate(Self.configUpdate(options: []))
    await harness.render { model.configOptions?.isEmpty == true }

    #expect(!Self.showsRow(Self.webRow(session.model), in: harness))
    #expect(harness.element(identifier: PermissionModePicker.pickerIdentifier) == nil)
  }

  // MARK: - Form

  @Test func theFormShowsOneRowForEachOptionInTheCategoryOrder() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = Self.mount(session: session)
    defer { harness.close() }

    let model = session.model
    let fields = Self.block(of: model) + "/field:"
    let rows = harness.accessibilityElements().compactMap(\.identifier).filter { $0.hasPrefix(fields) }
    #expect(rows == [Self.modeRow(model), Self.modelRow(model), Self.webRow(model)])
  }

  @Test func aSelectWithGroupsNamesTheGroupOfItsChoice() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = Self.mount(session: session)
    defer { harness.close() }

    #expect(Self.rowValue(Self.modelRow(session.model), in: harness) == Self.fastChoice)
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

    try await Self.pressWebSearch(of: session.model, in: harness, starts: starts)
    await harness.render { !Self.setParams(in: session).isEmpty }

    let params = try #require(Self.setParams(in: session).first)
    #expect(params["sessionId"]?.stringValue == ScriptedSession.sessionID)
    #expect(params["configId"]?.stringValue == "web")
    #expect(params["type"]?.stringValue == "boolean")
    #expect(params["value"] == .bool(true))
    #expect(Self.rowValue(Self.webRow(session.model), in: harness) == Self.notSelected)

    let optionsBefore = model.configOptions
    session.agent.releaseHeldAnswer()
    await harness.render { model.configOptions != optionsBefore }

    #expect(Self.rowValue(Self.webRow(session.model), in: harness) == Self.selected)
  }

  /// The choice of the current value sends nothing. To know that no frame
  /// comes later, the test then chooses a new value of another option as a
  /// fence: the frames go to the agent in order, so when the frame of the
  /// fence is there, a frame of the first choice is there too. The test then
  /// checks that the fence frame is the only frame.
  @Test func selectingTheCurrentValueSendsNothing() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let starts = ReportRecorder<String>()
    let harness = Self.mount(session: session, requestStartReport: starts.report)
    defer { harness.close() }
    let model = session.model
    let driver = Self.driver(of: harness)

    try driver.choose("Ask", in: Self.modeRow(model))
    try driver.choose(Self.deepChoice, in: Self.modelRow(model))
    // Each row commits in a task of its own, in order, so the start of the
    // fence comes after any start of the first choice.
    await ObservationWait.until { !starts.values.isEmpty }
    await ObservationWait.until { !Self.setParams(in: session).isEmpty }

    #expect(starts.values == [Self.setMethod])
    #expect(Self.setParams(in: session).map { $0["configId"]?.stringValue } == ["model"])
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

    try await Self.pressWebSearch(of: session.model, in: harness, starts: starts)
    await harness.render { TranscriptChecks.hasErrorEntry(model) }

    #expect(TranscriptChecks.hasErrorEntry(model))
    #expect(Self.rowValue(Self.webRow(session.model), in: harness) == Self.notSelected)
  }

  // MARK: - Agent updates

  @Test func anAgentConfigOptionUpdateChangesTheShownValue() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = Self.mount(session: session)
    defer { harness.close() }
    let model = session.model
    let autoSegment = PermissionModePicker.segmentIdentifier(for: "auto")
    #expect(harness.element(identifier: autoSegment)?.value == Self.notSelected)

    let optionsBefore = model.configOptions
    try await session.sendUpdate(
      Self.configUpdate(options: [Self.modelOption, Self.webOption, Self.modeOption(current: "auto")]))
    await harness.render { model.configOptions != optionsBefore }

    #expect(harness.element(identifier: autoSegment)?.value == Self.selected)
    #expect(Self.rowValue(Self.modeRow(session.model), in: harness) == "Auto")
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
    #expect(!Self.showsRow(Self.webRow(session.model), in: harness))
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

    #expect(harness.element(identifier: PermissionModePicker.pickerIdentifier) != nil)
    #expect(harness.element(identifier: PermissionModePicker.segmentIdentifier(for: "ask"))?.value == Self.selected)
    #expect(
      harness.element(identifier: PermissionModePicker.segmentIdentifier(for: "auto"))?.value == Self.notSelected)
  }
}
