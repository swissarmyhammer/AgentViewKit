import AppKit
@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorCommands
import EditorCommandsUI
import EditorTestSupport
import Testing

/// Tests that a real Control-Command key event spells the default chord of
/// its verb through the EditorKit translator.
///
/// The translator spells the chord from `charactersIgnoringModifiers`. Control
/// does not change that value of the bracket keys and the C key, and an arrow
/// key reports its function-key character, so each event spells the
/// `StandardChords` chord of its verb.
@MainActor struct AgentKeymapKeyEventTests {
  /// One key of the test: the characters that AppKit reports for it with
  /// Control and Command held, and its virtual key code.
  nonisolated struct Key: Sendable, CustomTestStringConvertible {
    /// The characters of the event. Control changes `[`, `]` and `c` to a
    /// control character.
    let characters: String
    /// The characters with no modifiers but Shift.
    let ignoringModifiers: String
    /// The virtual key code on an ANSI keyboard.
    let keyCode: UInt16
    /// The modifier flags that AppKit adds for the key itself: the
    /// function-key and the numeric-pad flags of an arrow key.
    let keyFlags: NSEvent.ModifierFlags
    /// The verb whose default chord the event spells.
    let verb: AgentCommandVerb

    var testDescription: String { verb.rawValue }
  }

  /// The virtual key code of the `C` key on an ANSI keyboard.
  nonisolated static let cKeyCode: UInt16 = 0x08

  /// The virtual key code of the Up Arrow key.
  nonisolated static let upArrowKeyCode: UInt16 = 0x7E

  /// The virtual key code of the Down Arrow key.
  nonisolated static let downArrowKeyCode: UInt16 = 0x7D

  /// The virtual key code of the `[` key on an ANSI keyboard.
  nonisolated static let leftBracketKeyCode: UInt16 = 0x21

  /// The virtual key code of the `]` key on an ANSI keyboard.
  nonisolated static let rightBracketKeyCode: UInt16 = 0x1E

  /// The flags that AppKit sets on an arrow key event.
  nonisolated static let arrowFlags: NSEvent.ModifierFlags = [.function, .numericPad]

  /// The keys of the agent verbs that use Control-Command.
  nonisolated static let keys: [Key] = [
    Key(characters: "\u{03}", ignoringModifiers: "c", keyCode: cKeyCode, keyFlags: [], verb: .copyThread),
    Key(
      characters: "\u{F700}", ignoringModifiers: "\u{F700}", keyCode: upArrowKeyCode, keyFlags: arrowFlags,
      verb: .jumpToPrevious),
    Key(
      characters: "\u{F701}", ignoringModifiers: "\u{F701}", keyCode: downArrowKeyCode, keyFlags: arrowFlags,
      verb: .jumpToNext),
    Key(characters: "\u{1B}", ignoringModifiers: "[", keyCode: leftBracketKeyCode, keyFlags: [], verb: .previousRequest),
    Key(characters: "\u{1D}", ignoringModifiers: "]", keyCode: rightBracketKeyCode, keyFlags: [], verb: .nextRequest),
  ]

  /// Makes a Control-Command key-down event of `key`.
  ///
  /// - Parameter key: The key.
  /// - Returns: The event.
  static func controlCommandEvent(of key: Key) throws -> NSEvent {
    try #require(
      NSEvent.makeKeyEvent(
        characters: key.characters, charactersIgnoringModifiers: key.ignoringModifiers, keyCode: key.keyCode,
        modifiers: key.keyFlags.union([.control, .command])))
  }

  @Test(arguments: keys)
  func aControlCommandKeySpellsTheDefaultChordOfItsVerb(key: Key) throws {
    let event = try Self.controlCommandEvent(of: key)

    let chord = try #require(KeyChordTranslator.chord(for: event))

    #expect(chord == AgentKeymap.defaultChords[key.verb]?.first)
    #expect(
      AgentKeymap.defaultKeymap.bindings(for: chord.asSequence).map(\.action)
        == [.command(key.verb.id)])
  }
}
