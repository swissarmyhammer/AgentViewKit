@testable import AgentViewKitTestSupport
import CoreGraphics

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

  /// The color of each pixel of `pixels` whose top leading corner is in
  /// `region`.
  ///
  /// - Parameters:
  ///   - pixels: The image.
  ///   - region: The region, in points from the top leading corner.
  /// - Returns: The colors, from the top row to the bottom row.
  private static func colors(of pixels: RenderedPixels, in region: CGRect) -> [PixelColor] {
    let pixelRegion = region.applying(CGAffineTransform(scaleX: pixels.scale, y: pixels.scale)).integral
      .intersection(CGRect(x: 0, y: 0, width: pixels.width, height: pixels.height))
    guard !pixelRegion.isNull else { return [] }
    return (Int(pixelRegion.minY)..<Int(pixelRegion.maxY)).flatMap { row in
      (Int(pixelRegion.minX)..<Int(pixelRegion.maxX)).map { column in
        PixelColor(components: pixels.components(atOffset: (row * pixels.width + column) * RenderedPixels.bytesPerPixel))
      }
    }
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
