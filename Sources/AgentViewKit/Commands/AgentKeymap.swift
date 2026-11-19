import EditorCommands

/// The default keys of the agent commands (plan.md §4.1, §11 decision 14).
///
/// | Key | `StandardChords` | Verb |
/// | --- | --- | --- |
/// | Command-Return | `submitNow` | ``AgentCommandVerb/send`` |
/// | Command-Period, Escape | `stop`, `leave` | ``AgentCommandVerb/cancel`` |
/// | Control-Command-C | `copyItemAsText` | ``AgentCommandVerb/copyThread`` |
/// | Control-Shift-Command-C | | ``AgentCommandVerb/copyMessage`` |
/// | Control-Command-Up Arrow | `previousItem` | ``AgentCommandVerb/jumpToPrevious`` |
/// | Control-Command-Down Arrow | `nextItem` | ``AgentCommandVerb/jumpToNext`` |
/// | Control-Command-[ | `previousWaiting` | ``AgentCommandVerb/previousRequest`` |
/// | Control-Command-] | `nextWaiting` | ``AgentCommandVerb/nextRequest`` |
/// | Control-Command-Left Arrow | | ``AgentCommandVerb/goToParent`` |
/// | Control-Command-Right Arrow | | ``AgentCommandVerb/openChild`` |
/// | Control-Option-Command-[ | | ``AgentCommandVerb/previousSibling`` |
/// | Control-Option-Command-] | | ``AgentCommandVerb/nextSibling`` |
/// | Control-Command-O | | ``AgentCommandVerb/jumpToSession`` |
/// | Command-G | | ``AgentCommandVerb/findNextHit`` |
/// | Shift-Command-G | | ``AgentCommandVerb/findPreviousHit`` |
/// | Escape | `leave` | ``AgentCommandVerb/clearSearchHits`` |
///
/// The keys follow the one key table of EditorKit, AgentViewKit and
/// KanbanViewKit (D137): a Mac key keeps its Mac meaning, and each kit command
/// uses Control-Command, which no editor keymap binds. Each key but Copy
/// Message is a `StandardChords` constant, so this type holds no chord text
/// of its own for it. The shared table names no chord for Copy Message, so
/// ``controlShiftCommandC`` is the one chord of this type.
///
/// Find Next Hit and Find Previous Hit do not use Control-Command. Command-G
/// and Shift-Command-G are the find keys of the Mac, so they keep their Mac
/// meaning (D137 (a), TestudoApp D207 (f)). The verbs are not available while
/// a text input has the focus, so there the keys stay the find of the editor
/// (D133). `StandardChords` has no find key but Command-F, so
/// ``findNextHit`` and ``findPreviousHit`` are chords of this type.
///
/// Escape is the first key of Clear Search Hits and the second key of Stop.
/// A scope binds the first key of each verb before the other keys, so with
/// search hits Escape clears the hits, and with no hits it stops the agent
/// (TestudoApp D207 (f)).
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
public nonisolated enum AgentKeymap {
  /// The Control-Shift-Command-C chord: Control-Command, the modifiers of a
  /// kit command, with Shift on the C of Copy. Control-Command-C is Copy
  /// Thread (`StandardChords.copyItemAsText`), and Command-C stays the Copy
  /// of the system Edit menu and of the text views.
  public static let controlShiftCommandC: KeyChord = "⌃⇧⌘C"

  /// The chord of Go to Parent Session: Control-Command-Left Arrow.
  public static let parentSession = KeyChord("⌃⌘" + KeyChord.leftArrow.rawValue)

  /// The chord of Open Child Session: Control-Command-Right Arrow.
  public static let childSession = KeyChord("⌃⌘" + KeyChord.rightArrow.rawValue)

  /// The chord of Previous Sibling Session: Control-Option-Command-[.
  public static let previousSibling: KeyChord = "⌃⌥⌘["

  /// The chord of Next Sibling Session: Control-Option-Command-].
  public static let nextSibling: KeyChord = "⌃⌥⌘]"

  /// The chord of Jump to Session: Control-Command-O ("open quickly"). The
  /// EditorKit jump keeps Control-Command-J.
  public static let jumpToSession: KeyChord = "⌃⌘O"

  /// The chord of Find Next Hit: Command-G, the Find Next key of the Mac
  /// (D137 (a)).
  public static let findNextHit: KeyChord = "⌘G"

  /// The chord of Find Previous Hit: Shift-Command-G, the Find Previous key
  /// of the Mac (D137 (a)).
  public static let findPreviousHit: KeyChord = "⇧⌘G"

  /// The default chords of each verb that has keys. The first chord is the
  /// chord that a menu shows.
  public static let defaultChords: [AgentCommandVerb: [KeyChord]] = [
    .send: [StandardChords.submitNow],
    .cancel: [StandardChords.stop, StandardChords.leave],
    .copyThread: [StandardChords.copyItemAsText],
    .copyMessage: [controlShiftCommandC],
    .jumpToPrevious: [StandardChords.previousItem],
    .jumpToNext: [StandardChords.nextItem],
    .previousRequest: [StandardChords.previousWaiting],
    .nextRequest: [StandardChords.nextWaiting],
    .goToParent: [parentSession],
    .openChild: [childSession],
    .previousSibling: [previousSibling],
    .nextSibling: [nextSibling],
    .jumpToSession: [jumpToSession],
    .findNextHit: [findNextHit],
    .findPreviousHit: [findPreviousHit],
    .clearSearchHits: [StandardChords.leave],
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

  /// The entries of ``defaultChords`` in the order that a scope binds them:
  /// the first chord of each verb in the order of the verbs, then
  /// ``secondaryChords``. Thus the bindings have a stable order, and Escape
  /// offers ``AgentCommandVerb/clearSearchHits`` before
  /// ``AgentCommandVerb/cancel``, as in a scope.
  static var sortedChords: [(verb: AgentCommandVerb, chord: KeyChord)] {
    chords { Array($0.prefix(1)) } + secondaryChords
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
  /// The call binds no chord of a verb of a group in `groupsOff`, so that
  /// chord resolves to nothing.
  ///
  /// - Parameters:
  ///   - registry: The registry to bind into.
  ///   - scope: The path of the scope.
  ///   - groupsOff: The groups whose verbs get no chord.
  static func bindSecondaryChords(
    into registry: inout CommandRegistry, at scope: FocusPath, groupsOff: Set<AgentCommandGroup> = []
  ) {
    for (verb, chord) in secondaryChords where !groupsOff.contains(verb.group) {
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
