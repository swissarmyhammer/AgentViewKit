@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Hosted tests of the menu buttons of the kit and of the Reasoning toggle,
/// each one of EditorKit's button components (EditorKit `style.md`,
/// "Buttons").
///
/// Each menu button is an EditorKit `EditorMenuButton`: the Session Options
/// menu of ``ConfigOptionsView``, the Tools menu of ``ToolToggles`` and the
/// children menu of the session crumbs. Each is one accessibility element,
/// whose show-menu action opens its menu, and a squeezed one hides its
/// caption and keeps its name as its label and its tooltip. The tests read the
/// accessibility tree and the menu that the action opens, never pixels or
/// frames.
@Suite(.serialized, .hostedSerially) @MainActor struct MenuButtonHostedTests {
  /// The locale of the views whose labels the tests read.
  static let locale = Locale(identifier: "en_US")

  /// The id of the child session of the children menu test.
  static let child = SessionId(rawValue: "reviewer")

  /// The title of the child session of the children menu test.
  static let childTitle = "Reviewer"

  /// The tools of the Tools menu: one on and one off.
  static let tools = [
    ToolToggle(id: ToolToggleID("web-search"), name: "Web search", isEnabled: true),
    ToolToggle(id: ToolToggleID("terminal"), name: "Terminal", isEnabled: false),
  ]

  /// A width that holds the symbol of the Tools menu and not its short
  /// caption, in points.
  static let toolsSqueezedWidth: CGFloat = 32

  /// The accessibility value of a toggle that is on.
  static let toggleOnValue = "1"

  /// The Session Options menu of a session with the preview options.
  static var sessionOptions: some View {
    ConfigOptionsView(session: PreviewFixtures.configuredSession, style: .menu)
  }

  /// The Tools menu of ``tools``.
  static var toolMenu: some View {
    ToolToggles(tools: tools) { _, _ in }
  }

  /// Mounts `content` in a window wider than each view under test.
  ///
  /// - Parameter content: The view under test.
  /// - Returns: The harness, after one render pass. The caller closes it.
  static func mount(_ content: some View) -> HostedViewHarness<some View> {
    let harness = HostedViewHarness(content, size: SqueezedButtonHostedTests.windowSize)
    harness.render()
    return harness
  }

  /// The number of accessibility elements with `identifier`.
  ///
  /// - Parameters:
  ///   - identifier: The accessibility identifier.
  ///   - harness: The harness that shows the view.
  /// - Returns: The count.
  static func elementCount(_ identifier: String, in harness: HostedViewHarness<some View>) -> Int {
    harness.accessibilityElements().filter { $0.identifier == identifier }.count
  }

  /// The titles of the items of the menu that the show-menu action of the
  /// element with `identifier` opens, with no separator between its
  /// sections.
  ///
  /// - Parameters:
  ///   - identifier: The accessibility identifier of the menu button.
  ///   - harness: The harness that shows the view.
  /// - Returns: The titles, in order.
  /// - Throws: The error of the action, or an issue when it opens no menu.
  static func menuTitles(of identifier: String, in harness: HostedViewHarness<some View>) throws -> [String] {
    let menu = try #require(try harness.perform(.showMenu, on: identifier))
    return menu.items.filter { !$0.isSeparatorItem }.map(\.title)
  }

  // MARK: - Session Options

  /// A production change that fails this test: the menu of the options adds
  /// an element of its own around its control, or splits its icon and its
  /// caption into elements.
  @Test func theSessionOptionsMenuIsOneElement() {
    let harness = Self.mount(Self.sessionOptions)
    defer { harness.close() }

    #expect(Self.elementCount(ConfigOptionsView.menuIdentifier, in: harness) == 1)
  }

  /// A production change that fails this test: the Session Options menu opens
  /// no menu through accessibility, or a menu without the options.
  @Test func showingTheSessionOptionsMenuListsEachOption() throws {
    let harness = Self.mount(Self.sessionOptions)
    defer { harness.close() }

    let titles = try Self.menuTitles(of: ConfigOptionsView.menuIdentifier, in: harness)

    for option in PreviewFixtures.configOptions {
      #expect(titles.contains(option.name), "the menu lists \(titles)")
    }
  }

  /// A production change that fails this test: the Session Options menu
  /// keeps a caption it has no room for, so its row cuts it and sets no
  /// tooltip.
  @Test func aSqueezedSessionOptionsMenuKeepsItsNameAsItsLabelAndItsTooltip() throws {
    let harness = SqueezedButtonHostedTests.mountSqueezed(Self.sessionOptions)
    defer { harness.close() }
    let element = try SqueezedButtonHostedTests.button(ConfigOptionsView.menuIdentifier, in: harness)

    #expect(element.label == "Session Options")
    #expect(element.hint == "Session Options")
  }

  // MARK: - Tools

  /// A production change that fails this test: the Tools menu adds an
  /// element of its own around its control, or splits its icon and its
  /// caption into elements.
  @Test func theToolsMenuIsOneElement() {
    let harness = Self.mount(Self.toolMenu)
    defer { harness.close() }

    #expect(Self.elementCount(ToolToggles.menuIdentifier, in: harness) == 1)
  }

  /// A production change that fails this test: the Tools menu opens no menu
  /// through accessibility, or a menu without a toggle for each tool.
  @Test func showingTheToolsMenuListsEachTool() throws {
    let harness = Self.mount(Self.toolMenu)
    defer { harness.close() }

    let titles = try Self.menuTitles(of: ToolToggles.menuIdentifier, in: harness)

    #expect(titles == Self.tools.map(\.name), "the menu lists \(titles)")
  }

  /// A production change that fails this test: the Tools menu keeps a
  /// caption it has no room for, so its row cuts it and sets no tooltip.
  @Test func aSqueezedToolsMenuKeepsItsNameAsItsLabelAndItsTooltip() throws {
    let harness = SqueezedButtonHostedTests.mountSqueezed(Self.toolMenu, width: Self.toolsSqueezedWidth)
    defer { harness.close() }
    let element = try SqueezedButtonHostedTests.button(ToolToggles.menuIdentifier, in: harness)

    #expect(element.label == "Tools")
    #expect(element.hint == "Tools")
  }

  // MARK: - Children of a session

  /// Opens a scripted session with one child, and mounts the header of the
  /// root session, whose crumbs end with the children menu.
  ///
  /// - Parameter session: The scripted session.
  /// - Returns: The harness, after one render pass. The caller closes it.
  /// - Throws: The error of the announce of the child.
  static func mountHeaderWithAChild(of session: ScriptedSession) async throws -> HostedViewHarness<some View> {
    _ = try await session.announceChild(Self.child, title: Self.childTitle)
    return Self.mount(
      AgentInfoHeader(connection: session.connection, session: session.model)
        .environment(\.locale, Self.locale))
  }

  /// A production change that fails this test: the children menu adds an
  /// element of its own around its control, or splits its icon and its
  /// caption into elements.
  @Test func theChildrenMenuIsOneElement() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = try await Self.mountHeaderWithAChild(of: session)
    defer { harness.close() }

    #expect(Self.elementCount(SessionBreadcrumb.childrenIdentifier, in: harness) == 1)
  }

  /// A production change that fails this test: the children menu opens no
  /// menu through accessibility, or a menu without the open child.
  @Test func showingTheChildrenMenuListsTheChild() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = try await Self.mountHeaderWithAChild(of: session)
    defer { harness.close() }
    let child = try #require(session.model.children.first)

    let titles = try Self.menuTitles(of: SessionBreadcrumb.childrenIdentifier, in: harness)

    #expect(
      titles == [SessionStateText.choiceLabel(for: child.pathEntry, locale: Self.locale)], "the menu lists \(titles)")
  }

  // MARK: - Reasoning

  /// A production change that fails this test: the expand button of a
  /// reasoning is a plain button whose title swaps, so VoiceOver reads no on
  /// or off state.
  @Test func aPressOfTheReasoningToggleTurnsItOn() throws {
    let entry = try #require(PreviewFixtures.firstEntry(in: .previewSample, as: ThoughtEntry.self))
    let store = ExpandedBlocksStore()
    store.collapse(entry: .thought(entry))
    let harness = Self.mount(ReasoningView(entry: entry).environment(\.expandedBlocksStore, store))
    defer { harness.close() }
    let toggle = ReasoningView.toggleIdentifier(for: entry.id.rowKey)

    try harness.perform(.press, on: toggle)

    #expect(harness.element(identifier: toggle)?.value == Self.toggleOnValue)
  }
}
