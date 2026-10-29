import CoreGraphics
import EditorTestSupport

/// The colors of one region of a capture: its background and its ink, for
/// the contrast checks of the text that a real window shows (^zbcys18).
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

  /// Reads the colors of `region` of `image`.
  ///
  /// - Parameters:
  ///   - image: The capture.
  ///   - region: The region, in points from the top leading corner of the
  ///     image.
  /// - Returns: `nil` when no pixel of the image is in `region`.
  /// - Throws: A `CapturedImageError` when the region cannot be read.
  init?(of image: CapturedImage, in region: CGRect) throws {
    guard let crop = try Self.crop(of: image, in: region) else { return nil }
    let colors = try Self.colors(of: crop)
    let counts = Dictionary(colors.map { ($0, 1) }, uniquingKeysWith: +)
    guard let background = counts.max(by: { $0.value < $1.value })?.key.color,
      let ink = colors.map(\.color).max(by: { $0.contrast(with: background) < $1.contrast(with: background) })
    else { return nil }
    self.background = background
    self.ink = ink
  }

  /// Whether a pixel of `region` of `image` shows `color`, as
  /// `CapturedImage.contains(_:)` reads a pixel.
  ///
  /// - Parameters:
  ///   - color: The color to find, with no dynamic part, such as a resolved
  ///     theme color.
  ///   - region: The region, in points from the top leading corner of the
  ///     image.
  ///   - image: The capture.
  /// - Returns: `true` when at least one pixel of `region` shows `color`.
  /// - Throws: A `CapturedImageError` when the region cannot be read.
  static func contains(_ color: CGColor, in region: CGRect, of image: CapturedImage) throws -> Bool {
    try crop(of: image, in: region)?.contains(color) ?? false
  }

  /// The frame of each column of the pixels of `region` of `image`.
  ///
  /// The columns hold the pixels that ``init(of:in:)`` reads: each frame is
  /// one pixel wide, and as high as the pixels of `region`.
  ///
  /// - Parameters:
  ///   - image: The capture.
  ///   - region: The region, in points from the top leading corner of the
  ///     image.
  /// - Returns: The frames, in points from the top leading corner of the
  ///   image, from the leading column to the trailing column. Empty when no
  ///   pixel of the image is in `region`.
  static func columns(of image: CapturedImage, in region: CGRect) -> [CGRect] {
    guard let pixelRegion = pixelRegion(of: image, in: region) else { return [] }
    let toPoints = CGAffineTransform(scaleX: 1 / CaptureGeometry.scale, y: 1 / CaptureGeometry.scale)
    return (Int(pixelRegion.minX)..<Int(pixelRegion.maxX)).map { column in
      CGRect(x: CGFloat(column), y: pixelRegion.minY, width: 1, height: pixelRegion.height).applying(toPoints)
    }
  }

  /// The pixels of `image` in `region`, as an image of their own.
  ///
  /// - Parameters:
  ///   - image: The capture.
  ///   - region: The region, in points from the top leading corner.
  /// - Returns: The crop, or `nil` when the region holds no pixel of the
  ///   image.
  /// - Throws: A `CapturedImageError` when the crop cannot be made.
  private static func crop(of image: CapturedImage, in region: CGRect) throws -> CapturedImage? {
    try pixelRegion(of: image, in: region).map { try image.cropped(to: $0) }
  }

  /// The color of each pixel of `crop`, column by column.
  ///
  /// - Parameter crop: The pixels of a region.
  /// - Returns: The colors.
  /// - Throws: A `CapturedImageError` when a column cannot be read.
  private static func colors(of crop: CapturedImage) throws -> [PixelColor] {
    try (0..<crop.pixelWidth).flatMap { column in
      try crop.pixelColumn(at: column).map(PixelColor.init(bytes:))
    }
  }

  /// `region` in whole pixels of `image`: each pixel whose area meets
  /// `region`, within the image.
  ///
  /// - Parameters:
  ///   - image: The capture.
  ///   - region: The region, in points from the top leading corner.
  /// - Returns: The region in pixels from the top leading corner, or `nil`
  ///   when it holds no pixel of the image.
  private static func pixelRegion(of image: CapturedImage, in region: CGRect) -> CGRect? {
    let bounds = CGRect(x: 0, y: 0, width: image.pixelWidth, height: image.pixelHeight)
    let pixelRegion = CaptureGeometry.pixels(of: region).intersection(bounds)
    return pixelRegion.isEmpty ? nil : pixelRegion
  }
}

/// The color of one opaque pixel of a capture, hashable so that
/// ``RegionColors`` can count the pixels of each color.
private struct PixelColor: Hashable {
  /// The place of each color channel in the bytes of a pixel.
  private enum Channel: Int {
    /// The red channel, first.
    case red
    /// The green channel, second.
    case green
    /// The blue channel, third.
    case blue
  }

  /// The largest value of one byte of a pixel.
  private static let byteMaximum = Double(UInt8.max)

  /// Red, green, blue and alpha, one byte each, as a capture holds them.
  let bytes: [UInt8]

  /// The color as an opaque ``ResolvedColor``. A capture is flattened over
  /// its background, so each pixel is opaque.
  var color: ResolvedColor {
    ResolvedColor(
      red: component(.red), green: component(.green), blue: component(.blue), alpha: 1)
  }

  /// One channel of the pixel, from 0 to 1.
  ///
  /// - Parameter channel: The channel.
  /// - Returns: The value.
  private func component(_ channel: Channel) -> Double {
    Double(bytes[channel.rawValue]) / Self.byteMaximum
  }
}
