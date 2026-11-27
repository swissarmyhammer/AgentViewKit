import AppKit
import SwiftUI

/// A source of the frames of the display, which drives the
/// ``TranscriptRowMountQueue`` of a thread (card ^7625j1b).
///
/// The source of a thread is ``TranscriptDisplayLinkFrames``: one step for
/// each frame of the display link of the thread. A test gives a source
/// that it steps by hand, so a test needs no clock.
@MainActor protocol TranscriptFrameSource: AnyObject {
  /// Starts to call `step` one time for each frame. A second call replaces
  /// the step, and keeps the source in run.
  ///
  /// - Parameter step: The work of one frame.
  func start(_ step: @escaping @MainActor () -> Void)

  /// Stops the steps. The source calls no step until the next ``start(_:)``.
  func stop()

  /// Ties the source to the display of `view`.
  ///
  /// - Parameter view: A view in the window of the thread.
  func attach(to view: NSView)
}

/// The turn of one row of a thread in the ``TranscriptRowMountQueue``
/// (card ^7625j1b).
///
/// Each ``TranscriptRowElement`` keeps one mount. The mount of a row that
/// the list makes in a live motion of the user waits from its start
/// (``init(waits:)``), so the row is static at rest before its first appear
/// too. A static row in view in a live motion, or a row that comes into
/// view at rest while its mount waits, puts its mount in the queue. A
/// row that shows its real form, also in a motion, takes its mount out of
/// the queue at once (``TranscriptRowMountQueue/release(_:)``), so a real
/// row never waits. While
/// the mount waits, the row shows its static form, also at rest
/// (``TranscriptRowForm``), unless a hold keeps it real. A row that leaves
/// the view leaves the queue, and its mount still waits, so a row that the
/// list keeps out of view does not mount its editors at rest. The row reads
/// ``waits``, so the turn of the row evaluates that row and no other row.
///
/// The mount holds the mount of each EditorKit text area of the row
/// (``TranscriptSlotMount``). At rest, each slot of a waiting row takes a
/// turn of its own, and the row waits until each of its slots is real.
/// Thus the frame of the row keeps the height of its static form while
/// some slots are real and some are still static.
@MainActor @Observable final class TranscriptRowMount {
  /// Whether the row waits in the queue for its turn to show its real
  /// form.
  fileprivate(set) var waits = false

  /// The distance of the vertical center of the row from the vertical
  /// center of the view of the list, in points. The queue mounts the row
  /// with the smallest distance first. A row that knows no distance has
  /// an infinite distance.
  ///
  /// The row writes it while it waits. A change does not evaluate the row.
  @ObservationIgnored var centerDistance = CGFloat.infinity

  /// Whether the row is in view: between its appear and its disappear. A
  /// change does not evaluate the row.
  @ObservationIgnored var isInView = false

  /// The mounts of the editor slots of the row, in the order of their
  /// arrival.
  @ObservationIgnored private var slots: [TranscriptSlotMount] = []

  /// Makes a mount.
  ///
  /// - Parameter waits: Whether the row waits from its start: `true` for a
  ///   row that the list makes in a live motion of the user.
  init(waits: Bool = false) {
    self.waits = waits
  }

  /// Adds the mount of an editor slot that shows in the row. A new slot
  /// waits when the row waits. A slot that the row has already keeps its
  /// state, so a slot that shows again does not wait again for a turn.
  ///
  /// - Parameter slot: The mount of the slot.
  func add(_ slot: TranscriptSlotMount) {
    guard !slots.contains(where: { $0 === slot }) else { return }
    slots.append(slot)
    slot.waits = waits
  }

  /// Removes the mount of an editor slot that leaves the row. The slot
  /// keeps its state: the list can keep the view of the slot out of view,
  /// and a slot that still waits does not show its editor there.
  ///
  /// - Parameter slot: The mount of the slot.
  func remove(_ slot: TranscriptSlotMount) {
    slots.removeAll { $0 === slot }
  }

  /// The waiting slot with the smallest top in the row, or `nil` when no
  /// slot of the row waits.
  fileprivate var nextWaitingSlot: TranscriptSlotMount? {
    slots.filter(\.waits).min { $0.top < $1.top }
  }

  /// Sets whether the row and each of its slots wait.
  ///
  /// - Parameter waits: Whether the row waits.
  fileprivate func setWaits(_ waits: Bool) {
    self.waits = waits
    for slot in slots {
      slot.waits = waits
    }
  }

  /// The distance of the vertical center of the view of `proxy` from the
  /// vertical center of its scroll view.
  ///
  /// - Parameter proxy: The geometry of the row.
  /// - Returns: The distance in points, or infinity outside a scroll view.
  nonisolated static func centerDistance(of proxy: GeometryProxy) -> CGFloat {
    guard let scrollBounds = proxy.bounds(of: .scrollView) else { return .infinity }
    return abs(proxy.frame(in: .local).midY - scrollBounds.midY)
  }
}

/// The turn of one EditorKit text area of a thread row in the
/// ``TranscriptRowMountQueue`` (card ^7625j1b).
///
/// Each ``StaticEditorSlot`` in a row keeps one mount, and adds it to the
/// ``TranscriptRowMount`` of its row. While the mount waits in a row that
/// takes turns at rest (``TranscriptSlotForm/inTurn``), the slot shows its
/// still view. The slot reads ``waits``, so the turn of the slot evaluates
/// that slot and no other view.
///
/// A new mount waits. Thus a slot that is not in its row yet, such as the
/// slot of a row that the list made while the rows moved and that did not
/// appear yet, shows its still view in a row that takes turns. In a row
/// that does not take turns, the slot does not read ``waits``.
@MainActor @Observable final class TranscriptSlotMount {
  /// Whether the slot waits for its turn to show its editor.
  fileprivate(set) var waits = true

  /// The top of the slot in the coordinate space of its row, in points.
  /// The queue makes the slot with the smallest top of a row real first. A
  /// slot that knows no top has an infinite top.
  ///
  /// The slot writes it while it waits. A change does not evaluate the
  /// slot.
  @ObservationIgnored var top = CGFloat.infinity

  /// Makes a mount that waits.
  init() {}

  /// The top of the view of `proxy` in the coordinate space of its row.
  ///
  /// - Parameter proxy: The geometry of the slot.
  /// - Returns: The top in points.
  nonisolated static func top(of proxy: GeometryProxy) -> CGFloat {
    proxy.frame(in: .named(TranscriptFileOrder.rowSpace)).minY
  }
}

/// Makes the EditorKit editors of the rows of a thread real one at a time
/// when the rows come to rest (card ^7625j1b).
///
/// A row that comes into the list while the rows move shows its static
/// form (``TranscriptStaticRow``). A static row of a live motion of the
/// user waits in the queue. When the rows come to rest, the queue
/// does not mount the editors of all these rows in one frame. Each editor
/// slot of these rows (``TranscriptSlotMount``) waits for a turn of its
/// own: in each frame of its ``frames``, the queue makes at most
/// ``editorSlotsPerFrame`` slots real. The slots of the row nearest the
/// vertical center of the view go first, and the slots of one row go from
/// top to bottom. Thus a row becomes real over a few frames. Until each of
/// its slots is real, the row keeps the exact height of its static form,
/// and when the last slot is real, the row leaves the queue.
///
/// A new motion stops the queue, and the slots that wait stay static. The
/// next rest starts the queue again. A row that leaves the view leaves the
/// queue and keeps its wait (``withdraw(_:)``). A row that gets a hold
/// (``TranscriptRowHolds``) shows its real form at once and leaves the
/// queue (``release(_:)``). A jump session mounts each row at once
/// (``mountAll()``), and each row that comes into the queue while the
/// session is open (``endMountAll()``).
@MainActor final class TranscriptRowMountQueue {
  /// The largest number of editor slots that the queue makes real in one
  /// frame. One EditorKit editor takes about one frame of the main thread
  /// when it mounts.
  static let editorSlotsPerFrame = 1

  /// The frames that drive the queue.
  let frames: any TranscriptFrameSource

  /// The mounts that wait for their turn.
  private var waiting: [ObjectIdentifier: TranscriptRowMount] = [:]

  /// Whether the rows of the thread are at rest. A new thread is at rest.
  private var isResting = true

  /// Whether a jump session is open: each row that comes into the queue
  /// shows its real form at once.
  private var mountsAtOnce = false

  /// Makes an empty queue.
  ///
  /// - Parameter frames: The frames that drive the queue.
  init(frames: any TranscriptFrameSource) {
    self.frames = frames
  }

  /// Puts the mount of a static row in view in a live motion, or of a row
  /// that comes into view at rest while it waits, in the queue. The row
  /// and each of its editor slots then wait for their turns. While a jump
  /// session is open, the row does not wait.
  ///
  /// - Parameter mount: The mount of the row.
  func enqueue(_ mount: TranscriptRowMount) {
    guard !mountsAtOnce else {
      mount.setWaits(false)
      return
    }
    mount.setWaits(true)
    waiting[ObjectIdentifier(mount)] = mount
    startFramesAtRest()
  }

  /// Takes the mount of a row out of the queue at once: the row and each
  /// of its editor slots do not wait. The row of the mount gets a hold,
  /// shows its real form for a different cause, at rest or in a motion, or
  /// has no editor slot that waits. A mount out of the queue that still
  /// waits, such as the mount of a row out of view, also stops to wait.
  ///
  /// - Parameter mount: The mount of the row.
  func release(_ mount: TranscriptRowMount) {
    withdraw(mount)
    mount.setWaits(false)
  }

  /// Takes the mount of a row that leaves the view out of the queue. The
  /// row and its editor slots keep their waits, so the row does not mount
  /// its editors out of view. When the row comes into view again, it puts
  /// its mount in the queue again (``enqueue(_:)``).
  ///
  /// - Parameter mount: The mount of the row.
  func withdraw(_ mount: TranscriptRowMount) {
    guard waiting.removeValue(forKey: ObjectIdentifier(mount)) != nil else { return }
    stopFramesWhenEmpty()
  }

  /// Takes each mount out of the queue at once, so each row shows its real
  /// form, and makes each row that comes into the queue after it real at
  /// once, until ``endMountAll()``. A jump session of EditorKit calls it
  /// when it opens, so that the jump targets are the targets of the real
  /// views.
  func mountAll() {
    mountsAtOnce = true
    for row in waiting.values {
      row.setWaits(false)
    }
    waiting.removeAll()
    frames.stop()
  }

  /// Ends ``mountAll()``: a row that comes into the queue after it waits
  /// for its turn again. A jump session of EditorKit calls it when it
  /// closes.
  func endMountAll() {
    mountsAtOnce = false
  }

  /// Records whether the rows of the thread move: a motion stops the
  /// queue, and a rest starts it.
  ///
  /// - Parameter rowsMove: Whether the rows of the thread move
  ///   (``TranscriptRowMotion``).
  func noteRowsMove(_ rowsMove: Bool) {
    isResting = !rowsMove
    if rowsMove {
      frames.stop()
    } else {
      startFramesAtRest()
    }
  }

  /// Starts the frames, when the rows are at rest and a row waits.
  private func startFramesAtRest() {
    guard isResting, !waiting.isEmpty else { return }
    frames.start { [weak self] in self?.mountNextSlots() }
  }

  /// Stops the frames, when no row waits.
  private func stopFramesWhenEmpty() {
    guard waiting.isEmpty else { return }
    frames.stop()
  }

  /// The waiting row nearest the vertical center of the view, or `nil`
  /// when no row waits.
  private var nearestWaitingRow: TranscriptRowMount? {
    waiting.values.min { $0.centerDistance < $1.centerDistance }
  }

  /// The step of one frame: makes at most ``editorSlotsPerFrame`` waiting
  /// slots real, from the row nearest the vertical center of the view. A
  /// row with no waiting slot leaves the queue, and uses none of the
  /// slots of the frame.
  private func mountNextSlots() {
    var slotsLeft = Self.editorSlotsPerFrame
    while slotsLeft > 0, let row = nearestWaitingRow {
      slotsLeft -= mountNextSlot(of: row)
    }
  }

  /// Makes the top waiting slot of a row real, and takes the row out of the
  /// queue when no slot of the row waits after that.
  ///
  /// - Parameter row: The mount of a waiting row.
  /// - Returns: The number of slots that became real: 1, or 0 for a row
  ///   with no waiting slot.
  private func mountNextSlot(of row: TranscriptRowMount) -> Int {
    let slot = row.nextWaitingSlot
    slot?.waits = false
    if row.nextWaitingSlot == nil {
      release(row)
    }
    return slot == nil ? 0 : 1
  }
}

/// The frames of the display link of the view of a thread: the production
/// ``TranscriptFrameSource`` (card ^7625j1b).
///
/// The source makes a display link of its view
/// (`NSView.displayLink(target:selector:)`) only while the queue runs it,
/// so the display link fires only while a row waits at rest. Before the
/// source has a view, a start waits for ``attach(to:)``.
@MainActor final class TranscriptDisplayLinkFrames: NSObject, TranscriptFrameSource {
  /// The view whose display gives the frames, or `nil` before the view of
  /// the thread shows.
  private weak var view: NSView?

  /// The display link, while the source runs and has a view.
  private var link: CADisplayLink?

  /// The step of each frame, while the source runs.
  private var step: (@MainActor () -> Void)?

  func start(_ step: @escaping @MainActor () -> Void) {
    self.step = step
    makeLinkIfNeeded()
  }

  func stop() {
    step = nil
    link?.invalidate()
    link = nil
  }

  func attach(to view: NSView) {
    self.view = view
    makeLinkIfNeeded()
  }

  /// Makes the display link, when the source runs, has a view, and has no
  /// link.
  private func makeLinkIfNeeded() {
    guard step != nil, link == nil, let view else { return }
    let link = view.displayLink(target: self, selector: #selector(frameDidFire))
    link.add(to: .main, forMode: .common)
    self.link = link
  }

  /// Runs the step of one frame of the display link.
  @objc private func frameDidFire() {
    step?()
  }
}

/// The view that gives the frames of the display of a thread to its
/// ``TranscriptFrameSource`` (card ^7625j1b).
///
/// The view has no size, takes no click, and shows nothing. When the view
/// leaves the window, the source stops.
struct TranscriptFrameAnchor: NSViewRepresentable {
  /// The source that takes the display of the view.
  let frames: any TranscriptFrameSource

  func makeCoordinator() -> any TranscriptFrameSource {
    frames
  }

  func makeNSView(context: Context) -> NSView {
    let view = TranscriptFrameAnchorView()
    frames.attach(to: view)
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {}

  static func dismantleNSView(_ nsView: NSView, coordinator: any TranscriptFrameSource) {
    coordinator.stop()
  }
}

/// The AppKit view of a ``TranscriptFrameAnchor``: a view that no click
/// reaches.
private final class TranscriptFrameAnchorView: NSView {
  override func hitTest(_ point: NSPoint) -> NSView? {
    nil
  }
}

extension EnvironmentValues {
  /// The queue that mounts the real rows of the thread at rest
  /// (``TranscriptRowMountQueue``), or `nil`. With no queue, a row shows
  /// its real form at once when the rows come to rest.
  ///
  /// ``ConversationView`` sets it for its rows.
  @Entry var transcriptRowMounts: TranscriptRowMountQueue? = nil
}
