import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsTestSupport
import EditorCommandsUI
import EditorTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// Tests for the header slot of a thread (TestudoApp D208 (i)): the host
/// view of `threadHeader(_:)` above the transcript, and the header of a
/// title and one command of `threadHeader(_:action:)` (TestudoApp D212).
///
/// Each test lays out a view in an `NSHostingView` with no window, so no
/// test shows a window or takes the focus.
@MainActor struct ThreadHeaderTests {
  /// The width of the thread of the tests.
  static let width: CGFloat = 900

  /// The height of the thread of the tests.
  static let height: CGFloat = 400

  /// A width that is too narrow for the whole title and the button on one
  /// line.
  static let narrowWidth: CGFloat = 160

  /// The title of the header of the host, as the host gives it.
  static let title = "Claude Code · read-only · Nov 21, 2026"

  /// The id of the command of the header.
  static let commandID = "test.continueInTestudo"

  /// The title of the command of the header, from the registry.
  static let commandTitle = "Continue in Testudo"

  /// The scope that holds the command of the header.
  static let scope = FocusSegment(kind: "threadHeaderTest")

  // MARK: - The view overload

  /// A production change that fails this test: the thread does not read
  /// the header of the environment, or does not show it in the top bar.
  @Test func theHeaderSlotShowsTheHostView() {
    let record = SlotProbeRecord()

    StyleViewHost.layOut(
      AgentThreadView(session: ReadOnlyThreadTests.readOnlyModel()) { EmptyView() }
        .threadHeader { SlotProbe(record: record) }
        .frame(width: Self.width, height: Self.height))

    #expect(record.isShown)
  }

  /// A production change that fails this test: the thread hides the header
  /// while it shows the unavailable message.
  @Test func theHeaderStaysInTheUnavailableState() {
    let record = SlotProbeRecord()

    StyleViewHost.layOut(
      AgentThreadView(session: ReadOnlyThreadTests.readOnlyModel()) { EmptyView() }
        .threadHeader { SlotProbe(record: record) }
        .threadUnavailable(ThreadUnavailableTests.message)
        .frame(width: Self.width, height: Self.height))

    #expect(record.isShown)
  }

  // MARK: - The title and command overload

  /// A production change that fails this test: the overload of a title and
  /// a command does not set the header of the environment.
  @Test func theTitleOverloadSetsTheHeaderOfTheEnvironment() {
    let record = SlotProbeRecord()

    StyleViewHost.layOut(
      ThreadHeaderValueProbe(record: record)
        .threadHeader(Self.title, action: Self.commandID))

    #expect(record.isShown)
  }

  /// A production change that fails this test: the header does not show the
  /// title, or shows it outside the group of the header.
  @Test func theHeaderGroupHasTheTitleText() async {
    let fixture = Fixture(definition: Fixture.available)

    let values = await fixture.headerValues()

    #expect(values.contains(Self.title))
  }

  /// A production change that fails this test: the button of the header does
  /// not bind the given command id, so the registry gives it no title.
  @Test func theButtonOfTheHeaderHasTheTitleOfTheCommand() async {
    let fixture = Fixture(definition: Fixture.available)

    let labels = await fixture.headerButtonLabels()

    #expect(labels == [Self.commandTitle])
  }

  /// A production change that fails this test: a press of the button of the
  /// header does not run the command through the registry.
  @Test func aPressOfTheButtonRunsTheCommand() async throws {
    let log = CommandRunLog()
    let fixture = Fixture(definition: .makeRecording(id: CommandID(Self.commandID), log: log))

    try await fixture.pressTheButton()

    #expect(log.runs.map(\.id) == [CommandID(Self.commandID)])
  }

  /// A production change that fails this test: the title of the header
  /// wraps, or the button wraps its title, at a narrow width.
  @Test func aNarrowHeaderKeepsTheHeightOfOneLine() throws {
    let wide = Fixture.size(width: Self.width)
    let narrow = Fixture.size(width: Self.narrowWidth)
    try #require(wide.height > 0)

    #expect(narrow.height == wide.height)
  }

  /// A production change that fails this test: the header is wider than a
  /// narrow width, so the title does not truncate.
  @Test func aNarrowHeaderFitsItsWidth() throws {
    let narrow = Fixture.size(width: Self.narrowWidth)
    try #require(narrow.height > 0)

    #expect(narrow.width <= Self.narrowWidth)
  }
}

// MARK: - Fixtures

extension ThreadHeaderTests {
  /// The header of a title and one command in the slot of the header, in a
  /// host with no window, with the command in the given registry.
  struct Fixture {
    /// The definition of an available command with the id and the title of
    /// the tests.
    static var available: CommandDefinition {
      .makeAlwaysAvailable(id: CommandID(commandID), title: commandTitle)
    }

    /// The command system of the header. The fixture keeps it, so the
    /// registry lives while the test reads the header.
    let system: CommandSystem

    /// The host of the header, with no window.
    let hosting: NSView

    /// Lays out the header with `definition` registered at the scope of the
    /// tests.
    ///
    /// - Parameter definition: The definition of the command of the header.
    init(definition: CommandDefinition) {
      let system = Self.system(with: definition)
      let hosting = NSHostingView(rootView: Self.root(system: system).frame(width: width))
      StyleViewHost.layOut(hosting)
      self.system = system
      self.hosting = hosting
    }

    /// A command system with `definition` registered at the scope of the
    /// tests.
    ///
    /// - Parameter definition: The definition of the command.
    /// - Returns: The system.
    static func system(with definition: CommandDefinition) -> CommandSystem {
      let system = CommandSystem()
      system.registry.register(definition, at: FocusPath.root(scope))
      return system
    }

    /// The header of the title and the command, in the slot of the header,
    /// in the scope of the tests.
    ///
    /// - Parameter system: The command system of the header.
    /// - Returns: The view.
    static func root(system: CommandSystem) -> some View {
      ThreadHeaderValueReader()
        .threadHeader(title, action: commandID)
        .commandScope(segment: scope)
        .commandSystem(system)
    }

    /// The size of the header with the command of the tests when its parent
    /// proposes `width`.
    ///
    /// - Parameter width: The proposed width, in points.
    /// - Returns: The size that the header takes.
    static func size(width: CGFloat) -> CGSize {
      StyleViewHost.size(of: root(system: system(with: available)), proposedWidth: width)
    }

    /// Reads the accessibility nodes of the header while the tree is built.
    ///
    /// - Parameter read: Reads each node under the group of the header, the
    ///   group too, depth first. The nodes are empty when no single element
    ///   has the identifier of the header.
    /// - Returns: The result of `read`.
    /// - Throws: The error of `read`.
    func readHeader<Result>(_ read: ([NSObject]) throws -> Result) async rethrows -> Result {
      try await withAccessibilityTree {
        let groups = accessibilityElements(
          identifiedAs: AgentThreadLayout.headerIdentifier, under: hosting)
        let nodes = groups.count == 1 ? groups.flatMap { accessibilitySubtree(of: $0) } : []
        return try read(nodes)
      }
    }

    /// The values of the nodes under the group of the header.
    ///
    /// - Returns: The values, depth first.
    func headerValues() async -> [String] {
      await readHeader { $0.compactMap(accessibilityValue(of:)) }
    }

    /// The labels of the buttons under the group of the header.
    ///
    /// - Returns: The labels, in tree order.
    func headerButtonLabels() async -> [String] {
      await readHeader { Self.buttons(in: $0).compactMap(accessibilityLabel(of:)) }
    }

    /// Presses the one button of the header, as VoiceOver does.
    ///
    /// - Throws: An error when the header has not one button, or the button
    ///   has no press.
    func pressTheButton() async throws {
      try await readHeader { nodes in
        let buttons = Self.buttons(in: nodes)
        let button = try #require(buttons.count == 1 ? buttons.first : nil)
        #expect(try performAccessibilityPress(on: button))
      }
    }

    /// The button nodes of `nodes`.
    ///
    /// - Parameter nodes: The accessibility nodes.
    /// - Returns: Each node whose role is `button`, in order.
    static func buttons(in nodes: [NSObject]) -> [NSObject] {
      nodes.filter { accessibilityRole(of: $0) == NSAccessibility.Role.button.rawValue }
    }
  }
}

/// A view that shows a ``SlotProbe`` when the environment has a header of a
/// thread.
struct ThreadHeaderValueProbe: View {
  /// The record that gets the show.
  let record: SlotProbeRecord

  /// The header of the environment, or `nil`.
  @Environment(\.threadHeader) private var header

  var body: some View {
    if header != nil {
      SlotProbe(record: record)
    }
  }
}

/// A view that shows the header of the environment in the slot of the
/// header, as ``AgentThreadView`` does.
struct ThreadHeaderValueReader: View {
  /// The header of the environment, or `nil`.
  @Environment(\.threadHeader) private var header

  var body: some View {
    if let header {
      ThreadHeaderSlot(header: header)
    }
  }
}
