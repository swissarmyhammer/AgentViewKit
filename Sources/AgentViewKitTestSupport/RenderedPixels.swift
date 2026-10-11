import AppKit
import CoreGraphics
import SwiftUI

/// The pixels of a SwiftUI view that `ImageRenderer` draws, in sRGB.
///
/// A test uses this type to learn which colors a view draws. For example, a
/// test gives a view an EditorKit theme with a color that no other part of
/// the view uses, and then checks that the pixels contain that color.
///
/// `ImageRenderer` draws SwiftUI content only. It does not draw the AppKit
/// view of an `NSViewRepresentable`, such as the EditorKit editor. The
/// renderer runs in the test process, with no window and no screen.
public struct RenderedPixels {
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

  /// The pixel bytes, ``bytesPerPixel`` for each pixel. The color components
  /// have the alpha multiplied in, so only an opaque pixel keeps the full
  /// components of its color.
  private let bytes: [UInt8]

  /// Renders `view` at `size` points.
  ///
  /// - Parameters:
  ///   - view: The view to render.
  ///   - size: The size of the view, in points.
  /// - Returns: `nil` when the renderer gives no image or the pixels cannot
  ///   be read.
  @MainActor
  public init?(rendering view: some View, size: CGSize) {
    let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
    renderer.scale = Self.renderScale
    guard let image = renderer.cgImage, let bytes = Self.bytes(of: image) else { return nil }
    self.bytes = bytes
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
      let pixel = (0..<Self.bytesPerPixel).map { Double(bytes[offset + $0]) / Self.componentMaximum }
      return zip(pixel, target).allSatisfy { abs($0 - $1) <= tolerance }
    }
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
