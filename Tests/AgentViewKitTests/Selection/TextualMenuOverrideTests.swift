@testable import AgentViewKit
import AppKit
import Testing

/// A stand-in for the Textual interaction view: a view that gives its own
/// menu. The override replaces the method of this class only.
private class OwnMenuTextView: NSView {
  /// The menu that the view gives, as Textual gives "Share…" and "Copy".
  static let ownMenu = NSMenu(title: "Textual")

  override func menu(for event: NSEvent) -> NSMenu? { Self.ownMenu }
}

/// A view that gives a menu, as the hosting view gives the item menu.
private final class ItemMenuView: NSView {
  /// The menu of the view.
  let itemMenu = NSMenu(title: "Item")

  override func menu(for event: NSEvent) -> NSMenu? { itemMenu }
}

/// The `menu(for:)` of the Textual interaction view gives the item menu, so
/// that each caller that asks the view for its menu, such as VoiceOver,
/// gets the item menu (D193 (f)).
@MainActor @Suite(.serialized) struct TextualMenuOverrideTests {
  /// A right press at the origin, in no window.
  static func rightPress() throws -> NSEvent {
    try #require(
      NSEvent.mouseEvent(
        with: .rightMouseDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
        eventNumber: 0, clickCount: 1, pressure: 1))
  }

  init() {
    TextualContextMenu.overrideMenu(of: OwnMenuTextView.self)
  }

  @Test func theTextGivesTheMenuOfAViewAboveIt() throws {
    let item = ItemMenuView()
    let plain = NSView()
    let text: NSView = OwnMenuTextView()
    item.addSubview(plain)
    plain.addSubview(text)

    #expect(text.menu(for: try Self.rightPress()) === item.itemMenu)
  }

  @Test func theTextWithNoMenuAboveItGivesItsOwnMenu() throws {
    let plain = NSView()
    let text: NSView = OwnMenuTextView()
    plain.addSubview(text)

    #expect(text.menu(for: try Self.rightPress()) === OwnMenuTextView.ownMenu)
  }

  @Test func aSecondOverrideChangesNothing() throws {
    TextualContextMenu.overrideMenu(of: OwnMenuTextView.self)
    let item = ItemMenuView()
    let text: NSView = OwnMenuTextView()
    item.addSubview(text)

    #expect(text.menu(for: try Self.rightPress()) === item.itemMenu)
  }

  @Test func theTextualClassIsFound() {
    #expect(TextualContextMenu.textualInteractionClass != nil)
  }
}
