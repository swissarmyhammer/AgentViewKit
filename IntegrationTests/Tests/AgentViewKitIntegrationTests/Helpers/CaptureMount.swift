import AppKit
import EditorTestSupport
import SwiftUI
import Testing

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

/// The bed of EditorKit that shows command scopes with focus rings in a real
/// key window, which a test renders after it sends an item of a session.
extension FocusRingBed: RenderedMount {
  /// Makes SwiftUI update the view now: a layout pass of the content view of
  /// the window, the hosting view of the bed, then a display of the window.
  func render() {
    window.contentView?.layoutSubtreeIfNeeded()
    window.displayIfNeeded()
  }
}

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
  ///   - styleMask: The style of the window; borderless by default. A titled
  ///     style with `.fullSizeContentView` shows the title bar and the toolbar
  ///     of a `NavigationSplitView`.
  init(
    _ content: Content, size: CGSize, appearance: ReviewAppearance = .light,
    styleMask: NSWindow.StyleMask = [.borderless]
  ) {
    window = CaptureWindow(contentSize: size, styleMask: styleMask)
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
    // one view differ by when they were taken (a 2 pt by 16 pt bar). The text
    // view resets the display mode of its indicator on each blink, so the
    // capture takes the focus out of every text view: no capture shows an
    // insertion point.
    mount.window.makeFirstResponder(nil)
    await RunLoopBlockFence.afterPendingBlocks()
    mount.render()
    hideViews(of: hiddenTypes, in: mount.hostingView)
    return try await mount.capture()
  }

  /// The frame of the accessibility element with `identifier` when `content`
  /// shows at `size`, in points from the top leading corner of the window: the
  /// region of a capture of the same view at the same size that shows the
  /// element.
  ///
  /// The frame comes from the accessibility tree of the same view in the
  /// window of a ``HostedViewHarness``, under the same root as a mount, so
  /// that both lay the view out the same way.
  ///
  /// - Parameters:
  ///   - identifier: The accessibility identifier of the element.
  ///   - content: The view, as it is given to the mount of the capture.
  ///   - size: The size of the content of the window, in points.
  /// - Returns: The frame.
  /// - Throws: An issue when no element has `identifier`.
  static func windowFrame(of identifier: String, in content: Content, size: CGSize) throws -> CGRect {
    let harness = HostedViewHarness(ReviewScreenRoot { content }, size: size)
    defer { harness.close() }
    harness.render()
    let frame = try #require(harness.frame(identifier: identifier), "No element \(identifier).")
    return ThreadBarControlJumpHostedTests.windowSpaceFrame(of: frame, in: harness.window)
  }

  /// The frame of the first AppKit view whose class is named `className`
  /// when `content` shows at `size`, in points from the top leading corner of
  /// the window: the region of a capture of the same view at the same size
  /// that shows the view.
  ///
  /// The cell of a `List` row hosts its SwiftUI content in a view that the
  /// accessibility tree of the harness does not list, so a `List` row has no
  /// frame by identifier (``windowFrame(of:in:size:)``). The cell is a
  /// private AppKit class, so the lookup is by the name of the class.
  ///
  /// - Parameters:
  ///   - className: The name of the class of the view, such as
  ///     `ListTableCellView`.
  ///   - content: The view, as it is given to the mount of the capture.
  ///   - size: The size of the content of the window, in points.
  /// - Returns: The frame.
  /// - Throws: An issue when no view has the class.
  static func windowFrame(ofViewNamed className: String, in content: Content, size: CGSize) throws -> CGRect {
    let harness = HostedViewHarness(ReviewScreenRoot { content }, size: size)
    defer { harness.close() }
    harness.render()
    let view = try #require(
      harness.hostingView.descendants.first { String(describing: type(of: $0)) == className },
      "No view of the class \(className).")
    return ThreadBarControlJumpHostedTests.windowSpaceFrame(of: harness.screenFrame(of: view), in: harness.window)
  }
}

/// The pixel geometry of a capture: points of a view to the pixels of its
/// image, and a SwiftUI color to the color its pixels show.
enum CaptureGeometry {
  /// The pixels of a capture for one point.
  static var scale: CGFloat { CGFloat(CapturedImage.captureScale) }

  /// The pixel of a capture that holds `point` of the view.
  ///
  /// - Parameter point: A point of the view, from its top leading corner.
  /// - Returns: The column and the row of the pixel, from the top leading
  ///   corner of the image.
  static func pixel(at point: CGPoint) -> (x: Int, y: Int) {
    (Int((point.x * scale).rounded(.down)), Int((point.y * scale).rounded(.down)))
  }

  /// The pixels of a capture that `rect` of the view covers.
  ///
  /// - Parameter rect: A rect of the view, in points from its top leading
  ///   corner.
  /// - Returns: The rect in whole pixels, from the top leading corner of the
  ///   image.
  static func pixels(of rect: CGRect) -> CGRect {
    rect.applying(CGAffineTransform(scaleX: scale, y: scale)).integral
  }

  /// The sRGB color of `color` with no dynamic part, for a pixel read.
  ///
  /// - Parameter color: A fixed color, such as a role of
  ///   ``DistinctRolesTheme`` or the backdrop of ``GlassRenderProbeTests``.
  /// - Returns: The color.
  static func cgColor(of color: Color) -> CGColor {
    color.resolve(in: EnvironmentValues()).cgColor
  }
}
