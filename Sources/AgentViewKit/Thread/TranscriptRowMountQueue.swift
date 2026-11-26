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
/// Each ``TranscriptRowElement`` keeps one mount. A row that comes into the
/// list while the rows move puts its mount in the queue. While the mount
/// waits, the row shows its static form, also at rest
/// (``TranscriptRowForm``), unless a hold keeps it real. The row reads
/// ``waits``, so the turn of the row evaluates that row and no other row.
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

  /// Makes a mount that does not wait.
  init() {}

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

/// Mounts the real rows of a thread a few at a time when the rows come to
/// rest (card ^7625j1b).
///
/// A row that comes into the list while the rows move shows its static
/// form (``TranscriptStaticRow``). When the rows come to rest, the queue
/// does not mount the real form of all these rows in one frame: in each
/// frame of its ``frames``, it mounts at most ``rowsPerFrame`` rows, the
/// rows nearest the vertical center of the view first. A row stays static,
/// with its exact height, until its turn.
///
/// A new motion stops the queue, and the rows that wait stay static. The
/// next rest starts the queue again. A row that gets a hold
/// (``TranscriptRowHolds``) shows its real form at once and leaves the
/// queue (``release(_:)``). A jump session mounts each row at once
/// (``mountAll()``).
@MainActor final class TranscriptRowMountQueue {
  /// The largest number of rows that the queue mounts in one frame.
  static let rowsPerFrame = 2

  /// The frames that drive the queue.
  let frames: any TranscriptFrameSource

  /// The mounts that wait for their turn.
  private var waiting: [ObjectIdentifier: TranscriptRowMount] = [:]

  /// Whether the rows of the thread are at rest. A new thread is at rest.
  private var isResting = true

  /// Makes an empty queue.
  ///
  /// - Parameter frames: The frames that drive the queue.
  init(frames: any TranscriptFrameSource) {
    self.frames = frames
  }

  /// Puts the mount of a row that comes into the list while the rows move
  /// in the queue. The row then waits for its turn.
  ///
  /// - Parameter mount: The mount of the row.
  func enqueue(_ mount: TranscriptRowMount) {
    mount.waits = true
    waiting[ObjectIdentifier(mount)] = mount
    startFramesAtRest()
  }

  /// Takes the mount of a row out of the queue at once: the row does not
  /// wait. The row of the mount gets a hold, shows its real form at rest
  /// for a different cause, or leaves the list.
  ///
  /// - Parameter mount: The mount of the row.
  func release(_ mount: TranscriptRowMount) {
    guard waiting.removeValue(forKey: ObjectIdentifier(mount)) != nil else { return }
    mount.waits = false
    stopFramesWhenEmpty()
  }

  /// Takes each mount out of the queue at once, so each row shows its real
  /// form. A jump session of EditorKit calls it, so that the jump targets
  /// are the targets of the real views.
  func mountAll() {
    waiting.values.forEach { $0.waits = false }
    waiting.removeAll()
    frames.stop()
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
    frames.start { [weak self] in self?.mountNextRows() }
  }

  /// Stops the frames, when no row waits.
  private func stopFramesWhenEmpty() {
    guard waiting.isEmpty else { return }
    frames.stop()
  }

  /// The step of one frame: mounts the ``rowsPerFrame`` rows nearest the
  /// vertical center of the view.
  private func mountNextRows() {
    let next = waiting.values.sorted { $0.centerDistance < $1.centerDistance }.prefix(Self.rowsPerFrame)
    next.forEach(release)
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
