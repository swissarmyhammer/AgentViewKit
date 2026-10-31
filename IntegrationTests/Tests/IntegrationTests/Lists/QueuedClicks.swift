import AppKit
import EditorTestSupport

/// Clicks that go through the event queue of the app, as a click of a person
/// does.
///
/// SwiftUI starts a tap gesture only in a key window, and `NSApp.currentEvent`
/// holds an event only on the path of the event queue, so a row that opens on a
/// click needs these, and not `HostedViewHarness.click(at:timeLimit:)`.
@MainActor enum QueuedClicks {
  /// The time a click may take to reach the window, in seconds.
  private static let eventTimeLimit: TimeInterval = 5

  /// Sends one press and release of the mouse for each number in
  /// `clickCounts`, at `point`.
  ///
  /// - Parameters:
  ///   - point: The point, in window coordinates.
  ///   - clickCounts: The click count of each press, such as `[1, 2]` for a
  ///     double click.
  ///   - window: The window.
  static func click(at point: NSPoint, clickCounts: [Int] = [1], in window: NSWindow) async {
    deliver(clickCounts.flatMap { events(at: point, clickCount: $0, in: window) })
    await RunLoopBlockFence.afterPendingBlocks()
  }

  /// The press and the release of one click.
  ///
  /// - Parameters:
  ///   - point: The point, in window coordinates.
  ///   - clickCount: The click count of the events.
  ///   - window: The window.
  /// - Returns: The two events.
  private static func events(at point: NSPoint, clickCount: Int, in window: NSWindow) -> [NSEvent] {
    [(NSEvent.EventType.leftMouseDown, Float(1)), (.leftMouseUp, Float(0))].compactMap { type, pressure in
      NSEvent.mouseEvent(
        with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: clickCount,
        pressure: pressure)
    }
  }

  /// Posts `events` and dispatches each one, in a nested run of the main run
  /// loop.
  ///
  /// `postEvent(_:atStart:)` stops the main run loop, which would end the
  /// process in its outermost run, so the clicks run in a nested run. Each
  /// click sets `NSApp.currentEvent` on its way to the window, as in an app.
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
}
