@testable import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import SwiftUI
import Testing

/// Hosted tests of ``ConfigOptionsView`` and ``PermissionModePicker``
/// through a ``NoopThreadActions``.
@Suite(.serialized) @MainActor struct ConfigOptionsViewHostedTests {
  /// The longest time that a test waits for a call or an update, in seconds.
  static let waitSeconds: TimeInterval = 1

  /// The id of the model option.
  static let modelID = ConfigOptionID("model")

  /// The id of the web search option.
  static let webID = ConfigOptionID("web")

  /// The id of the mode option.
  static let modeID = ConfigOptionID("mode")

  /// The id of the thought level option.
  static let thoughtID = ConfigOptionID("thought")

  /// The id of the temperature option.
  static let temperatureID = ConfigOptionID("temperature")

  /// The id of the option with a type that the kit does not know.
  static let rangeID = ConfigOptionID("range")

  /// The id of the option with a category that the kit does not know.
  static let styleID = ConfigOptionID("style")

  /// A model option with its values in two groups.
  static let model = ConfigOption(
    id: modelID, name: "Model", category: .model,
    kind: .select(
      current: "fast-1",
      choices: .grouped([
        SelectGroup(
          id: "fast", name: "Fast Models",
          options: [SelectOption(id: "fast-1", name: "Fast One")]),
        SelectGroup(
          id: "deep", name: "Deep Models",
          options: [SelectOption(id: "deep-1", name: "Deep One")]),
      ])))

  /// A boolean option with no category.
  static let webSearch = ConfigOption(
    id: webID, name: "Web Search", kind: .boolean(current: false))

  /// A mode option with the value `ask` selected.
  static let mode = modeOption(current: "ask")

  /// A mode option with two flat values.
  ///
  /// - Parameter current: The id of the selected value.
  /// - Returns: The option.
  static func modeOption(current: String) -> ConfigOption {
    ConfigOption(
      id: modeID, name: "Mode", category: .mode,
      kind: .select(
        current: current,
        choices: .flat([
          SelectOption(id: "ask", name: "Ask"),
          SelectOption(id: "auto", name: "Auto"),
        ])))
  }

  /// The options of the view tests, not in category order.
  static let options: [ConfigOption] = [model, webSearch, mode]

  /// A view that shows the options of a thread, so that a change to the
  /// thread updates the views.
  struct ThreadOptions: View {
    /// The thread to show.
    let thread: AgentThread

    var body: some View {
      VStack {
        ConfigOptionsView(options: thread.configOptions, style: .form)
        PermissionModePicker(options: thread.configOptions)
      }
    }
  }

  /// Mounts `content` with `actions`.
  ///
  /// - Parameters:
  ///   - content: The view to mount.
  ///   - actions: The actions of the view.
  /// - Returns: The harness.
  static func mount(
    _ content: some View,
    actions: NoopThreadActions
  ) -> HostedViewHarness<some View> {
    let harness = HostedViewHarness(content.threadActions(actions))
    harness.pump()
    return harness
  }

  // MARK: - Grouping

  @Test func sectionsFollowTheCategoryOrderAndDropUnknownTypes() {
    let options = [
      Self.webSearch,
      ConfigOption(
        id: Self.temperatureID, name: "Temperature", category: .modelConfig,
        kind: .boolean(current: true)),
      ConfigOption(
        id: Self.styleID, name: "Style", category: .unknown("style"),
        kind: .boolean(current: true)),
      ConfigOption(
        id: Self.thoughtID, name: "Thought", category: .thoughtLevel,
        kind: .boolean(current: false)),
      ConfigOption(
        id: Self.rangeID, name: "Range", category: .model,
        kind: .unknown(type: "range", raw: .null)),
      Self.model,
      Self.mode,
    ]

    let sections = ConfigOptionsView.sections(for: options)

    #expect(sections.map(\.id) == ["mode", "model", "thought_level", "model_config", "uncategorized"])
    #expect(
      sections.map { $0.options.map(\.id) } == [
        [Self.modeID], [Self.modelID], [Self.thoughtID], [Self.temperatureID],
        [Self.webID, Self.styleID],
      ])
    #expect(sections.map(\.title) == ["Mode", "Model", "Thought Level", "Model Settings", "Other"])
  }

  @Test func noOptionThatTheViewCanShowMountsNoView() {
    let unknown = ConfigOption(
      id: Self.rangeID, name: "Range", kind: .unknown(type: "range", raw: .null))
    let harness = Self.mount(
      ConfigOptionsView(options: [unknown], style: .form), actions: NoopThreadActions())
    defer { harness.close() }

    #expect(harness.element(identifier: ConfigOptionsView.viewIdentifier) == nil)
  }

  // MARK: - Form

  @Test func theFormShowsTheCategorySectionsInOrder() {
    let harness = Self.mount(
      ConfigOptionsView(options: Self.options, style: .form), actions: NoopThreadActions())
    defer { harness.close() }

    let headers = harness.accessibilityElements().compactMap(\.identifier).filter {
      $0.hasPrefix(ConfigOptionsView.sectionIdentifierPrefix)
    }
    #expect(headers == ["config-section-mode", "config-section-model", "config-section-uncategorized"])
    #expect(harness.element(identifier: "config-section-model")?.label == "Model")
  }

  @Test func aSelectWithGroupsShowsASectionForEachGroupName() throws {
    let harness = Self.mount(
      ConfigOptionsView(options: Self.options, style: .form), actions: NoopThreadActions())
    defer { harness.close() }

    let elements = harness.accessibilityElements()
    for (groupID, name) in [("fast", "Fast Models"), ("deep", "Deep Models")] {
      let identifier = ConfigOptionsView.groupIdentifier(for: Self.modelID, groupID: groupID)
      let index = try #require(elements.firstIndex { $0.identifier == identifier })
      #expect(elements[index + 1].label == name, "The group \(groupID) has no header.")
    }
    #expect(
      harness.element(
        identifier: ConfigOptionsView.choiceIdentifier(for: Self.modelID, value: "fast-1"))?.value
        == "1")
    #expect(
      harness.element(
        identifier: ConfigOptionsView.choiceIdentifier(for: Self.modelID, value: "deep-1"))?.value
        == "0")
  }

  @Test func selectingAValueInAnotherGroupSetsTheOptionWithTheValueID() async throws {
    let actions = NoopThreadActions()
    let harness = Self.mount(ConfigOptionsView(options: Self.options, style: .form), actions: actions)
    defer { harness.close() }

    try harness.press(
      identifier: ConfigOptionsView.choiceIdentifier(for: Self.modelID, value: "deep-1"))
    await harness.pump(until: Self.waitSeconds) { !actions.calls.isEmpty }

    #expect(actions.calls == [.setConfigOption(Self.modelID, .id("deep-1"))])
  }

  @Test func changingAToggleSetsTheOptionWithABoolean() async throws {
    let actions = NoopThreadActions()
    let harness = Self.mount(ConfigOptionsView(options: Self.options, style: .form), actions: actions)
    defer { harness.close() }

    try harness.press(identifier: ConfigOptionsView.controlIdentifier(for: Self.webID))
    await harness.pump(until: Self.waitSeconds) { !actions.calls.isEmpty }

    #expect(actions.calls == [.setConfigOption(Self.webID, .boolean(true))])
  }

  @Test func selectingTheCurrentValueSetsNothing() throws {
    let actions = NoopThreadActions()
    let harness = Self.mount(ConfigOptionsView(options: Self.options, style: .form), actions: actions)
    defer { harness.close() }

    try harness.press(identifier: ConfigOptionsView.choiceIdentifier(for: Self.modeID, value: "ask"))
    harness.pump()

    #expect(actions.calls.isEmpty)
  }

  // MARK: - Menu

  @Test func theMenuStyleShowsOneMenuButton() {
    let harness = Self.mount(
      ConfigOptionsView(options: Self.options, style: .menu), actions: NoopThreadActions())
    defer { harness.close() }

    #expect(harness.element(identifier: ConfigOptionsView.menuIdentifier) != nil)
    #expect(harness.element(identifier: ConfigOptionsView.controlIdentifier(for: Self.webID)) == nil)
  }

  // MARK: - Permission mode

  @Test func thePermissionModePickerIsAbsentWithNoModeOption() {
    let harness = Self.mount(
      PermissionModePicker(options: [Self.model, Self.webSearch]), actions: NoopThreadActions())
    defer { harness.close() }

    #expect(harness.element(identifier: PermissionModePicker.pickerIdentifier) == nil)
    #expect(PermissionModePicker.modeOption(in: [Self.model, Self.webSearch]) == nil)
  }

  @Test func thePermissionModePickerShowsOneSegmentForEachValue() {
    let harness = Self.mount(PermissionModePicker(options: Self.options), actions: NoopThreadActions())
    defer { harness.close() }

    #expect(harness.element(identifier: PermissionModePicker.pickerIdentifier) != nil)
    #expect(harness.element(identifier: PermissionModePicker.segmentIdentifier(for: "ask"))?.value == "1")
    #expect(harness.element(identifier: PermissionModePicker.segmentIdentifier(for: "auto"))?.value == "0")
  }

  /// The test does not press a segment. A press on an AppKit segmented
  /// control stops the test process before the other tests run, as a press
  /// on a stepper does. Thus the test sets the binding that the picker uses.
  @Test func theModeBindingSetsTheModeOptionOnlyForANewValue() async {
    let actions = NoopThreadActions()
    let selection = configOptionBinding(
      id: Self.modeID, current: "ask", actions: actions, send: ConfigValue.id)

    selection.wrappedValue = "ask"
    selection.wrappedValue = "auto"
    let deadline = Date(timeIntervalSinceNow: Self.waitSeconds)
    while actions.calls.isEmpty, Date() < deadline {
      await Task.yield()
    }

    #expect(selection.wrappedValue == "ask")
    #expect(actions.calls == [.setConfigOption(Self.modeID, .id("auto"))])
  }

  // MARK: - Updates

  @Test func bothViewsUpdateWhenTheThreadReplacesTheList() async {
    let thread = AgentThread()
    thread.apply(.setConfigOptions([Self.webSearch]))
    let harness = Self.mount(ThreadOptions(thread: thread), actions: NoopThreadActions())
    defer { harness.close() }
    let autoIdentifier = PermissionModePicker.segmentIdentifier(for: "auto")
    #expect(harness.element(identifier: PermissionModePicker.pickerIdentifier) == nil)

    thread.apply(.setConfigOptions([Self.modeOption(current: "auto"), Self.webSearch]))
    await harness.pump(until: Self.waitSeconds) {
      harness.element(identifier: autoIdentifier)?.value == "1"
    }

    #expect(harness.element(identifier: autoIdentifier)?.value == "1")
    #expect(
      harness.element(
        identifier: ConfigOptionsView.choiceIdentifier(for: Self.modeID, value: "auto"))?.value
        == "1")
  }
}
