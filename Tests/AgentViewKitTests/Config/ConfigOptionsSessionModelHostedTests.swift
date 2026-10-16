import AgentViewKitTestSupport
import DemoSupport
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

  /// The accessibility value of a choice of a select option.
  ///
  /// - Parameters:
  ///   - value: The value id of the choice.
  ///   - id: The id of the option.
  ///   - harness: The harness of the view.
  /// - Returns: `"1"` for the selected choice, `"0"` for another choice.
  static func choiceValue(
    _ value: String, of id: SessionConfigId, in harness: HostedViewHarness<some View>
  ) -> String? {
    harness.element(identifier: ConfigOptionsView.choiceIdentifier(for: id, value: value))?.value
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
    #expect(harness.element(identifier: ConfigOptionsView.viewIdentifier) == nil)
    #expect(harness.element(identifier: PermissionModePicker.pickerIdentifier) == nil)
  }

  @Test func withAnEmptyOptionListTheControlsAreHidden() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = Self.mount(session: session)
    defer { harness.close() }
    let model = session.model
    #expect(harness.element(identifier: ConfigOptionsView.viewIdentifier) != nil)

    try await session.sendUpdate(Self.configUpdate(options: []))
    await harness.render { model.configOptions?.isEmpty == true }

    #expect(harness.element(identifier: ConfigOptionsView.viewIdentifier) == nil)
    #expect(harness.element(identifier: PermissionModePicker.pickerIdentifier) == nil)
  }

  // MARK: - Form

  @Test func theFormShowsTheCategorySectionsInOrder() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = Self.mount(session: session)
    defer { harness.close() }

    let headers = harness.accessibilityElements().compactMap(\.identifier).filter {
      $0.hasPrefix(ConfigOptionsView.sectionIdentifierPrefix)
    }
    #expect(headers == ["config-section-mode", "config-section-model", "config-section-uncategorized"])
    #expect(harness.element(identifier: "config-section-model")?.label == "Model")
  }

  @Test func aSelectWithGroupsShowsASectionForEachGroupName() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = Self.mount(session: session)
    defer { harness.close() }

    let elements = harness.accessibilityElements()
    for (groupID, name) in [("fast", "Fast Models"), ("deep", "Deep Models")] {
      let identifier = ConfigOptionsView.groupIdentifier(for: Self.modelID, groupID: groupID)
      let index = try #require(elements.firstIndex { $0.identifier == identifier })
      #expect(elements[index + 1].label == name, "The group \(groupID) has no header.")
    }
    #expect(Self.choiceValue("fast-1", of: Self.modelID, in: harness) == Self.selected)
    #expect(Self.choiceValue("deep-1", of: Self.modelID, in: harness) == Self.notSelected)
  }

  // MARK: - Set config option

  /// The agent holds its answer, and after the answer it sends the option
  /// value that it reports. The report changes the options of the model, so
  /// the test waits for that change, and then renders the view.
  @Test func aChangeSendsSetConfigOptionAndTheViewShowsTheValueThatTheModelReports() async throws {
    let reported = Self.modelOption.replacingOccurrences(
      of: #""currentValue": "fast-1""#, with: #""currentValue": "deep-1""#)
    let reportedFrame = try Self.configUpdateFrame(options: [reported, Self.webOption, Self.modeOption(current: "ask")])
    let session = try await Self.openSession { agent in
      agent.heldMethods = [Self.setMethod]
      agent.followUps[Self.setMethod] = { _, _ in [reportedFrame] }
    }
    defer { session.close() }
    let starts = ReportRecorder<String>()
    let harness = Self.mount(session: session, requestStartReport: starts.report)
    defer { harness.close() }
    let model = session.model

    try harness.press(identifier: ConfigOptionsView.choiceIdentifier(for: Self.modelID, value: "deep-1"))
    // The choice starts the set request in the same step as the press, so a
    // press that started nothing stops the test here.
    try #require(starts.values == [Self.setMethod])
    await harness.render { !Self.setParams(in: session).isEmpty }

    let params = try #require(Self.setParams(in: session).first)
    #expect(params["sessionId"]?.stringValue == ScriptedSession.sessionID)
    #expect(params["configId"]?.stringValue == "model")
    #expect(params["type"]?.stringValue == "id")
    #expect(params["value"]?.stringValue == "deep-1")
    #expect(Self.choiceValue("fast-1", of: Self.modelID, in: harness) == Self.selected)

    let optionsBefore = model.configOptions
    session.agent.releaseHeldAnswer()
    await harness.render { model.configOptions != optionsBefore }

    #expect(Self.choiceValue("deep-1", of: Self.modelID, in: harness) == Self.selected)
    #expect(Self.choiceValue("fast-1", of: Self.modelID, in: harness) == Self.notSelected)
  }

  @Test func changingAToggleSendsABooleanValue() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let starts = ReportRecorder<String>()
    let harness = Self.mount(session: session, requestStartReport: starts.report)
    defer { harness.close() }

    try harness.press(identifier: ConfigOptionsView.controlIdentifier(for: Self.webID))
    // The toggle starts the set request in the same step as the press, so a
    // press that started nothing stops the test here.
    try #require(starts.values == [Self.setMethod])
    await ObservationWait.until { !Self.setParams(in: session).isEmpty }

    let params = try #require(Self.setParams(in: session).first)
    #expect(params["configId"]?.stringValue == "web")
    #expect(params["type"]?.stringValue == "boolean")
    #expect(params["value"] == .bool(true))
  }

  /// The press of the current value sends nothing. To know that no frame
  /// comes later, the test then presses a new value of another option as a
  /// fence: the frames go to the agent in order, so when the frame of the
  /// fence is there, a frame of the first press is there too. The test then
  /// checks that the fence frame is the only frame.
  @Test func selectingTheCurrentValueSendsNothing() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let starts = ReportRecorder<String>()
    let harness = Self.mount(session: session, requestStartReport: starts.report)
    defer { harness.close() }

    try harness.press(identifier: ConfigOptionsView.choiceIdentifier(for: Self.modeID, value: "ask"))
    // The press of the current value starts no request, so a press that
    // started a request stops the test here.
    try #require(starts.values.isEmpty)
    try harness.press(identifier: ConfigOptionsView.choiceIdentifier(for: Self.modelID, value: "deep-1"))
    // The fence choice starts the set request in the same step as the press,
    // so a press that started nothing stops the test here.
    try #require(starts.values == [Self.setMethod])
    await ObservationWait.until { !Self.setParams(in: session).isEmpty }

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

    try harness.press(identifier: ConfigOptionsView.choiceIdentifier(for: Self.modelID, value: "deep-1"))
    // The choice starts the set request in the same step as the press, so a
    // press that started nothing stops the test here.
    try #require(starts.values == [Self.setMethod])
    await harness.render { TranscriptChecks.hasErrorEntry(model) }

    #expect(TranscriptChecks.hasErrorEntry(model))
    #expect(Self.choiceValue("fast-1", of: Self.modelID, in: harness) == Self.selected)
    #expect(Self.choiceValue("deep-1", of: Self.modelID, in: harness) == Self.notSelected)
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
    #expect(Self.choiceValue("auto", of: Self.modeID, in: harness) == Self.selected)
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
    #expect(harness.element(identifier: ConfigOptionsView.controlIdentifier(for: Self.webID)) == nil)
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
