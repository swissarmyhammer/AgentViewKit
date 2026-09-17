import EditorCommands

/// The default keys of the agent commands (plan.md §4.1, §11 decision 14).
///
/// | Key | Verb |
/// | --- | --- |
/// | Command-Return | ``AgentCommandVerb/send`` |
/// | Escape | ``AgentCommandVerb/cancel`` |
/// | Command-Shift-C | ``AgentCommandVerb/copyThread`` |
/// | Option-Up Arrow | ``AgentCommandVerb/jumpToPrevious`` |
/// | Option-Down Arrow | ``AgentCommandVerb/jumpToNext`` |
///
/// An ``AgentCommandScope`` binds these keys in the CUA layer of its scope.
/// The keys use the EditorKit chord spelling, with the modifier glyphs in the
/// order `⌃⌥⇧⌘`. A key that the focused view uses first, such as Return in
/// the composer, does not get to the scope.
public nonisolated enum AgentKeymap {
  /// The Command-Return chord.
  public static let commandReturn = KeyChord("⌘" + KeyChord.return.rawValue)

  /// The Command-Shift-C chord.
  public static let commandShiftC: KeyChord = "⇧⌘C"

  /// The Option-Up Arrow chord.
  public static let optionUp = KeyChord("⌥" + KeyChord.upArrow.rawValue)

  /// The Option-Down Arrow chord.
  public static let optionDown = KeyChord("⌥" + KeyChord.downArrow.rawValue)

  /// The default chord of each verb that has one.
  public static let defaultChords: [AgentCommandVerb: KeyChord] = [
    .send: commandReturn,
    .cancel: .escape,
    .copyThread: commandShiftC,
    .jumpToPrevious: optionUp,
    .jumpToNext: optionDown,
  ]

  /// The default keymap: each chord of ``defaultChords`` bound to the
  /// command id of its verb.
  public static let defaultKeymap: Keymap = {
    var keymap = Keymap()
    for (verb, chord) in sortedChords {
      keymap.bind(chord.asSequence, to: .command(verb.id))
    }
    return keymap
  }()

  /// The entries of ``defaultChords`` in the order of the verbs, so that the
  /// bindings have a stable order.
  static var sortedChords: [(verb: AgentCommandVerb, chord: KeyChord)] {
    AgentCommandVerb.allCases.compactMap { verb in
      defaultChords[verb].map { (verb, $0) }
    }
  }

  /// Binds each default chord in the CUA layer of `scope`.
  ///
  /// The call first clears the CUA layer of the scope, so that a second call
  /// does not add the bindings again.
  ///
  /// - Parameters:
  ///   - registry: The registry to bind into.
  ///   - scope: The path of the scope.
  static func bind(into registry: inout CommandRegistry, at scope: FocusPath) {
    registry.resetKeymap(at: scope, mode: .cua)
    for (verb, chord) in sortedChords {
      registry.bindKey(chord.asSequence, to: .command(verb.id), mode: .cua, at: scope)
    }
  }
}
