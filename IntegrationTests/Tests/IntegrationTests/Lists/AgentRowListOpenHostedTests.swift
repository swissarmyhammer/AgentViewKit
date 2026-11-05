import AppKit
import EditorCommands
import EditorCommandsUI
import EditorStyle
import EditorTestSupport
import SwiftUI
import Testing

@testable import AgentViewKit

/// The window of one test: two rows that open on `trigger`, beside a scope that
/// stands for the tab of the host, in the harness window, which is never
/// ordered in and never key.
///
/// A test drives a row through its accessibility action and the keys. Only the
/// tests of ``AgentRowListOpenPointerHostedTests`` click: SwiftUI reads a tap
/// gesture only from the dispatch of a window that is ordered in, and
/// `NSApp.currentEvent` holds an event only on the path of the event queue, so
/// their click goes through the queue of the app
/// (`HostedViewHarness.sendClick(atWindowPoint:)`). The click orders the window
/// in behind every window and off the screen, and the window stays not key.
@MainActor private struct OpenBed {
  /// The ids of the rows, in list order.
  static let ids = ["first", "second"]

  /// The list of the bed.
  static let scope = AgentRowListScope(list: FocusSegment(kind: "openList"), rowKind: "openRow")

  /// The path of the scope of the tab.
  static let tabPath = FocusPath.root(FocusSegment(kind: "openTab"))

  /// The command system of the window.
  let system: CommandSystem

  /// The id of each open, in order.
  let opened: ReportRecorder<String>

  /// The harness that shows the window.
  let harness: HostedViewHarness<AnyView>

  /// Mounts the list and the tab, and waits for the beacons of their scopes.
  ///
  /// - Parameters:
  ///   - trigger: What opens a row.
  ///   - opens: Whether the rows open, or the list has no `onOpen`.
  ///   - movesFocusOnOpen: Whether an open gives the focus to the tab, as a
  ///     host does when it shows the opened item.
  init(trigger: AgentRowOpenTrigger, opens: Bool = true, movesFocusOnOpen: Bool = true) async throws {
    let system = CommandSystem()
    let opened = ReportRecorder<String>()
    let report = opened.report
    self.system = system
    self.opened = opened
    let open = { (id: String) in
      report(id)
      if movesFocusOnOpen { _ = system.geometry.requestFocus(at: Self.tabPath) }
    }
    harness = HostedViewHarness(
      AnyView(
        HStack {
          AgentRowList(Self.ids, id: \.self, scope: Self.scope, openOn: trigger, onOpen: opens ? open : nil) { id in
            Text(id).accessibilityIdentifier(id)
          }
          Color.clear.commandScope(segment: Self.tabPath.segments[0])
        }
        .commandSystem(system)))
    await RunLoopBlockFence.afterPendingBlocks()
    try #require(waitForLiveBeacons([Self.tabPath, Self.rowPath(0), Self.rowPath(1)], in: system))
  }

  /// The path of the scope of the row at `index`.
  ///
  /// - Parameter index: The index of the row.
  /// - Returns: The path of the row.
  static func rowPath(_ index: Int) -> FocusPath {
    scope.path(ofRow: ids[index])
  }

  /// The center of the text of the row at `index`, in window coordinates.
  ///
  /// - Parameter index: The index of the row.
  /// - Returns: The point.
  func textCenter(ofRow index: Int) throws -> NSPoint {
    let frame = try #require(harness.frame(identifier: Self.ids[index]))
    return harness.window.convertPoint(fromScreen: NSPoint(x: frame.midX, y: frame.midY))
  }

  /// A point in the leading padding of the row at `index`, outside the text,
  /// in window coordinates.
  ///
  /// - Parameter index: The index of the row.
  /// - Returns: The point.
  func paddingPoint(ofRow index: Int) throws -> NSPoint {
    let row = try #require(system.geometry.rect(of: Self.rowPath(index)))
    let inset = EditorStyle.default.tile.padding / 2
    return NSPoint(x: row.minX + inset, y: harness.window.frame.height - row.midY)
  }

  /// The scope among the tab and the rows that holds the first responder of
  /// the window.
  ///
  /// - Returns: The path of the scope, or `nil` when none of them holds it.
  func focusedScope() -> FocusPath? {
    guard let responder = harness.window.firstResponder as? NSView,
      let frame = WindowSpace.rect(of: responder)
    else { return nil }
    return [Self.tabPath, Self.rowPath(0), Self.rowPath(1)].first { system.geometry.rect(of: $0) == frame }
  }
}

/// `openOn: .click` of ``AgentRowList``, through the accessibility action of a
/// row and the keys: the action opens a row, and Return and the arrows act on
/// the focused row.
@Suite(.serialized, .hostedSerially) @MainActor struct AgentRowListOpenHostedTests {
  @Test func theOpenActionOpensTheRow() async throws {
    let bed = try await OpenBed(trigger: .click)
    defer { bed.harness.close() }

    let row = OpenBed.scope.rowIdentifier(for: OpenBed.ids[1])
    try bed.harness.perform(.custom(AgentRowClicks.openActionName), on: row)

    #expect(bed.opened.values == [OpenBed.ids[1]])
  }

  /// An assistive client opens a row of a list that opens on a double click
  /// with one action, as Return does.
  @Test func theOpenActionOpensARowOfADoubleClickList() async throws {
    let bed = try await OpenBed(trigger: .doubleClick)
    defer { bed.harness.close() }

    let row = OpenBed.scope.rowIdentifier(for: OpenBed.ids[0])
    try bed.harness.perform(.custom(AgentRowClicks.openActionName), on: row)

    #expect(bed.opened.values == [OpenBed.ids[0]])
  }

  /// A list with no `onOpen` names the action of a row Select, and it selects
  /// the row, as a click does.
  @Test func theSelectActionOfARowThatDoesNotOpenSelectsIt() async throws {
    let bed = try await OpenBed(trigger: .click, opens: false)
    defer { bed.harness.close() }

    let row = OpenBed.scope.rowIdentifier(for: OpenBed.ids[1])
    try bed.harness.perform(.custom(AgentRowClicks.selectActionName), on: row)

    #expect(bed.focusedScope() == OpenBed.rowPath(1))
  }

  @Test func returnOpensTheSelectedRow() async throws {
    let bed = try await OpenBed(trigger: .click)
    defer { bed.harness.close() }
    try #require(bed.system.geometry.requestFocus(at: OpenBed.rowPath(1)))
    bed.harness.render()

    try bed.harness.sendKey(.return)

    #expect(bed.opened.values == [OpenBed.ids[1]])
  }

  @Test func theDownArrowMovesTheSelection() async throws {
    let bed = try await OpenBed(trigger: .click)
    defer { bed.harness.close() }
    try #require(bed.system.geometry.requestFocus(at: OpenBed.rowPath(0)))
    bed.harness.render()

    try bed.harness.sendKey(.downArrow)

    #expect(bed.focusedScope() == OpenBed.rowPath(1))
  }
}

/// The mouse of ``AgentRowOpenTrigger``, which only a real click reaches: one
/// click opens a row wherever it lands on the row, the click count of the event
/// tells the clicks of a double click apart, and the press of a click leaves
/// the focus where `onOpen` puts it.
///
/// Each test clicks through the event queue of the app, so it orders the
/// window in behind every window and off the screen; the window stays not key
/// and takes no focus from the user. Each suite whose name ends in
/// `PointerHostedTests` holds such a click.
@Suite(.serialized, .hostedSerially) @MainActor struct AgentRowListOpenPointerHostedTests {
  @Test func oneClickOnThePaddingOpensTheRow() async throws {
    let bed = try await OpenBed(trigger: .click)
    defer { bed.harness.close() }

    try await bed.harness.sendClick(atWindowPoint: bed.paddingPoint(ofRow: 0))

    #expect(bed.opened.values == [OpenBed.ids[0]])
  }

  @Test func aDoubleClickOpensTheRowOnce() async throws {
    let bed = try await OpenBed(trigger: .click)
    defer { bed.harness.close() }

    try await bed.harness.sendClick(atWindowPoint: bed.textCenter(ofRow: 0), clickCounts: [1, 2])

    #expect(bed.opened.values == [OpenBed.ids[0]])
  }

  @Test func theFocusStaysOnTheOpenedItemAfterAClick() async throws {
    let bed = try await OpenBed(trigger: .click)
    defer { bed.harness.close() }

    try await bed.harness.sendClick(atWindowPoint: bed.textCenter(ofRow: 0))

    #expect(bed.focusedScope() == OpenBed.tabPath)
  }

  /// The press of the second click comes after the host moved the focus, so
  /// this is where a row that takes the focus from a press takes it back.
  @Test func theFocusStaysOnTheOpenedItemAfterADoubleClick() async throws {
    let bed = try await OpenBed(trigger: .click)
    defer { bed.harness.close() }

    try await bed.harness.sendClick(atWindowPoint: bed.textCenter(ofRow: 0), clickCounts: [1, 2])

    #expect(bed.focusedScope() == OpenBed.tabPath)
  }

  @Test func aClickDoesNotSelectTheRowWhenTheHostMovesNoFocus() async throws {
    let bed = try await OpenBed(trigger: .click, movesFocusOnOpen: false)
    defer { bed.harness.close() }

    try await bed.harness.sendClick(atWindowPoint: bed.textCenter(ofRow: 0))

    #expect(bed.focusedScope() != OpenBed.rowPath(0))
  }

  /// The default stays: one click selects the row and opens nothing.
  @Test func byDefaultOneClickSelectsTheRow() async throws {
    let bed = try await OpenBed(trigger: .doubleClick)
    defer { bed.harness.close() }

    try await bed.harness.sendClick(atWindowPoint: bed.textCenter(ofRow: 0))

    #expect(bed.opened.values.isEmpty)
    #expect(bed.focusedScope() == OpenBed.rowPath(0))
  }

  /// The default stays: the second click of a double click opens the row.
  @Test func byDefaultADoubleClickOpensTheRow() async throws {
    let bed = try await OpenBed(trigger: .doubleClick)
    defer { bed.harness.close() }

    try await bed.harness.sendClick(atWindowPoint: bed.textCenter(ofRow: 0), clickCounts: [1, 2])

    #expect(bed.opened.values == [OpenBed.ids[0]])
  }
}
