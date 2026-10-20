import EditorCommands

/// The default keys of the agent commands (plan.md §4.1, §11 decision 14).
///
/// | Key | Verb |
/// | --- | --- |
/// | Command-Return | ``AgentCommandVerb/send`` |
/// | Command-Period, Escape | ``AgentCommandVerb/cancel`` |
/// | Command-Shift-C | ``AgentCommandVerb/copyThread`` |
/// | Option-Up Arrow | ``AgentCommandVerb/jumpToPrevious`` |
/// | Option-Down Arrow | ``AgentCommandVerb/jumpToNext`` |
/// | Command-Shift-[ | ``AgentCommandVerb/previousRequest`` |
/// | Command-Shift-] | ``AgentCommandVerb/nextRequest`` |
///
/// The definition of each command carries the first key of its verb in
/// `keys[.cua]`, so a menu shows that key. When an ``AgentCommandScope``
/// registers the definitions, `CommandRegistry.register` binds these keys in
/// the CUA layer of the scope. The scope binds each other key of a verb with
/// `bindKey`, with the command id as the source of the binding. Thus Stop
/// shows Command-Period in the menu, and Escape also stops the agent when
/// the thread or the composer has the focus.
///
/// The keys use the EditorKit chord spelling, with the modifier glyphs in the
/// order `⌃⌥⇧⌘`. A key that the focused view uses first, such as Return in
/// the composer, does not get to the scope.
///
/// The EditorKit translator spells a key event from its
/// `charactersIgnoringModifiers`. On a US keyboard, Shift changes `[` to `{`
/// and `]` to `}`, thus Command-Shift-[ is the chord `⇧⌘{` and
/// Command-Shift-] is the chord `⇧⌘}`.
public nonisolated enum AgentKeymap {
  /// The Command-Return chord.
  public static let commandReturn = KeyChord("⌘" + KeyChord.return.rawValue)

  /// The Command-Period chord, the Mac key for stop.
  public static let commandPeriod: KeyChord = "⌘."

  /// The Command-Shift-C chord.
  public static let commandShiftC: KeyChord = "⇧⌘C"

  /// The Option-Up Arrow chord.
  public static let optionUp = KeyChord("⌥" + KeyChord.upArrow.rawValue)

  /// The Option-Down Arrow chord.
  public static let optionDown = KeyChord("⌥" + KeyChord.downArrow.rawValue)

  /// The Command-Shift-[ chord. Shift changes `[` to `{`.
  public static let commandShiftLeftBracket: KeyChord = "⇧⌘{"

  /// The Command-Shift-] chord. Shift changes `]` to `}`.
  public static let commandShiftRightBracket: KeyChord = "⇧⌘}"

  /// The default chords of each verb that has keys. The first chord is the
  /// chord that a menu shows.
  public static let defaultChords: [AgentCommandVerb: [KeyChord]] = [
    .send: [commandReturn],
    .cancel: [commandPeriod, .escape],
    .copyThread: [commandShiftC],
    .jumpToPrevious: [optionUp],
    .jumpToNext: [optionDown],
    .previousRequest: [commandShiftLeftBracket],
    .nextRequest: [commandShiftRightBracket],
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
    chords { $0 }
  }

  /// The chords of ``defaultChords`` after the first chord of each verb, in
  /// the order of the verbs. The definition of a command holds only the
  /// first chord, so the scope binds these chords with `bindKey`.
  static var secondaryChords: [(verb: AgentCommandVerb, chord: KeyChord)] {
    chords { Array($0.dropFirst()) }
  }

  /// Binds each chord of ``secondaryChords`` in the CUA layer of `scope`.
  ///
  /// The source of each binding is the command id of its verb. Thus a second
  /// `CommandRegistry.register` of the verb at `scope` removes the binding
  /// first, and a second call of this method does not add it again.
  ///
  /// - Parameters:
  ///   - registry: The registry to bind into.
  ///   - scope: The path of the scope.
  static func bindSecondaryChords(into registry: inout CommandRegistry, at scope: FocusPath) {
    for (verb, chord) in secondaryChords {
      registry.bindKey(chord.asSequence, to: .command(verb.id), mode: .cua, at: scope, source: verb.id)
    }
  }

  /// The chords that `select` keeps of each verb, in the order of the verbs.
  ///
  /// - Parameter select: Gives the chords to keep of the chords of a verb.
  /// - Returns: One entry for each kept chord.
  private static func chords(
    _ select: ([KeyChord]) -> [KeyChord]
  ) -> [(verb: AgentCommandVerb, chord: KeyChord)] {
    AgentCommandVerb.allCases.flatMap { verb in
      select(defaultChords[verb] ?? []).map { (verb, $0) }
    }
  }
}
