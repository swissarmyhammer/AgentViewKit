import AppKit
import ObjectiveC

// The context menu of a right click on Textual text (D193 (f)).
//
// Textual 0.5.0 gives its interaction view (`NSTextInteractionView`) its own
// context menu, with "Share…" and "Copy". The view is the hit view of a
// right click on a selectable text, so AppKit asks it first, and its menu
// covers the item menu of the kit (`.commandContextMenu` of
// `AgentItemScope`). The rule is that the context menu, the main menu and
// the palette show the same commands for the focused object.
//
// So the kit does two things, one time for the application:
//
// - It replaces the `menu(for:)` of the Textual class. The new method gives
//   the menu of the first view above the text that gives one, or else the
//   Textual menu. So each caller that asks the view for its menu, such as
//   VoiceOver or a test, gets the item menu.
// - An app-local event monitor sees each press that opens a context menu.
//   Textual's `rightMouseDown` shows its own menu with no call to
//   `menu(for:)`. So when the hit view of the press is a Textual
//   interaction view, the monitor shows the item menu and discards the
//   press. A press on a different view goes on as before.
//
// The `willOpen` hook of a `.commandContextMenu` runs from the EditorKit
// monitor of presses (and from the test harness), one time for each
// opening, so this lookup does not run it. Command-C still copies the
// selection of the text.

/// The monitor that gives a right click on Textual text the item menu of
/// the kit.
enum TextualContextMenu {
  /// The monitor of events, or `nil` before the first start.
  private static var monitor: Any?

  /// The classes whose `menu(for:)` the kit replaced.
  private static var overriddenClasses: Set<ObjectIdentifier> = []

  /// The class of the Textual interaction view, or `nil` when the pin of
  /// Textual has no class with the name.
  static var textualInteractionClass: AnyClass? {
    NSClassFromString("Textual." + TextualSelectionProbeView.interactionTypeName)
  }

  /// Starts the monitor and replaces the `menu(for:)` of the Textual class,
  /// one time. Both stay for the life of the application.
  static func start() {
    if let textual = textualInteractionClass {
      overrideMenu(of: textual)
    }
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
    return menuAbove(hit, for: event)
  }

  /// The menu of the first view above a view that gives one.
  ///
  /// - Parameters:
  ///   - view: The view.
  ///   - event: The press.
  /// - Returns: The view above and its menu, or `nil` when no view above
  ///   gives a menu.
  static func menuAbove(_ view: NSView, for event: NSEvent) -> (view: NSView, menu: NSMenu)? {
    let views = sequence(first: view, next: \.superview).dropFirst()
    return views.lazy.compactMap { view in view.menu(for: event).map { (view, $0) } }.first
  }

  /// Replaces the `menu(for:)` of a class, one time: the new method gives
  /// the menu of the first view above the view that gives one, or else the
  /// menu of the old method.
  ///
  /// - Parameter viewClass: A subclass of `NSView` that has its own
  ///   `menu(for:)`.
  static func overrideMenu(of viewClass: AnyClass) {
    guard overriddenClasses.insert(ObjectIdentifier(viewClass)).inserted else { return }
    let selector = #selector(NSView.menu(for:))
    guard let method = class_getInstanceMethod(viewClass, selector) else { return }
    typealias MenuFunction = @convention(c) (NSView, Selector, NSEvent) -> NSMenu?
    let original = unsafeBitCast(method_getImplementation(method), to: MenuFunction.self)
    let replacement: @convention(block) (NSView, NSEvent) -> NSMenu? = { view, event in
      nonisolated(unsafe) var menu: NSMenu?
      MainActor.assumeIsolated { menu = menuAbove(view, for: event)?.menu }
      return menu ?? original(view, selector, event)
    }
    // The class has its own method (`class_getInstanceMethod` found it on
    // the class), so the change does not touch `NSView`.
    method_setImplementation(method, imp_implementationWithBlock(replacement))
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
