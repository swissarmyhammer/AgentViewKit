import AppKit
import EditorCommandsUI

// The context menu of a right click on Textual text (D193 (f)).
//
// Textual 0.5.0 gives its interaction view (`NSTextInteractionView`) its own
// context menu, with "Share…" and "Copy". The view is the hit view of a
// right click on a selectable text, so AppKit asks it first, and its menu
// covers the item menu of the kit (`.commandContextMenu` of
// `AgentItemScope`). The rule is that the context menu, the main menu and
// the palette show the same commands for the focused object.
//
// So an app-local event monitor sees each press that opens a context menu.
// When the hit view of the press is a Textual interaction view, the monitor
// opens the menu of the first view above it that gives one, and discards
// the press. A press on a different view goes on as before. Command-C still
// copies the selection of the text.

/// The monitor that gives a right click on Textual text the item menu of
/// the kit.
enum TextualContextMenu {
  /// The monitor of events, or `nil` before the first start.
  private static var monitor: Any?

  /// Starts the monitor of the application, one time. It runs for the life
  /// of the application.
  static func start() {
    guard monitor == nil else { return }
    monitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .leftMouseDown]) { event in
      let shown = MainActor.assumeIsolated { showItemMenu(for: event) }
      return shown ? nil : event
    }
  }

  /// Tells if a press opens a context menu: a press of the right button, or
  /// a press of the left button with Control, as AppKit reads it.
  ///
  /// - Parameters:
  ///   - type: The type of the event.
  ///   - modifierFlags: The modifier keys of the event.
  /// - Returns: `true` for a press that opens a context menu.
  nonisolated static func opensMenu(type: NSEvent.EventType, modifierFlags: NSEvent.ModifierFlags) -> Bool {
    switch type {
    case .rightMouseDown: true
    case .leftMouseDown: modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.control)
    default: false
    }
  }

  /// The menu to show for a press on a view, in place of the menu of the
  /// view: for a Textual interaction view, the menu of the first view above
  /// it that gives one.
  ///
  /// - Parameters:
  ///   - event: The press.
  ///   - hit: The view under the press.
  /// - Returns: The view and its menu, or `nil` when the view keeps its own
  ///   menu: it is not Textual text, or no view above it gives a menu.
  static func itemMenu(for event: NSEvent, hit: NSView) -> (view: NSView, menu: NSMenu)? {
    guard String(describing: type(of: hit)) == TextualSelectionProbeView.interactionTypeName else { return nil }
    if let window = hit.window {
      // Runs the `willOpen` hook of the `.commandContextMenu` under the
      // press, as a right click on a different part of the item does.
      CommandContextMenuSiteView.prepareMenu(atWindowPoint: event.locationInWindow, in: window)
    }
    let views = sequence(first: hit, next: \.superview).dropFirst()
    return views.lazy.compactMap { view in view.menu(for: event).map { (view, $0) } }.first
  }

  /// Shows the item menu for a press on Textual text.
  ///
  /// - Parameter event: The event.
  /// - Returns: `true` when the monitor showed the menu, so that the window
  ///   gets no event.
  private static func showItemMenu(for event: NSEvent) -> Bool {
    guard opensMenu(type: event.type, modifierFlags: event.modifierFlags), let window = event.window,
      let hit = window.contentView?.superview?.hitTest(event.locationInWindow),
      let (view, menu) = itemMenu(for: event, hit: hit)
    else { return false }
    NSMenu.popUpContextMenu(menu, with: event, for: view)
    return true
  }
}
