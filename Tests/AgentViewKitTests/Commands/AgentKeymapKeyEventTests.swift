import AppKit
@testable import AgentViewKit
import EditorCommands
import EditorCommandsUI
import Testing

/// Tests that a real Command-Shift-[ and Command-Shift-] key event spells
/// the default chord of its verb through the EditorKit translator.
///
/// The translator spells the chord from `charactersIgnoringModifiers`. On a
/// US keyboard, Shift changes that value of the bracket keys to `{` and `}`.
@MainActor struct AgentKeymapKeyEventTests {
  /// The virtual key code of the `[` key on an ANSI keyboard.
  static let leftBracketKeyCode: UInt16 = 0x21

  /// The virtual key code of the `]` key on an ANSI keyboard.
  static let rightBracketKeyCode: UInt16 = 0x1E

  /// Makes a Command-Shift key-down event.
  ///
  /// - Parameters:
  ///   - characters: The characters of the event.
  ///   - ignoringModifiers: The characters with no modifiers but Shift.
  ///   - keyCode: The virtual key code.
  /// - Returns: The event.
  static func commandShiftEvent(
    characters: String, ignoringModifiers: String, keyCode: UInt16
  ) throws -> NSEvent {
    try #require(
      NSEvent.keyEvent(
        with: .keyDown, location: .zero, modifierFlags: [.command, .shift], timestamp: 0,
        windowNumber: 0, context: nil, characters: characters,
        charactersIgnoringModifiers: ignoringModifiers, isARepeat: false, keyCode: keyCode))
  }

  @Test func commandShiftLeftBracketSpellsThePreviousRequestChord() throws {
    let event = try Self.commandShiftEvent(
      characters: "[", ignoringModifiers: "{", keyCode: Self.leftBracketKeyCode)

    let chord = try #require(KeyChordTranslator.chord(for: event))

    #expect(chord == AgentKeymap.defaultChords[.previousRequest])
    #expect(
      AgentKeymap.defaultKeymap.bindings(for: chord.asSequence).map(\.action)
        == [.command(AgentCommandVerb.previousRequest.id)])
  }

  @Test func commandShiftRightBracketSpellsTheNextRequestChord() throws {
    let event = try Self.commandShiftEvent(
      characters: "]", ignoringModifiers: "}", keyCode: Self.rightBracketKeyCode)

    let chord = try #require(KeyChordTranslator.chord(for: event))

    #expect(chord == AgentKeymap.defaultChords[.nextRequest])
    #expect(
      AgentKeymap.defaultKeymap.bindings(for: chord.asSequence).map(\.action)
        == [.command(AgentCommandVerb.nextRequest.id)])
  }
}
