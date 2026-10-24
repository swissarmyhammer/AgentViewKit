import AgentViewKitTestSupport
import AppKit
import Testing

/// Tests of the one key event factory that the test support and the tests
/// share.
@Suite @MainActor struct NSEventKeyEventTests {
  /// The virtual key code of the `C` key on an ANSI keyboard.
  static let cKeyCode = AgentMainMenuHostedTests.cKeyCode

  /// The window number that the window test gives the event.
  static let windowNumber = 7

  /// The timestamp that the window test gives the event.
  static let timestamp: TimeInterval = 42

  @Test func aKeyEventIsAKeyDownWithItsCharactersKeyCodeAndModifiers() throws {
    let event = try #require(
      NSEvent.makeKeyEvent(characters: "C", keyCode: Self.cKeyCode, modifiers: [.command, .shift]))

    #expect(event.type == .keyDown)
    #expect(event.characters == "C")
    #expect(event.charactersIgnoringModifiers == "C")
    #expect(event.keyCode == Self.cKeyCode)
    #expect(event.modifierFlags == [.command, .shift])
    #expect(event.windowNumber == 0)
    #expect(event.timestamp == 0)
    #expect(!event.isARepeat)
  }

  @Test func aKeyEventKeepsTheCharactersIgnoringModifiersThatItIsGiven() throws {
    let event = try #require(
      NSEvent.makeKeyEvent(
        characters: "[", charactersIgnoringModifiers: "{", keyCode: Self.cKeyCode, modifiers: .command))

    #expect(event.characters == "[")
    #expect(event.charactersIgnoringModifiers == "{")
  }

  @Test func aKeyEventHasTheTypeWindowAndTimestampThatItIsGiven() throws {
    let event = try #require(
      NSEvent.makeKeyEvent(
        .keyUp, characters: "c", keyCode: Self.cKeyCode, modifiers: [],
        timestamp: Self.timestamp, windowNumber: Self.windowNumber))

    #expect(event.type == .keyUp)
    #expect(event.windowNumber == Self.windowNumber)
    #expect(event.timestamp == Self.timestamp)
  }
}
