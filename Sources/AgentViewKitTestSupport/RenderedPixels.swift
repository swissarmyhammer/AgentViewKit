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

  /// The distance from the top leading corner of a pixel to its center, in
  /// pixels.
  private static let pixelCenter: CGFloat = 0.5

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
    return pixelOffsets.contains { offset in
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

  /// Whether these pixels and `other` show the same image.
  ///
  /// The renderer can change a byte of an anti-aliased edge by one level
  /// between two renders of one view. Thus, use this method, and not `==`,
  /// to find that a setting does not change a view. The images show the same
  /// when they have the same size and each byte is in `tolerance` of the
  /// byte of `other`.
  ///
  /// - Parameters:
  ///   - other: The pixels to compare with.
  ///   - tolerance: The largest difference of one component, from 0 to 1.
  /// - Returns: `true` when the images show the same.
  public func isClose(to other: RenderedPixels, tolerance: Double = defaultTolerance) -> Bool {
    isClose(to: other, atOffsets: Array(pixelOffsets), tolerance: tolerance)
  }

  /// Whether these pixels and `other` show the same colors at `points`.
  ///
  /// In one process, `ImageRenderer` draws the edge of a rounded glass
  /// differently in its first renders and in its later renders. The change
  /// comes from work that the system does in the background, so the number
  /// of renders before the change is not the same in each run. A test cannot
  /// wait for the change: it gives no event. The change is only near the
  /// edge: within 2 points of the edge, a byte can change by 31 levels.
  /// Farther in, a byte changes by one level or less. Thus, to find that a
  /// setting does not change a glass, use this method with points that are
  /// far from each edge, and not ``isClose(to:tolerance:)``.
  ///
  /// The images show the same colors when they have the same size, and each
  /// byte of the pixel at each point is in `tolerance` of the byte of
  /// `other`.
  ///
  /// - Parameters:
  ///   - other: The pixels to compare with.
  ///   - points: The points to read, in points from the top leading corner
  ///     of the view.
  ///   - tolerance: The largest difference of one component, from 0 to 1.
  /// - Returns: `true` when the images show the same colors at each point.
  ///   `false` when a point is not in the view.
  public func isClose(
    to other: RenderedPixels, at points: [CGPoint], tolerance: Double = defaultTolerance
  ) -> Bool {
    let offsets = points.map(offset(of:))
    guard offsets.allSatisfy({ $0 != nil }) else { return false }
    return isClose(to: other, atOffsets: offsets.compactMap { $0 }, tolerance: tolerance)
  }

  /// Whether these pixels and `other` show the same colors in `region`.
  ///
  /// Use this method to compare each pixel that is far from the edge of a
  /// rounded glass, for the reason that ``isClose(to:at:tolerance:)`` gives.
  /// The method reads each pixel whose center is in `region`.
  ///
  /// The images show the same colors when they have the same size, and each
  /// byte of each pixel in `region` is in `tolerance` of the byte of `other`.
  ///
  /// - Parameters:
  ///   - other: The pixels to compare with.
  ///   - region: The region to read, in points from the top leading corner
  ///     of the view.
  ///   - tolerance: The largest difference of one component, from 0 to 1.
  /// - Returns: `true` when the images show the same colors in `region`.
  ///   `false` when the center of no pixel is in `region`.
  public func isClose(
    to other: RenderedPixels, within region: Path, tolerance: Double = defaultTolerance
  ) -> Bool {
    let offsets = offsets(within: region)
    guard !offsets.isEmpty else { return false }
    return isClose(to: other, atOffsets: offsets, tolerance: tolerance)
  }

  /// Whether these pixels and `other` have the same size, and the same
  /// colors at `offsets`.
  ///
  /// - Parameters:
  ///   - other: The pixels to compare with.
  ///   - offsets: The offsets in ``bytes`` of the pixels to compare.
  ///   - tolerance: The largest difference of one component, from 0 to 1.
  /// - Returns: `true` when each byte of each pixel is in `tolerance` of the
  ///   byte of `other`.
  private func isClose(to other: RenderedPixels, atOffsets offsets: [Int], tolerance: Double)
    -> Bool
  {
    guard width == other.width, height == other.height, scale == other.scale else { return false }
    return offsets.allSatisfy { offset in
      pixel(atOffset: offset, matches: other.components(atOffset: offset), tolerance: tolerance)
    }
  }

  /// The offsets in ``bytes`` of the pixels whose center is in `region`.
  ///
  /// - Parameter region: A region in points from the top leading corner of
  ///   the view.
  /// - Returns: The offsets, from the top row to the bottom row.
  private func offsets(within region: Path) -> [Int] {
    (0..<height).flatMap { row in
      (0..<width).compactMap { column -> Int? in
        let center = CGPoint(
          x: (CGFloat(column) + Self.pixelCenter) / scale,
          y: (CGFloat(row) + Self.pixelCenter) / scale)
        return region.contains(center) ? offset(of: center) : nil
      }
    }
  }

  /// The offset in ``bytes`` of each pixel, from the first pixel of the top
  /// row to the last pixel of the bottom row.
  private var pixelOffsets: StrideTo<Int> {
    stride(from: 0, to: bytes.count, by: Self.bytesPerPixel)
  }

  /// The offset in ``bytes`` of the pixel at `point`.
  ///
  /// This method is the only place that changes a point into a pixel.
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
    zip(components(atOffset: offset), target).allSatisfy {
      Self.isWithin($0, $1, tolerance: tolerance)
    }
  }

  /// The components of the pixel at `offset` in ``bytes``.
  ///
  /// - Parameter offset: The offset of the first byte of the pixel.
  /// - Returns: Red, green, blue and alpha, from 0 to 1.
  private func components(atOffset offset: Int) -> [Double] {
    (0..<Self.bytesPerPixel).map { Self.component(bytes[offset + $0]) }
  }

  /// The value of the color component in `byte`, from 0 to 1.
  ///
  /// - Parameter byte: One byte of ``bytes``.
  /// - Returns: `byte` divided by ``componentMaximum``.
  private static func component(_ byte: UInt8) -> Double {
    Double(byte) / componentMaximum
  }

  /// Whether two color components have a difference of `tolerance` or less.
  ///
  /// - Parameters:
  ///   - a: One component, from 0 to 1.
  ///   - b: The other component, from 0 to 1.
  ///   - tolerance: The largest difference of one component, from 0 to 1.
  /// - Returns: `true` when `a` is in `tolerance` of `b`.
  private static func isWithin(_ a: Double, _ b: Double, tolerance: Double) -> Bool {
    abs(a - b) <= tolerance
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
