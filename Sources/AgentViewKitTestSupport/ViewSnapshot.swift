import AppKit
import SwiftUI

/// The pixels of a view for a snapshot image (AVK-13), at a fixed size and
/// at ``RenderedPixels/renderScale``, in sRGB.
///
/// The type has three render paths:
///
/// - ``hostedPixels(of:size:variant:hiding:settle:)`` (path A) mounts the
///   real view in the off-screen window of ``HostedViewHarness`` and reads
///   the cache of the window. Use it for each view, except a glass part. It
///   draws the AppKit views, such as a `ScrollView`, a `List`, a `TextEditor`
///   and the EditorKit editor, and the views with `accessibilityFocused(_:)`.
///   The cache of a window shows no glass (`GlassRenderProbeTests`), and it
///   shows a vibrant label, such as the text of a sidebar `List` row, as its
///   black mask in the dark variant. The recorded snapshot images use it.
/// - ``renderedPixels(of:size:variant:)`` (path B) renders the view with
///   `ImageRenderer`. Use it for a glass part in isolation, such as the
///   field of the composer, the request deck in the bar, or the floating
///   controls. It draws no AppKit view and no view with
///   `accessibilityFocused(_:)`.
/// - ``compositedPixels(of:size:variant:hiding:settle:)`` (path C) mounts
///   the real view in the window of path A and renders the layer tree of the
///   window with the renderer of Core Animation (``LayerTreeRenderer``). It
///   draws the AppKit views and Liquid Glass, the scroll edge effect, the
///   vibrant labels in the look of the variant, and the glyphs of the glass
///   buttons. The review gallery uses it, so that a person sees what a window
///   shows.
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
  /// The function also hides each AppKit view in `view` whose class is one of
  /// `hiddenTypes`, or a subclass of one. Give the class of a view that draws
  /// different pixels on each run, such as the `QLPreviewView` of the
  /// `AttachmentInspector` of the kit: QuickLook draws its preview out of
  /// process, at a time that no event of the view tells. The image then
  /// shows the place of the view, with the views behind it.
  ///
  /// - Parameters:
  ///   - view: The real view to show.
  ///   - size: The size of the view, in points.
  ///   - variant: The settings of the image.
  ///   - hiddenTypes: The classes of the AppKit views that the image does not
  ///     show. The default hides no view.
  ///   - settle: The work that waits for a certain event before the image,
  ///     for example the end of the syntax parse of a code block
  ///     (`SyntaxCoordinator.ensureParsed(upTo:)`). Do not wait for a time.
  /// - Returns: The pixels, or `nil` when AppKit gives no cache.
  /// - Throws: The error of `settle`.
  @MainActor
  public static func hostedPixels(
    of view: some View, size: CGSize, variant: SnapshotVariant,
    hiding hiddenTypes: [NSView.Type] = [], settle: @MainActor () async throws -> Void = {}
  ) async rethrows -> RenderedPixels? {
    try await settledPixels(of: view, size: size, variant: variant, settle: settle) { hostingView in
      cachedPixels(of: hostingView, hiding: hiddenTypes)
    }
  }

  /// Mounts `view` in a hidden window with the settings of `variant`, for a
  /// test that drives the view through more than one render pass before the
  /// image, such as a scroll by command (path A).
  ///
  /// The window has the appearance of `variant`. The caller makes the render
  /// passes, reads the image with ``pixels(of:hiding:)``, and closes the
  /// harness. ``hostedPixels(of:size:variant:hiding:settle:)`` does the same
  /// with one settle step.
  ///
  /// - Parameters:
  ///   - view: The real view to show.
  ///   - size: The size of the view, in points.
  ///   - variant: The settings of the image.
  /// - Returns: The harness, before its first render pass.
  @MainActor
  public static func makeHarness(of view: some View, size: CGSize, variant: SnapshotVariant)
    -> HostedViewHarness<some View>
  {
    let harness = HostedViewHarness(variant.pinned(view), size: size)
    harness.window.appearance = NSAppearance(named: variant.appearanceName)
    return harness
  }

  /// Reads the pixels that AppKit caches for the view of `harness` (path A),
  /// after it hides the scroll edge effects and each AppKit view of
  /// `hiddenTypes`. See ``hostedPixels(of:size:variant:hiding:settle:)``.
  ///
  /// - Parameters:
  ///   - harness: The harness of ``makeHarness(of:size:variant:)``, after its
  ///     last render pass.
  ///   - hiddenTypes: The classes of the AppKit views that the image does not
  ///     show. The default hides no view.
  /// - Returns: The pixels, or `nil` when AppKit gives no cache.
  @MainActor
  public static func pixels(of harness: HostedViewHarness<some View>, hiding hiddenTypes: [NSView.Type] = [])
    -> RenderedPixels?
  {
    cachedPixels(of: harness.hostingView, hiding: hiddenTypes)
  }

  /// Reads the pixels that AppKit caches for `hostingView` (path A), after it
  /// hides the scroll edge effects and each AppKit view of `hiddenTypes`.
  ///
  /// - Parameters:
  ///   - hostingView: The hosting view of a harness, after its last render
  ///     pass.
  ///   - hiddenTypes: The classes of the AppKit views that the image does not
  ///     show.
  /// - Returns: The pixels, or `nil` when AppKit gives no cache.
  @MainActor
  private static func cachedPixels(of hostingView: NSView, hiding hiddenTypes: [NSView.Type])
    -> RenderedPixels?
  {
    ScrollPocketProbe.hidePockets(in: hostingView)
    hostingView.hideDescendants(of: hiddenTypes)
    return RenderedPixels(cachingDisplayOf: hostingView, scale: RenderedPixels.renderScale)
  }

  /// Mounts `view` in a hidden window and renders the layer tree of the
  /// window with the renderer of Core Animation (path C, ^zbcys18).
  ///
  /// The window is the window of path A, with the appearance of `variant`,
  /// and the function makes the same render passes around `settle`. The image
  /// then shows what path A cannot draw: Liquid Glass, the scroll edge effect,
  /// a vibrant label in the light or dark look of the variant, and the glyph
  /// of a symbol-only glass button (``LayerTreeRenderer``). The window never
  /// shows and never takes the focus (AVK-12).
  ///
  /// The image is in process, so it can differ from a window on the screen in
  /// what only the render server knows: the desktop behind a window, and the
  /// color space of the display. A popover is its own window that AppKit puts
  /// on the screen, so the image never shows one.
  ///
  /// - Parameters:
  ///   - view: The real view to show.
  ///   - size: The size of the view, in points.
  ///   - variant: The settings of the image.
  ///   - hiddenTypes: The classes of the AppKit views that the image does not
  ///     show, as in ``hostedPixels(of:size:variant:hiding:settle:)``. The
  ///     default hides no view.
  ///   - settle: The work that waits for a certain event before the image. Do
  ///     not wait for a time.
  /// - Returns: The pixels, or `nil` when the computer has no Metal device.
  /// - Throws: The error of `settle`.
  @MainActor
  public static func compositedPixels(
    of view: some View, size: CGSize, variant: SnapshotVariant,
    hiding hiddenTypes: [NSView.Type] = [], settle: @MainActor () async throws -> Void = {}
  ) async rethrows -> RenderedPixels? {
    try await settledPixels(of: view, size: size, variant: variant, settle: settle) { hostingView in
      compositedPixels(of: hostingView, hiding: hiddenTypes)
    }
  }

  /// Renders the layer tree of the window of `harness` with the renderer of
  /// Core Animation (path C), after it hides each AppKit view of
  /// `hiddenTypes`. See ``compositedPixels(of:size:variant:hiding:settle:)``.
  ///
  /// - Parameters:
  ///   - harness: The harness of ``makeHarness(of:size:variant:)``, after its
  ///     last render pass.
  ///   - hiddenTypes: The classes of the AppKit views that the image does not
  ///     show. The default hides no view.
  /// - Returns: The pixels, or `nil` when the computer has no Metal device.
  @MainActor
  public static func compositedPixels(
    of harness: HostedViewHarness<some View>, hiding hiddenTypes: [NSView.Type] = []
  ) -> RenderedPixels? {
    compositedPixels(of: harness.hostingView, hiding: hiddenTypes)
  }

  /// Renders the layer tree of `hostingView` (path C), after it hides each
  /// AppKit view of `hiddenTypes`.
  ///
  /// - Parameters:
  ///   - hostingView: The hosting view of a harness, after its last render
  ///     pass.
  ///   - hiddenTypes: The classes of the AppKit views that the image does not
  ///     show.
  /// - Returns: The pixels, or `nil` when the computer has no Metal device.
  @MainActor
  private static func compositedPixels(of hostingView: NSView, hiding hiddenTypes: [NSView.Type])
    -> RenderedPixels?
  {
    hostingView.hideDescendants(of: hiddenTypes)
    return LayerTreeRenderer.pixels(of: hostingView, scale: RenderedPixels.renderScale)
  }

  /// Mounts `view` in a hidden window with the settings of `variant`, makes
  /// one render pass, runs `settle`, makes one more pass, and reads the image
  /// of the hosting view with `read`. The harness closes before the function
  /// returns.
  ///
  /// - Parameters:
  ///   - view: The real view to show.
  ///   - size: The size of the view, in points.
  ///   - variant: The settings of the image.
  ///   - settle: The work that waits for a certain event before the image.
  ///   - read: The read of the image of the hosting view: path A or path C.
  /// - Returns: The pixels that `read` gives.
  /// - Throws: The error of `settle`.
  @MainActor
  private static func settledPixels(
    of view: some View, size: CGSize, variant: SnapshotVariant, settle: @MainActor () async throws -> Void,
    read: @MainActor (NSView) -> RenderedPixels?
  ) async rethrows -> RenderedPixels? {
    let harness = makeHarness(of: view, size: size, variant: variant)
    defer { harness.close() }
    harness.render()
    try await settle()
    harness.render()
    return read(harness.hostingView)
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
