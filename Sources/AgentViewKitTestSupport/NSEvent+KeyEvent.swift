import AppKit

extension NSEvent {
  /// Makes a key event of one key, with no location, no context and no
  /// repeat.
  ///
  /// This is the one key event factory of the test support and the tests. A
  /// test that needs a key event, and the harness that sends one to its
  /// window, make it here.
  ///
  /// - Parameters:
  ///   - type: The type of the event, key-down or key-up.
  ///   - characters: The characters of the event.
  ///   - charactersIgnoringModifiers: The characters with no modifiers but
  ///     Shift. `nil` uses `characters`.
  ///   - keyCode: The virtual key code.
  ///   - modifiers: The modifier flags.
  ///   - timestamp: The time of the event, in seconds since system startup.
  ///   - windowNumber: The number of the window of the event, or `0` for no
  ///     window.
  /// - Returns: The event, or `nil` when AppKit cannot make it.
  public static func makeKeyEvent(
    _ type: NSEvent.EventType = .keyDown,
    characters: String,
    charactersIgnoringModifiers: String? = nil,
    keyCode: UInt16,
    modifiers: NSEvent.ModifierFlags,
    timestamp: TimeInterval = 0,
    windowNumber: Int = 0
  ) -> NSEvent? {
    keyEvent(
      with: type,
      location: .zero,
      modifierFlags: modifiers,
      timestamp: timestamp,
      windowNumber: windowNumber,
      context: nil,
      characters: characters,
      charactersIgnoringModifiers: charactersIgnoringModifiers ?? characters,
      isARepeat: false,
      keyCode: keyCode
    )
  }
}
