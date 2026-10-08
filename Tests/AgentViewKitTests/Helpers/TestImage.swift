import AppKit
import Foundation
import Testing

/// The small PNG image of the tests.
///
/// Each test that needs real image bytes makes them with ``makePNGData()``,
/// and keeps no copy of its own.
enum TestImage {
  /// The width and the height of the image, in pixels.
  static let side = 4

  /// The number of bits of each sample of the image.
  static let bitsPerSample = 8

  /// The number of samples of each pixel of the image: red, green, blue, and
  /// alpha.
  static let samplesPerPixel = 4

  /// The value that tells AppKit to calculate the row length and the pixel
  /// length from the other values.
  static let calculatedLength = 0

  /// Makes the bytes of the PNG image.
  ///
  /// - Returns: The PNG data.
  /// - Throws: An error when AppKit cannot make the image.
  static func makePNGData() throws -> Data {
    let bitmap = try #require(
      NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: bitsPerSample,
        samplesPerPixel: samplesPerPixel, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: calculatedLength, bitsPerPixel: calculatedLength))
    return try #require(bitmap.representation(using: .png, properties: [:]))
  }
}
