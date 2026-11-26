import SwiftUI

/// The motion signal of the rows of a thread (card ^9ync5h3, spike
/// ^fa3j934).
///
/// While the list of a ``ConversationView`` moves, each row that can show
/// its static form shows it (``TranscriptStaticRow``): its text in SwiftUI
/// `Text`, and no EditorKit editor. At rest, each row shows its real form.
/// The list moves while the SwiftUI scroll phase is not idle: the user
/// drags, flicks or scrolls the list, the list decelerates, or the kit
/// animates a scroll.
///
/// While a jump session of EditorKit is open, the rows do not move: each
/// row shows its real form, so that the jump targets of the rows are the
/// targets of the real views.
///
/// Only a live motion of the user (``isLiveMotion(_:)``) makes the rows
/// that come into the list wait in the ``TranscriptRowMountQueue`` (card
/// ^7625j1b). A scroll of the kit, such as a jump to a row, makes no row
/// wait.
enum TranscriptRowMotion {
  /// Tells if the list moves in a scroll phase.
  ///
  /// - Parameter phase: The scroll phase of the list.
  /// - Returns: `true` when `phase` is not idle.
  static func isMoving(_ phase: ScrollPhase) -> Bool {
    phase != .idle
  }

  /// Tells if the user moves the list in a scroll phase: the user drags,
  /// flicks or scrolls the list, or the list decelerates after a flick. An
  /// animated scroll of the kit is not a live motion.
  ///
  /// - Parameter phase: The scroll phase of the list.
  /// - Returns: `true` when `phase` scrolls and is not the animating phase.
  static func isLiveMotion(_ phase: ScrollPhase) -> Bool {
    phase.isScrolling && phase != .animating
  }

  /// Tells if the rows of the list show their static forms.
  ///
  /// - Parameters:
  ///   - isMoving: Whether the list moves (``isMoving(_:)``).
  ///   - isJumping: Whether a jump session of EditorKit is open.
  /// - Returns: `true` when the list moves and no jump session is open.
  static func rowsMove(isMoving: Bool, isJumping: Bool) -> Bool {
    isMoving && !isJumping
  }
}

extension EnvironmentValues {
  /// Whether the rows of the thread move (``TranscriptRowMotion``).
  ///
  /// ``ConversationView`` sets it for its rows. Each
  /// ``TranscriptRowElement`` reads it, and shows the static form of its
  /// row while the value is `true` (``TranscriptStaticRow``). Outside a
  /// thread, the value is `false`, so each row shows its real form.
  @Entry var transcriptRowsMove = false

  /// Whether the rows of the thread move in a live motion of the user
  /// (``TranscriptRowMotion/isLiveMotion(_:)``).
  ///
  /// ``ConversationView`` sets it for its rows. A static row that comes
  /// into view while the value is `true` waits in the
  /// ``TranscriptRowMountQueue`` (``TranscriptRowElement``). Outside a
  /// thread, the value is `false`.
  @Entry var transcriptRowsMoveLive = false
}
