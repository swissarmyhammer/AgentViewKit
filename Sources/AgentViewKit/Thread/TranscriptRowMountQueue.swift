import AppKit
import FoundationModelsACPClient
import Observation
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

/// The wait of one row of a thread for an interaction of the user, in the
/// ``TranscriptRowMountQueue`` (card ^7625j1b).
///
/// Each ``TranscriptRowElement`` keeps one mount. The mount of a row that
/// the list makes in a live motion of the user waits from its start
/// (``init(waits:)``), so the row is static at rest before its first appear
/// too. A static row in view in a live motion puts its mount in the queue.
/// While the mount waits, the row shows its static form, at rest too
/// (``TranscriptRowForm``), unless a hold keeps it real. The row reads
/// ``waits``, so the end of the wait of a row evaluates that row and no
/// other row.
///
/// The wait ends only for a cause: an interaction of the user with the row
/// (``TranscriptRowMountQueue/release(_:)``), an edit of the data of the row
/// (``TranscriptRowMountQueue/releaseOnEdit(_:of:expandedBlocks:)``), or a
/// jump session (``TranscriptRowMountQueue/mountAll()``). The frames of a
/// rest do not end it. A row that leaves the view leaves the queue, and
/// its mount still waits, so a row that the list keeps out of view does
/// not mount its editors.
@MainActor @Observable final class TranscriptRowMount {
  /// Whether the row waits for an interaction to show its real form.
  fileprivate(set) var waits = false

  /// Whether the row is in view: between its appear and its disappear. A
  /// change does not evaluate the row.
  @ObservationIgnored var isInView = false

  /// Whether an edit of the data of the row ends the wait
  /// (``TranscriptRowMountQueue/releaseOnEdit(_:of:expandedBlocks:)``).
  @ObservationIgnored fileprivate var watchesEdits = false

  /// Makes a mount.
  ///
  /// - Parameter waits: Whether the row waits from its start: `true` for a
  ///   row that the list makes in a live motion of the user.
  init(waits: Bool = false) {
    self.waits = waits
  }
}

/// Keeps the rows of a thread that show their static form at rest, and
/// ends the wait of a row when the user interacts with it (card ^7625j1b).
///
/// A row that comes into the list while the rows move shows its static
/// form (``TranscriptStaticRow``), and EditorKit mounts no editor in it. A
/// static row of a live motion of the user waits in the queue, and keeps
/// its static form at rest too: the frames of a rest mount no editor, so a
/// rest after a flick does not hitch. The wait of a row ends, and the row
/// shows its real form, only for an interaction or an edit:
///
/// - a press of the mouse on the static text of the row, or an
///   accessibility press or focus on it (``StaticEditorSlot``);
/// - a hold of the row (``TranscriptRowHolds``): the keyboard focus in its
///   item scope, the text selection of the thread, or the stream of its
///   entry;
/// - a find hit that marks words in the text of the row
///   (``TranscriptRowHolds/isSearchTarget``);
/// - an edit of the data of the row, such as new text or an expanded block
///   (``releaseOnEdit(_:of:expandedBlocks:)``), because the height and the
///   pictures of its static form are of the old data;
/// - a jump session, which mounts each row in view (``mountAll()``).
///
/// The mouse that only hovers a waiting row does not end its wait. A row
/// whose wait ended stays real while it stays in view
/// (``TranscriptRowHolds/wasRealAtRest``). A row that leaves the view
/// leaves the queue and keeps its wait (``withdraw(_:)``).
///
/// The frames of the queue give the one frame of the end of a live motion
/// (``afterNextFrame(_:)``, ``TranscriptMotionState``), so a thread has one
/// display link, and the link fires only in that frame.
@MainActor final class TranscriptRowMountQueue {
  /// The frames that drive the queue.
  let frames: any TranscriptFrameSource

  /// The mounts of the rows in view that wait.
  private var waiting: [ObjectIdentifier: TranscriptRowMount] = [:]

  /// Whether a jump session is open: each row that comes into the queue
  /// shows its real form at once.
  private var mountsAtOnce = false

  /// The work of the next frame (``afterNextFrame(_:)``), or `nil`.
  private var nextFrameAction: (@MainActor () -> Void)?

  /// Makes an empty queue.
  ///
  /// - Parameter frames: The frames that drive the queue.
  init(frames: any TranscriptFrameSource) {
    self.frames = frames
  }

  /// Puts the mount of a static row in view in a live motion, or of a row
  /// that comes into view while it waits, in the queue. The row then waits
  /// for an interaction. While a jump session is open, the row does not
  /// wait.
  ///
  /// - Parameter mount: The mount of the row.
  func enqueue(_ mount: TranscriptRowMount) {
    guard !mountsAtOnce else {
      mount.waits = false
      return
    }
    mount.waits = true
    waiting[ObjectIdentifier(mount)] = mount
  }

  /// Takes the mount of a row out of the queue at once: the row does not
  /// wait, and shows its real form at rest. The user interacts with the
  /// row, the row gets a hold, or it shows its real form for a different
  /// cause. A mount out of the queue that still waits, such as the mount
  /// of a row out of view, also stops to wait.
  ///
  /// - Parameter mount: The mount of the row.
  func release(_ mount: TranscriptRowMount) {
    withdraw(mount)
    mount.waits = false
  }

  /// Ends the wait of a row at the first edit of its data: the data of its
  /// height (``TranscriptRowContent``) and the expanded state of its
  /// blocks. The static form of the row has the height and the pictures of
  /// the old data, so the row then shows its real form.
  ///
  /// A row that already watches its edits does not watch again. The models
  /// of a transcript are main-actor models, so an edit comes on the main
  /// actor.
  ///
  /// - Parameters:
  ///   - mount: The mount of a row that waits.
  ///   - entry: The entry of the row.
  ///   - expandedBlocks: The store of the expanded blocks of the thread, or
  ///     `nil`.
  func releaseOnEdit(_ mount: TranscriptRowMount, of entry: TranscriptEntry, expandedBlocks: ExpandedBlocksStore?) {
    guard mount.waits, !mount.watchesEdits else { return }
    mount.watchesEdits = true
    withObservationTracking {
      _ = TranscriptRowContent(entry: entry, isExpanded: expandedBlocks?.isExpanded(entry: entry) ?? false)
    } onChange: { [weak self, weak mount] in
      MainActor.assumeIsolated {
        guard let mount else { return }
        self?.noteEdit(of: mount)
      }
    }
  }

  /// Records an edit of the data of a row that watches its edits: the row
  /// stops to wait.
  ///
  /// - Parameter mount: The mount of the row.
  private func noteEdit(of mount: TranscriptRowMount) {
    mount.watchesEdits = false
    release(mount)
  }

  /// Takes the mount of a row that leaves the view out of the queue. The
  /// row keeps its wait, so the row does not mount its editors out of
  /// view. When the row comes into view again in a live motion, it puts
  /// its mount in the queue again (``enqueue(_:)``).
  ///
  /// - Parameter mount: The mount of the row.
  func withdraw(_ mount: TranscriptRowMount) {
    waiting.removeValue(forKey: ObjectIdentifier(mount))
  }

  /// Takes each mount out of the queue at once, so each row in view shows
  /// its real form, and makes each row that comes into the queue after it
  /// real at once, until ``endMountAll()``. A jump session of EditorKit
  /// calls it when it opens, so that the jump targets are the targets of
  /// the real views.
  func mountAll() {
    mountsAtOnce = true
    for row in waiting.values {
      row.waits = false
    }
    waiting.removeAll()
  }

  /// Ends ``mountAll()``: a row that comes into the queue after it waits
  /// for an interaction again. A jump session of EditorKit calls it when
  /// it closes.
  func endMountAll() {
    mountsAtOnce = false
  }

  /// Runs `action` in the next frame of ``frames``, also while the rows
  /// move. A second call before that frame replaces the action.
  ///
  /// - Parameter action: The work of the next frame.
  func afterNextFrame(_ action: @escaping @MainActor () -> Void) {
    nextFrameAction = action
    frames.start { [weak self] in self?.stepFrame() }
  }

  /// The step of one frame: stops the frames, and runs the work of the
  /// frame (``afterNextFrame(_:)``). The work can start the frames again.
  private func stepFrame() {
    let action = nextFrameAction
    nextFrameAction = nil
    frames.stop()
    action?()
  }
}

/// The frames of the display link of the view of a thread: the production
/// ``TranscriptFrameSource`` (card ^7625j1b).
///
/// The source makes a display link of its view
/// (`NSView.displayLink(target:selector:)`) only while the queue runs it,
/// so the display link fires only for the work of the next frame of the
/// queue. Before the source has a view, a start waits for
/// ``attach(to:)``.
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
  /// The queue of the rows of the thread that keep their static form at
  /// rest until an interaction (``TranscriptRowMountQueue``), or `nil`.
  /// With no queue, a row shows its real form at once when the rows come
  /// to rest.
  ///
  /// ``ConversationView`` sets it for its rows.
  @Entry var transcriptRowMounts: TranscriptRowMountQueue? = nil
}
