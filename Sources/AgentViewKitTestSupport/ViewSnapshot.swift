import AppKit
import SwiftUI

/// The pixels of a view for a snapshot image (AVK-13), at a fixed size and
/// at ``RenderedPixels/renderScale``, in sRGB.
///
/// The type has two render paths:
///
/// - ``hostedPixels(of:size:variant:settle:)`` (path A) mounts the real view
///   in the off-screen window of ``HostedViewHarness`` and reads the cache of
///   the window. Use it for each view, except a glass part. It draws the
///   AppKit views, such as a `ScrollView`, a `List`, a `TextEditor` and the
///   EditorKit editor, and the views with `accessibilityFocused(_:)`. The
///   cache of a window shows no glass (`GlassRenderProbeTests`).
/// - ``renderedPixels(of:size:variant:)`` (path B) renders the view with
///   `ImageRenderer`. Use it for a glass part in isolation, such as the
///   field of the composer, the request deck in the bar, or the floating
///   controls. It draws no AppKit view and no view with
///   `accessibilityFocused(_:)`.
///
/// Each path shows the view over the window background, with the settings of
/// a ``SnapshotVariant``. Give the view fixed data and fixed dates.
public enum ViewSnapshot {
  /// Mounts `view` in a hidden window and reads the pixels that AppKit
  /// caches for it (path A).
  ///
  /// The function sets the appearance of the window to the appearance of
  /// `variant`, so that the AppKit views use the colors of the variant. It
  /// makes one ``HostedViewHarness/render()`` pass, then runs `settle`, then
  /// makes one more pass, and then reads the cache. The window never shows
  /// and never takes the focus (AVK-12).
  ///
  /// Before it reads the cache, the function hides the scroll edge effect of
  /// each scroll view in `view` (``ScrollPocketProbe/hidePockets(in:)``).
  /// The cache of a window cannot draw the effect: the backdrop layer of a
  /// soft edge effect, such as the one that the list of a thread asks for
  /// (^ph0m0hf), leaves an empty image with only the gradient of the effect.
  ///
  /// - Parameters:
  ///   - view: The real view to show.
  ///   - size: The size of the view, in points.
  ///   - variant: The settings of the image.
  ///   - settle: The work that waits for a certain event before the image,
  ///     for example the end of the syntax parse of a code block
  ///     (`SyntaxCoordinator.ensureParsed(upTo:)`). Do not wait for a time.
  /// - Returns: The pixels, or `nil` when AppKit gives no cache.
  /// - Throws: The error of `settle`.
  @MainActor
  public static func hostedPixels(
    of view: some View, size: CGSize, variant: SnapshotVariant,
    settle: @MainActor () async throws -> Void = {}
  ) async rethrows -> RenderedPixels? {
    let harness = HostedViewHarness(variant.pinned(view), size: size)
    defer { harness.close() }
    harness.window.appearance = NSAppearance(named: variant.appearanceName)
    harness.render()
    try await settle()
    harness.render()
    ScrollPocketProbe.hidePockets(in: harness.hostingView)
    return RenderedPixels(cachingDisplayOf: harness.hostingView, scale: RenderedPixels.renderScale)
  }

  /// Renders `view` with `ImageRenderer` (path B).
  ///
  /// The image shows a glass look: `ImageRenderer` draws Liquid Glass in the
  /// test process with no window and no screen. The look can be different
  /// from the Liquid Glass that the system draws in a window on the screen.
  /// It also follows Reduce Transparency and Increase Contrast.
  ///
  /// - Parameters:
  ///   - view: The glass part to render.
  ///   - size: The size of the view, in points.
  ///   - variant: The settings of the image.
  /// - Returns: The pixels, or `nil` when the renderer gives no image.
  @MainActor
  public static func renderedPixels(of view: some View, size: CGSize, variant: SnapshotVariant)
    -> RenderedPixels?
  {
    RenderedPixels(rendering: variant.pinned(view), size: size)
  }
}
