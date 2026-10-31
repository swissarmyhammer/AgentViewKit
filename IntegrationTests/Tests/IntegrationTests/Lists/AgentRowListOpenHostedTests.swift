import AppKit
import EditorCommands
import EditorCommandsUI
import EditorStyle
import EditorTestSupport
import SwiftUI
import Testing

@testable import AgentViewKit

/// The window of one test: two rows that open on `trigger`, beside a scope that
/// stands for the tab of the host, in a real key window off the screen.
///
/// SwiftUI starts a tap gesture only in a key window, and `NSApp.currentEvent`
/// holds an event only on the path of the event queue. So a click here goes
/// through the queue of the app, as a click of a person does, and not through
/// `HostedViewHarness.click(at:timeLimit:)`.
@MainActor private struct OpenBed {
  /// The ids of the rows, in list order.
  static let ids = ["first", "second"]

  /// The size of the window.
  static let size = CGSize(width: 300, height: 300)

  /// The list of the bed.
  static let scope = AgentRowListScope(list: FocusSegment(kind: "openList"), rowKind: "openRow")

  /// The path of the scope of the tab.
  static let tabPath = FocusPath.root(FocusSegment(kind: "openTab"))

  /// The time a click of the bed may take to reach the window, in seconds.
  static let eventTimeLimit: TimeInterval = 5

  /// The command system of the window.
  let system: CommandSystem

  /// The id of each open, in order.
  let opened: ReportRecorder<String>

  /// The harness that shows the window.
  let harness: HostedViewHarness<AnyView>

  /// Mounts the list and the tab, and makes the window key.
  ///
  /// - Parameters:
  ///   - trigger: What opens a row.
  ///   - movesFocusOnOpen: Whether an open gives the focus to the tab, as a
  ///     host does when it shows the opened item.
  init(trigger: AgentRowOpenTrigger, movesFocusOnOpen: Bool = true) async throws {
    let system = CommandSystem()
    let opened = ReportRecorder<String>()
    let report = opened.report
    self.system = system
    self.opened = opened
    harness = HostedViewHarness(
      AnyView(
        HStack {
          AgentRowList(Self.ids, id: \.self, scope: Self.scope, openOn: trigger) { id in
            report(id)
            if movesFocusOnOpen { _ = system.geometry.requestFocus(at: Self.tabPath) }
          } row: { id in
            Text(id).accessibilityIdentifier(id)
          }
          Color.clear.commandScope(segment: Self.tabPath.segments[0])
        }
        .commandSystem(system)),
      size: Self.size)
    harness.window.makeKeyAndOrderFront(nil)
    await RunLoopBlockFence.afterPendingBlocks()
    try #require(waitForLiveBeacons([Self.tabPath, Self.rowPath(0), Self.rowPath(1)], in: system))
  }

  /// The path of the scope of the row at `index`.
  ///
  /// - Parameter index: The index of the row.
  /// - Returns: The path of the row.
  static func rowPath(_ index: Int) -> FocusPath {
    FocusPath.root(scope.list).appending(scope.rowSegment(for: ids[index]))
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

  /// Sends one press and release of the mouse for each number in
  /// `clickCounts`, at `point`, through the event queue of the app.
  ///
  /// `postEvent(_:atStart:)` stops the main run loop, which would end the
  /// process in its outermost run, so the clicks run in a nested run. Each
  /// click sets `NSApp.currentEvent` on its way to the window, as in an app.
  ///
  /// - Parameters:
  ///   - point: The point, in window coordinates.
  ///   - clickCounts: The click count of each press, such as `[1, 2]` for a
  ///     double click.
  func click(at point: NSPoint, clickCounts: [Int] = [1]) async {
    OpenBed.deliver(clickCounts.flatMap { events(at: point, clickCount: $0) })
    await RunLoopBlockFence.afterPendingBlocks()
    harness.render()
  }

  /// The press and the release of one click.
  ///
  /// - Parameters:
  ///   - point: The point, in window coordinates.
  ///   - clickCount: The click count of the events.
  /// - Returns: The two events.
  private func events(at point: NSPoint, clickCount: Int) -> [NSEvent] {
    [(NSEvent.EventType.leftMouseDown, Float(1)), (.leftMouseUp, Float(0))].compactMap { type, pressure in
      NSEvent.mouseEvent(
        with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: harness.window.windowNumber, context: nil, eventNumber: 0, clickCount: clickCount,
        pressure: pressure)
    }
  }

  /// Posts `events` and dispatches each one, in a nested run of the main run
  /// loop.
  ///
  /// - Parameter events: The events.
  private static func deliver(_ events: [NSEvent]) {
    var isDone = false
    let dispatch: @MainActor () -> Void = {
      events.forEach { NSApp.postEvent($0, atStart: false) }
      for _ in events {
        let limit = Date(timeIntervalSinceNow: eventTimeLimit)
        if let event = NSApp.nextEvent(
          matching: [.leftMouseDown, .leftMouseUp], until: limit, inMode: .default, dequeue: true)
        {
          NSApp.sendEvent(event)
        }
      }
      isDone = true
    }
    CFRunLoopPerformBlock(CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue) {
      MainActor.assumeIsolated { dispatch() }
    }
    while !isDone { _ = CFRunLoopRunInMode(.defaultMode, eventTimeLimit, true) }
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

/// `openOn: .click` of ``AgentRowList``: one click opens a row, wherever it
/// lands on the row, and the focus stays where `onOpen` puts it.
@Suite(.serialized, .hostedSerially) @MainActor struct AgentRowListOpenHostedTests {
  @Test func oneClickOnTheTextOpensTheRow() async throws {
    let bed = try await OpenBed(trigger: .click)
    defer { bed.harness.close() }

    await bed.click(at: try bed.textCenter(ofRow: 1))

    #expect(bed.opened.values == [OpenBed.ids[1]])
  }

  @Test func oneClickOnThePaddingOpensTheRow() async throws {
    let bed = try await OpenBed(trigger: .click)
    defer { bed.harness.close() }

    await bed.click(at: try bed.paddingPoint(ofRow: 0))

    #expect(bed.opened.values == [OpenBed.ids[0]])
  }

  @Test func aDoubleClickOpensTheRowOnce() async throws {
    let bed = try await OpenBed(trigger: .click)
    defer { bed.harness.close() }

    await bed.click(at: try bed.textCenter(ofRow: 0), clickCounts: [1, 2])

    #expect(bed.opened.values == [OpenBed.ids[0]])
  }

  @Test func theFocusStaysOnTheOpenedItemAfterAClick() async throws {
    let bed = try await OpenBed(trigger: .click)
    defer { bed.harness.close() }

    await bed.click(at: try bed.textCenter(ofRow: 0))

    #expect(bed.focusedScope() == OpenBed.tabPath)
  }

  /// The press of the second click comes after the host moved the focus, so
  /// this is where a row that takes the focus from a press takes it back.
  @Test func theFocusStaysOnTheOpenedItemAfterADoubleClick() async throws {
    let bed = try await OpenBed(trigger: .click)
    defer { bed.harness.close() }

    await bed.click(at: try bed.textCenter(ofRow: 0), clickCounts: [1, 2])

    #expect(bed.focusedScope() == OpenBed.tabPath)
  }

  @Test func aClickDoesNotSelectTheRowWhenTheHostMovesNoFocus() async throws {
    let bed = try await OpenBed(trigger: .click, movesFocusOnOpen: false)
    defer { bed.harness.close() }

    await bed.click(at: try bed.textCenter(ofRow: 0))

    #expect(bed.focusedScope() != OpenBed.rowPath(0))
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

  /// The default stays: one click selects the row and opens nothing.
  @Test func byDefaultOneClickSelectsTheRow() async throws {
    let bed = try await OpenBed(trigger: .doubleClick)
    defer { bed.harness.close() }

    await bed.click(at: try bed.textCenter(ofRow: 0))

    #expect(bed.opened.values.isEmpty)
    #expect(bed.focusedScope() == OpenBed.rowPath(0))
  }

  /// The default stays: the second click of a double click opens the row.
  @Test func byDefaultADoubleClickOpensTheRow() async throws {
    let bed = try await OpenBed(trigger: .doubleClick)
    defer { bed.harness.close() }

    await bed.click(at: try bed.textCenter(ofRow: 0), clickCounts: [1, 2])

    #expect(bed.opened.values == [OpenBed.ids[0]])
  }
}
