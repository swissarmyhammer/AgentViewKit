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

/// The motion of the rows of a thread, from the scroll phases of its list
/// (card ^9ync5h3).
///
/// The end of a live motion of the user comes in two frames. In the frame
/// of the end, the rows take the hit test again (``isLiveMoving`` is
/// `false`), and they keep their motion form (``isMoving`` stays `true`).
/// One frame later (``endMotion()``), the rows come to rest and change
/// their form. Thus the hover of the row under a still mouse and the form
/// change of the rows never land in the same frame. While the end waits
/// for its frame (``endsLiveMotion``), a row that the list makes waits in
/// the ``TranscriptRowMountQueue`` as a row of the motion does. The end of
/// a scroll of the kit comes in one frame.
struct TranscriptMotionState: Equatable {
  /// Whether the rows move: the list moves (``TranscriptRowMotion/isMoving(_:)``),
  /// or a live motion ended and its next frame did not come yet.
  private(set) var isMoving = false

  /// Whether the user moves the list
  /// (``TranscriptRowMotion/isLiveMotion(_:)``).
  private(set) var isLiveMoving = false

  /// Whether a live motion ended, and the rows wait for the next frame to
  /// come to rest (``endMotion()``).
  private(set) var endsLiveMotion = false

  /// Records a new scroll phase of the list.
  ///
  /// - Parameter phase: The new scroll phase.
  /// - Returns: `true` when the phase ends a live motion: the caller then
  ///   calls ``endMotion()`` in the next frame.
  mutating func note(_ phase: ScrollPhase) -> Bool {
    let isLive = TranscriptRowMotion.isLiveMotion(phase)
    let moving = TranscriptRowMotion.isMoving(phase)
    endsLiveMotion = isLiveMoving && !isLive && !moving
    isLiveMoving = isLive
    isMoving = moving || endsLiveMotion
    return endsLiveMotion
  }

  /// Brings the rows to rest in the frame after the end of a live motion.
  /// When a new phase came after that end, the call changes nothing.
  mutating func endMotion() {
    guard endsLiveMotion else { return }
    endsLiveMotion = false
    isMoving = false
  }
}

/// Takes the hit test away from one element of the rows of a thread in a
/// live motion of the user (card ^9ync5h3).
///
/// In a live motion, the content moves under a still mouse, and SwiftUI
/// hit-tests each hover responder of the rows again on each frame. The
/// elements take no hit test then, so their rows have no hover responder
/// to test. A scroll-wheel event goes to the scroll view of the list. At
/// rest, and in the frame of the end of a live motion
/// (``TranscriptMotionState``), the elements take the hit test again.
///
/// ``ConversationView`` gives the modifier to each element in its
/// `ForEach`, outside the body of the row, so a change of the hit test
/// evaluates no row. One modifier on the lazy stack of the rows also keeps
/// the hover responders from the hit test, but then the list draws the
/// layers of some rows again in the steps of a flick
/// (`TranscriptRowRedrawTests`).
struct TranscriptRowsHitTest: ViewModifier {
  /// Whether the user moves the rows
  /// (``TranscriptMotionState/isLiveMoving``). It is `false` in the frame
  /// of the end of a live motion.
  let rowsMoveLive: Bool

  func body(content: Content) -> some View {
    content.allowsHitTesting(!rowsMoveLive)
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
  /// (``TranscriptRowMotion/isLiveMotion(_:)``), or in the frame of the end
  /// of such a motion (``TranscriptMotionState/endsLiveMotion``).
  ///
  /// ``ConversationView`` sets it for its rows. A static row that comes
  /// into view while the value is `true` waits in the
  /// ``TranscriptRowMountQueue`` (``TranscriptRowElement``). The value
  /// stays `true` in the frame of the end of a live motion, so a row that
  /// comes into view in that frame waits too, and the rows evaluate no
  /// change in that frame. The stack of the rows takes the hit test again
  /// in that frame (``TranscriptRowsHitTest``). Outside a thread, the value
  /// is `false`.
  @Entry var transcriptRowsMoveLive = false
}
