@testable import AgentViewKitTestSupport
import CoreGraphics
import SwiftUI

/// The colors of one region of an image: its background and its ink, for the
/// contrast checks of the composited images (^zbcys18).
///
/// The background is the color that covers the most pixels of the region.
/// The ink is the pixel whose contrast with the background is the largest,
/// such as the core of a glyph of a line of text.
struct RegionColors {
  /// The color that covers the most pixels of the region.
  let background: ResolvedColor

  /// The pixel of the region whose contrast with ``background`` is the
  /// largest.
  let ink: ResolvedColor

  /// The WCAG contrast ratio of ``ink`` and ``background``, from 1 to 21.
  var contrast: Double {
    ink.contrast(with: background)
  }

  /// Reads the colors of `region` of `pixels`.
  ///
  /// - Parameters:
  ///   - pixels: The image.
  ///   - region: The region, in points from the top leading corner of the
  ///     image.
  /// - Returns: `nil` when no pixel of the image is in `region`.
  init?(of pixels: RenderedPixels, in region: CGRect) {
    let colors = Self.colors(of: pixels, in: region)
    let counts = Dictionary(colors.map { ($0, 1) }, uniquingKeysWith: +)
    guard let background = counts.max(by: { $0.value < $1.value })?.key.color,
      let ink = colors.map(\.color).max(by: { $0.contrast(with: background) < $1.contrast(with: background) })
    else { return nil }
    self.background = background
    self.ink = ink
  }

  /// Whether a pixel of `region` of `pixels` has `color`.
  ///
  /// The pixels are the pixels that ``colors(of:in:)`` reads, and each one
  /// is matched as ``RenderedPixels/contains(_:at:tolerance:)`` matches it.
  ///
  /// - Parameters:
  ///   - color: The color to find. Use a color with no dynamic part, such as
  ///     a resolved theme color.
  ///   - region: The region, in points from the top leading corner of the
  ///     image.
  ///   - pixels: The image.
  ///   - tolerance: The largest difference of one component, from 0 to 1.
  /// - Returns: `true` when at least one pixel of `region` has `color`.
  static func contains(
    _ color: Color, in region: CGRect, of pixels: RenderedPixels, tolerance: Double = RenderedPixels.defaultTolerance
  ) -> Bool {
    centers(of: pixels, in: region).contains { pixels.contains(color, at: $0, tolerance: tolerance) }
  }

  /// The frame of each column of the pixels of `region` of `pixels`.
  ///
  /// The columns hold the pixels that ``colors(of:in:)`` reads: each frame is
  /// one pixel wide, and as high as the pixels of `region`.
  ///
  /// - Parameters:
  ///   - pixels: The image.
  ///   - region: The region, in points from the top leading corner of the
  ///     image.
  /// - Returns: The frames, in points from the top leading corner of the
  ///   image, from the leading column to the trailing column. Empty when no
  ///   pixel of the image is in `region`.
  static func columns(of pixels: RenderedPixels, in region: CGRect) -> [CGRect] {
    guard let pixelRegion = pixelRegion(of: pixels, in: region) else { return [] }
    let toPoints = CGAffineTransform(scaleX: 1 / pixels.scale, y: 1 / pixels.scale)
    return (Int(pixelRegion.minX)..<Int(pixelRegion.maxX)).map { column in
      CGRect(x: CGFloat(column), y: pixelRegion.minY, width: 1, height: pixelRegion.height).applying(toPoints)
    }
  }

  /// The distance from the top leading corner of a pixel to its center, in
  /// pixels.
  private static let pixelCenter: CGFloat = 0.5

  /// The color of each pixel of `pixels` whose top leading corner is in
  /// `region`.
  ///
  /// - Parameters:
  ///   - pixels: The image.
  ///   - region: The region, in points from the top leading corner.
  /// - Returns: The colors, from the top row to the bottom row.
  private static func colors(of pixels: RenderedPixels, in region: CGRect) -> [PixelColor] {
    centers(of: pixels, in: region).compactMap(pixels.offset(of:)).map { offset in
      PixelColor(components: pixels.components(atOffset: offset))
    }
  }

  /// The center of each pixel of `pixels` whose top leading corner is in
  /// `region`.
  ///
  /// This method is the one walk over the pixels of a region: ``colors(of:in:)``
  /// and ``contains(_:in:of:tolerance:)`` both read the pixels it gives.
  ///
  /// - Parameters:
  ///   - pixels: The image.
  ///   - region: The region, in points from the top leading corner.
  /// - Returns: The centers, in points from the top leading corner, from the
  ///   top row to the bottom row.
  private static func centers(of pixels: RenderedPixels, in region: CGRect) -> [CGPoint] {
    guard let pixelRegion = pixelRegion(of: pixels, in: region) else { return [] }
    return (Int(pixelRegion.minY)..<Int(pixelRegion.maxY)).flatMap { row in
      (Int(pixelRegion.minX)..<Int(pixelRegion.maxX)).map { column in
        CGPoint(
          x: (CGFloat(column) + pixelCenter) / pixels.scale,
          y: (CGFloat(row) + pixelCenter) / pixels.scale)
      }
    }
  }

  /// `region` in whole pixels of `pixels`: each pixel whose area meets
  /// `region`, within the image.
  ///
  /// - Parameters:
  ///   - pixels: The image.
  ///   - region: The region, in points from the top leading corner.
  /// - Returns: The region in pixels from the top leading corner, or `nil`
  ///   when it holds no pixel of the image.
  private static func pixelRegion(of pixels: RenderedPixels, in region: CGRect) -> CGRect? {
    let pixelRegion = region.applying(CGAffineTransform(scaleX: pixels.scale, y: pixels.scale)).integral
      .intersection(CGRect(x: 0, y: 0, width: pixels.width, height: pixels.height))
    return pixelRegion.isEmpty ? nil : pixelRegion
  }
}

/// The color of one opaque pixel, hashable so that ``RegionColors`` can count
/// the pixels of each color.
private struct PixelColor: Hashable {
  /// The place of each color channel in the components of a pixel.
  private enum Channel: Int {
    /// The red channel, first.
    case red
    /// The green channel, second.
    case green
    /// The blue channel, third.
    case blue
  }

  /// Red, green, blue and alpha, from 0 to 1.
  let components: [Double]

  /// The color as an opaque ``ResolvedColor``.
  var color: ResolvedColor {
    ResolvedColor(
      red: components[Channel.red.rawValue], green: components[Channel.green.rawValue],
      blue: components[Channel.blue.rawValue], alpha: 1)
  }
}
