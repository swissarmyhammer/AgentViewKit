import AppKit
import CoreGraphics
import SwiftUI

/// The pixels of a SwiftUI view that `ImageRenderer` draws, or that AppKit
/// caches for a view in a window, in sRGB.
///
/// A test uses this type to learn which colors a view draws. For example, a
/// test gives a view an EditorKit theme with a color that no other part of
/// the view uses, and then checks that the pixels contain that color. Two
/// values are equal when they have the same bytes, so a test can also
/// compare two renders.
///
/// `ImageRenderer` draws SwiftUI content only. It does not draw the AppKit
/// view of an `NSViewRepresentable`, such as the EditorKit editor. The
/// renderer runs in the test process, with no window and no screen.
///
/// `ImageRenderer` draws Liquid Glass, and the glass follows the
/// accessibility values in the environment, such as
/// `_accessibilityReduceTransparency`. The cache of a view in a window does
/// not show the glass, because the render server of the system draws it
/// there (`GlassRenderProbeTests`).
public struct RenderedPixels: Equatable {
  /// The bytes of one pixel: red, green, blue and alpha, one byte each.
  private static let bytesPerPixel = 4

  /// The bits of one color component.
  private static let bitsPerComponent = 8

  /// The largest value of one color component in a byte.
  private static let componentMaximum = 255.0

  /// The pixels at the scale of a Retina screen, two pixels for each point.
  private static let renderScale: CGFloat = 2

  /// The default largest difference of one color component, from 0 to 1,
  /// between a pixel and the color that a test looks for.
  public static let defaultTolerance = 0.02

  /// A hosting view that the type makes one time, before its first render.
  ///
  /// `ImageRenderer` draws no Liquid Glass until the process makes its first
  /// `NSHostingView`. Before that, a `glassEffect` draws nothing. Thus,
  /// without this view, the pixels of a glass view would change with the
  /// order of the tests (`RenderedPixelsTests`).
  private static let glassRenderingHost = NSHostingView(rootView: EmptyView())

  /// The pixel bytes, ``bytesPerPixel`` for each pixel. The color components
  /// have the alpha multiplied in, so only an opaque pixel keeps the full
  /// components of its color.
  private let bytes: [UInt8]

  /// The number of pixels in one row. The first row of ``bytes`` is the top
  /// row of the image.
  private let width: Int

  /// The number of rows of pixels.
  private let height: Int

  /// The number of pixels for each point.
  private let scale: CGFloat

  /// Renders `view` at `size` points.
  ///
  /// - Parameters:
  ///   - view: The view to render.
  ///   - size: The size of the view, in points.
  /// - Returns: `nil` when the renderer gives no image or the pixels cannot
  ///   be read.
  @MainActor
  public init?(rendering view: some View, size: CGSize) {
    _ = Self.glassRenderingHost
    let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
    renderer.scale = Self.renderScale
    guard let image = renderer.cgImage else { return nil }
    self.init(image: image, scale: Self.renderScale)
  }

  /// Reads the pixels that AppKit caches for `view` and its subviews.
  ///
  /// Use this initializer for a view in the window of a
  /// ``HostedViewHarness``, for example its `hostingView`. The cache has the
  /// scale of the window.
  ///
  /// - Parameter view: The view to read.
  /// - Returns: `nil` when AppKit gives no cache, the view has no width, or
  ///   the pixels cannot be read.
  @MainActor
  public init?(cachingDisplayOf view: NSView) {
    guard let cache = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
    view.cacheDisplay(in: view.bounds, to: cache)
    guard let image = cache.cgImage, view.bounds.width > 0 else { return nil }
    self.init(image: image, scale: CGFloat(image.width) / view.bounds.width)
  }

  /// Reads the pixels of `image`.
  ///
  /// - Parameters:
  ///   - image: The image to read.
  ///   - scale: The number of pixels in `image` for each point.
  /// - Returns: `nil` when the pixels cannot be read.
  private init?(image: CGImage, scale: CGFloat) {
    guard let bytes = Self.bytes(of: image) else { return nil }
    self.bytes = bytes
    self.width = image.width
    self.height = image.height
    self.scale = scale
  }

  /// Whether a pixel has the color `color`.
  ///
  /// A pixel has the color when it is opaque and each of its sRGB components
  /// is in `tolerance` of the component of `color`.
  ///
  /// - Parameters:
  ///   - color: The color to find. Use a color with no dynamic part, such as
  ///     `Color(red:green:blue:)`.
  ///   - tolerance: The largest difference of one component, from 0 to 1.
  /// - Returns: `true` when at least one pixel has the color.
  public func contains(_ color: Color, tolerance: Double = defaultTolerance) -> Bool {
    guard let target = Self.components(of: color) else { return false }
    return stride(from: 0, to: bytes.count, by: Self.bytesPerPixel).contains { offset in
      pixel(atOffset: offset, matches: target, tolerance: tolerance)
    }
  }

  /// Whether the pixel at `point` has the color `color`.
  ///
  /// The pixel has the color when it is opaque and each of its sRGB
  /// components is in `tolerance` of the component of `color`.
  ///
  /// - Parameters:
  ///   - color: The color to find. Use a color with no dynamic part, such as
  ///     `Color(red:green:blue:)`.
  ///   - point: The point to read, in points from the top leading corner of
  ///     the view.
  ///   - tolerance: The largest difference of one component, from 0 to 1.
  /// - Returns: `true` when the pixel at `point` has the color. `false` when
  ///   `point` is not in the view.
  public func contains(
    _ color: Color, at point: CGPoint, tolerance: Double = defaultTolerance
  ) -> Bool {
    guard let target = Self.components(of: color), let offset = offset(of: point) else {
      return false
    }
    return pixel(atOffset: offset, matches: target, tolerance: tolerance)
  }

  /// The offset in ``bytes`` of the pixel at `point`.
  ///
  /// - Parameter point: A point from the top leading corner of the view.
  /// - Returns: The offset, or `nil` when `point` is not in the view.
  private func offset(of point: CGPoint) -> Int? {
    let column = Int((point.x * scale).rounded(.down))
    let row = Int((point.y * scale).rounded(.down))
    guard (0..<width).contains(column), (0..<height).contains(row) else { return nil }
    return (row * width + column) * Self.bytesPerPixel
  }

  /// Whether the pixel at `offset` in ``bytes`` has the components `target`.
  ///
  /// - Parameters:
  ///   - offset: The offset of the first byte of the pixel.
  ///   - target: Red, green, blue and alpha, from 0 to 1.
  ///   - tolerance: The largest difference of one component, from 0 to 1.
  /// - Returns: `true` when each component is in `tolerance` of `target`.
  private func pixel(atOffset offset: Int, matches target: [Double], tolerance: Double) -> Bool {
    let pixel = (0..<Self.bytesPerPixel).map { Double(bytes[offset + $0]) / Self.componentMaximum }
    return zip(pixel, target).allSatisfy { abs($0 - $1) <= tolerance }
  }

  /// The sRGB components of `color`, with an alpha of one.
  ///
  /// - Parameter color: A color with no dynamic part.
  /// - Returns: Red, green, blue and alpha, from 0 to 1, or `nil` when the
  ///   color has no sRGB form.
  private static func components(of color: Color) -> [Double]? {
    guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return nil }
    return [srgb.redComponent, srgb.greenComponent, srgb.blueComponent, 1].map { Double($0) }
  }

  /// The pixels of `image`, drawn into an sRGB buffer of known layout.
  ///
  /// - Parameter image: The image to read.
  /// - Returns: The bytes, or `nil` when the buffer cannot be made.
  private static func bytes(of image: CGImage) -> [UInt8]? {
    let bytesPerRow = image.width * bytesPerPixel
    var bytes = [UInt8](repeating: 0, count: bytesPerRow * image.height)
    let drew = bytes.withUnsafeMutableBytes { buffer -> Bool in
      guard let space = CGColorSpace(name: CGColorSpace.sRGB),
        let context = CGContext(
          data: buffer.baseAddress, width: image.width, height: image.height,
          bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: space,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      else { return false }
      context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
      return true
    }
    return drew ? bytes : nil
  }
}
