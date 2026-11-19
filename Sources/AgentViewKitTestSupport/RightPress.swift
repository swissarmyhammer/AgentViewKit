import AppKit
import Testing

/// The right mouse-down event that a test makes to read the menu of a view.
///
/// The test gives the event to `NSView.menu(for:)` and never posts it. Thus
/// no window comes on the screen and no window takes the focus. The unit
/// tests and the hosted tests make each right press here, and keep no copy
/// of their own.
public enum RightPress {
  /// The window number of a press on a view that has no window.
  static let noWindowNumber = 0

  /// The event number of the press.
  static let eventNumber = 0

  /// The click count of one right click.
  static let clickCount = 1

  /// The pressure of a right press.
  static let pressure: Float = 1

  /// The time stamp of the press.
  static let timestamp: TimeInterval = 0

  /// Makes a right press at the center of `view`.
  ///
  /// The press has the window number of the window of `view`. A view with no
  /// window gets a press with no window.
  ///
  /// - Parameter view: The view under the press.
  /// - Returns: The press, in the coordinates of the window of `view`.
  /// - Throws: An error when AppKit makes no event.
  public static func makeEvent(atCenterOf view: NSView) throws -> NSEvent {
    try makeEvent(at: NSPoint(x: view.bounds.midX, y: view.bounds.midY), in: view)
  }

  /// Makes a right press at `point` of `view`.
  ///
  /// The press has the window number of the window of `view`. A view with no
  /// window gets a press with no window.
  ///
  /// - Parameters:
  ///   - point: The point of the press, in the coordinates of `view`.
  ///   - view: The view under the press.
  /// - Returns: The press, in the coordinates of the window of `view`.
  /// - Throws: An error when AppKit makes no event.
  public static func makeEvent(at point: NSPoint, in view: NSView) throws -> NSEvent {
    let location = view.convert(point, to: nil)
    return try #require(
      NSEvent.mouseEvent(
        with: .rightMouseDown, location: location, modifierFlags: [], timestamp: timestamp,
        windowNumber: view.window?.windowNumber ?? noWindowNumber, context: nil,
        eventNumber: eventNumber, clickCount: clickCount, pressure: pressure))
  }
}
