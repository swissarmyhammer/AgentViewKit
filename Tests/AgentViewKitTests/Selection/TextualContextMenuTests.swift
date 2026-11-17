@testable import AgentViewKit
import AppKit
import Testing

/// A view with the type name of the Textual interaction view, as the hit
/// view of a right click on a selectable text.
private final class NSTextInteractionView: NSView {
  /// The menu that the view gives, as Textual gives "Share…" and "Copy".
  let ownMenu = NSMenu(title: "Textual")

  override func menu(for event: NSEvent) -> NSMenu? { ownMenu }
}

/// A view that gives a menu, as the hosting view gives the item menu.
private final class MenuView: NSView {
  /// The menu of the view.
  let itemMenu = NSMenu(title: "Item")

  override func menu(for event: NSEvent) -> NSMenu? { itemMenu }
}

/// A right click on the Textual text of a message shows the item menu of
/// the kit, not the menu of Textual (D193 (f)).
@MainActor @Suite struct TextualContextMenuTests {
  /// A right click at the origin, in no window.
  static func rightClick(_ type: NSEvent.EventType = .rightMouseDown, modifiers: NSEvent.ModifierFlags = [])
    throws -> NSEvent
  {
    try #require(
      NSEvent.mouseEvent(
        with: type, location: .zero, modifierFlags: modifiers, timestamp: 0, windowNumber: 0, context: nil,
        eventNumber: 0, clickCount: 1, pressure: 1))
  }

  @Test func aRightPressOpensAMenu() {
    #expect(TextualContextMenu.opensMenu(type: .rightMouseDown, modifierFlags: []))
  }

  @Test func aControlLeftPressOpensAMenu() {
    #expect(TextualContextMenu.opensMenu(type: .leftMouseDown, modifierFlags: [.control]))
  }

  @Test func aLeftPressOpensNoMenu() {
    #expect(!TextualContextMenu.opensMenu(type: .leftMouseDown, modifierFlags: [.command]))
  }

  @Test func theMenuOfAClickOnTextualTextIsTheMenuOfAViewAboveIt() throws {
    let item = MenuView()
    let plain = NSView()
    let text = NSTextInteractionView()
    item.addSubview(plain)
    plain.addSubview(text)

    let found = try #require(TextualContextMenu.itemMenu(for: Self.rightClick(), hit: text))

    #expect(found.menu === item.itemMenu)
    #expect(found.view === item)
  }

  @Test func aClickOnOtherViewsKeepsItsOwnMenu() throws {
    let item = MenuView()
    let other = NSView()
    item.addSubview(other)

    #expect(TextualContextMenu.itemMenu(for: try Self.rightClick(), hit: other) == nil)
  }

  @Test func textualTextWithNoMenuAboveItKeepsTheTextualMenu() throws {
    let plain = NSView()
    let text = NSTextInteractionView()
    plain.addSubview(text)

    #expect(TextualContextMenu.itemMenu(for: try Self.rightClick(), hit: text) == nil)
  }
}
