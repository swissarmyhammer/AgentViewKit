import AppKit
import EditorTestSupport
import SwiftUI

/// A view mounted in a window, which a test renders after a change of its
/// model: the off-screen window of a ``HostedViewHarness``, or the real
/// window of a ``CaptureMount``. A helper that sends a change and waits for it
/// takes either one.
protocol RenderedMount {
  /// Makes SwiftUI update the view now, with no run loop turn and no clock.
  func render()

  /// Waits until `condition` holds, then makes SwiftUI update the view.
  ///
  /// - Parameter condition: The condition on observable model values that are
  ///   certain to change.
  func render(when condition: @MainActor () -> Bool) async
}

extension RenderedMount {
  /// Waits until `condition` holds, then until the main run loop has run the
  /// update that SwiftUI queued for the change, then renders.
  ///
  /// - Parameter condition: The condition on observable model values that are
  ///   certain to change.
  func render(when condition: @MainActor () -> Bool) async {
    await ObservationWait.until(condition)
    await RunLoopBlockFence.afterPendingBlocks()
    render()
  }
}

extension HostedViewHarness: RenderedMount {}

extension CaptureMount: RenderedMount {}

/// The mount of a key screen of EditorKit's review gallery, as the `settle`
/// of a `ReviewScreen` receives it: the real key window on the screen.
extension ReviewMount: RenderedMount {
  /// Makes SwiftUI update the view now: a layout pass of the hosting view,
  /// then a display of the window.
  func render() {
    layOutAndDisplay(hostingView, in: window)
  }
}

/// Makes SwiftUI update a mounted view now: a layout pass of `view`, then a
/// display of `window`.
///
/// - Parameters:
///   - view: The hosting view of the mount.
///   - window: The window that shows it.
func layOutAndDisplay(_ view: NSView, in window: NSWindow) {
  view.layoutSubtreeIfNeeded()
  window.displayIfNeeded()
}

/// Hides each AppKit view of `types` under `root`, such as the `QLPreviewView`
/// of the attachment inspector: QuickLook draws its preview out of process, at
/// a time that no event of the view tells.
///
/// - Parameters:
///   - types: The classes of the views to hide.
///   - root: The hosting view of the mount.
func hideViews(of types: [NSView.Type], in root: NSView) {
  for view in root.descendants where types.contains(where: view.isKind(of:)) {
    view.isHidden = true
  }
}

/// A view of the kit mounted in a real borderless window of its own, for a
/// capture from the window server (EditorKit `style.md`, rule 9).
///
/// The window is EditorKit's `CaptureWindow`: the capture orders it in and
/// makes it the key window, with no activation of the test process, and
/// ScreenCaptureKit reads its pixels as the window server composites them, so
/// the image shows Liquid Glass, the scroll edge effect and every AppKit view,
/// as the app shows them. The view shows in the appearance of its look, under
/// the pins of every screen of the kits (EditorKit `ReviewScreenRoot`): one
/// locale, one time zone, one calendar, no animation and Reduce Motion on, so
/// the endless animations of the kit stand still. EditorKit's capture stops
/// each AppKit progress indicator, which reads no Reduce Motion, so that it
/// takes the first two equal images. A test that mounts one runs under
/// `.hostedSerially`. The test calls ``close()`` at the end.
final class CaptureMount<Content: View> {
  /// The window, on the screen once the first capture orders it in.
  let window: CaptureWindow

  /// The hosting view of the view: the content view of the window.
  let hostingView: NSHostingView<ReviewScreenRoot<Content>>

  /// Mounts `content` at `size` in the appearance of `appearance`, and lays it
  /// out.
  ///
  /// - Parameters:
  ///   - content: The view to show.
  ///   - size: The size of the content of the window, in points.
  ///   - appearance: The look of the window: Light or Dark.
  init(_ content: Content, size: CGSize, appearance: ReviewAppearance = .light) {
    window = CaptureWindow(contentSize: size, styleMask: [.borderless])
    window.appearance = NSAppearance(named: appearance.appearanceName)
    hostingView = NSHostingView(rootView: ReviewScreenRoot { content })
    // A view with no outer padding is as small as its content, and the
    // default sizing of a hosting view shrinks the window around it. The
    // window keeps the `size` of the mount, as EditorKit's own mount keeps it.
    hostingView.sizingOptions = []
    hostingView.frame = NSRect(origin: .zero, size: size)
    window.contentView = hostingView
    render()
  }

  /// Makes SwiftUI update the view now: a layout pass of the hosting view,
  /// then a display of the window.
  func render() {
    layOutAndDisplay(hostingView, in: window)
  }

  /// Captures the whole window from the window server.
  ///
  /// - Returns: The image of the window: the view over the window background.
  /// - Throws: A `WindowCaptureError`, or the error of ScreenCaptureKit.
  func capture() async throws -> CapturedImage {
    try await CapturedImage(capturing: window)
  }

  /// Closes the window.
  func close() {
    closeHostedWindow(window)
  }
}

extension CaptureMount {
  /// Mounts `content` at `size` in `appearance`, runs `settle`, hides each
  /// AppKit view of `hiddenTypes`, captures the window and closes it.
  ///
  /// - Parameters:
  ///   - content: The view to show.
  ///   - size: The size of the content of the window, in points.
  ///   - appearance: The look of the window.
  ///   - hiddenTypes: The classes of the AppKit views that the image does not
  ///     show, such as the `QLPreviewView` of the attachment inspector:
  ///     QuickLook draws its preview out of process, at a time that no event
  ///     of the view tells. The default hides no view.
  ///   - settle: The wait for an event of the mounted view before the image,
  ///     such as the end of the syntax parse of a code block. Do not wait for
  ///     a time.
  /// - Returns: The image of the window.
  /// - Throws: The error of `settle`, a `WindowCaptureError`, or the error of
  ///   ScreenCaptureKit.
  static func capture(
    _ content: Content, size: CGSize, appearance: ReviewAppearance = .light, hiding hiddenTypes: [NSView.Type] = [],
    settle: @MainActor (CaptureMount) async throws -> Void = { _ in }
  ) async throws -> CapturedImage {
    let mount = CaptureMount(content, size: size, appearance: appearance)
    defer { mount.close() }
    try await settle(mount)
    mount.render()
    // The insertion point of a focused text view blinks, so two captures of
    // one view differ by when they were taken (a 2 pt by 16 pt bar). No
    // capture shows it: the display mode `.hidden` stays hidden when the
    // blink or the focus would show the indicator again.
    for indicator in mount.hostingView.descendants.compactMap({ $0 as? NSTextInsertionIndicator }) {
      indicator.displayMode = .hidden
    }
    hideViews(of: hiddenTypes, in: mount.hostingView)
    return try await mount.capture()
  }
}
