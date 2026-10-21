import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// The PNG form of ``RenderedPixels``, and the image of the difference of two
/// renders. The snapshot images of the views use them (AVK-13).
extension RenderedPixels {
  /// The bytes of the magenta that a difference image gives to each pixel
  /// that changed: red, green, blue and alpha. No view of the kit draws this
  /// color.
  private static let differenceMarkBytes: [UInt8] = [.max, .min, .max, .max]

  /// The part of the color of a pixel that a difference image keeps for a
  /// pixel that did not change. The rest of the color is white, so that the
  /// marks of the pixels that changed are easy to see.
  private static let unchangedPixelStrength = 0.3

  /// Whether this difference image marks the pixel at `point` as a pixel
  /// that changed (``difference(from:tolerance:)``).
  ///
  /// - Parameter point: The point to read, in points from the top leading
  ///   corner of the view.
  /// - Returns: `true` when the pixel has the mark color. `false` when
  ///   `point` is not in the image.
  public func marksAChange(at point: CGPoint) -> Bool {
    guard let offset = offset(of: point) else { return false }
    return Array(bytes[offset..<offset + Self.bytesPerPixel]) == Self.differenceMarkBytes
  }

  /// Reads the pixels of a PNG image.
  ///
  /// - Parameters:
  ///   - data: The bytes of the PNG file.
  ///   - scale: The number of pixels in the image for each point.
  /// - Returns: `nil` when ImageIO cannot read the image or the pixels
  ///   cannot be read.
  public init?(pngData data: Data, scale: CGFloat) {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { return nil }
    self.init(image: image, scale: scale)
  }

  /// The pixels as a PNG image in sRGB, with one image pixel for each pixel.
  ///
  /// - Returns: The bytes of the PNG file, or `nil` when Core Graphics or
  ///   ImageIO cannot make it.
  public func pngData() -> Data? {
    guard let image = cgImage() else { return nil }
    let data = NSMutableData()
    guard
      let destination = CGImageDestinationCreateWithData(
        data as CFMutableData, UTType.png.identifier as CFString, 1, nil)
    else { return nil }
    CGImageDestinationAddImage(destination, image, nil)
    return CGImageDestinationFinalize(destination) ? data as Data : nil
  }

  /// An image that shows where these pixels and `other` are different.
  ///
  /// Each pixel whose bytes are all in `tolerance` of the bytes of the pixel
  /// of `other` keeps a pale form of its color. Each other pixel is magenta
  /// (``marksAChange(at:)``). The test is the test of
  /// ``isClose(to:tolerance:)``, so the image marks each pixel that makes
  /// that method give `false`.
  ///
  /// - Parameters:
  ///   - other: The pixels to compare with, for example a reference image.
  ///   - tolerance: The largest difference of one component, from 0 to 1.
  /// - Returns: The difference image, or `nil` when the two images do not
  ///   have the same size and scale.
  public func difference(from other: RenderedPixels, tolerance: Double = defaultTolerance)
    -> RenderedPixels?
  {
    guard width == other.width, height == other.height, scale == other.scale else { return nil }
    let levels = tolerance * Self.componentMaximum
    var marked = bytes
    for offset in pixelOffsets {
      let pixel = offset..<offset + Self.bytesPerPixel
      marked.replaceSubrange(
        pixel,
        with: self.pixel(atOffset: offset, isCloseTo: other, levels: levels)
          ? Self.paleBytes(of: bytes[pixel]) : Self.differenceMarkBytes)
    }
    return RenderedPixels(bytes: marked, width: width, height: height, scale: scale)
  }

  /// The bytes of an opaque pixel that shows a pale form of a color.
  ///
  /// - Parameter pixel: The red, green, blue and alpha bytes of the color,
  ///   with the alpha multiplied in.
  /// - Returns: The bytes of the pixel over white, faded toward white.
  private static func paleBytes(of pixel: ArraySlice<UInt8>) -> [UInt8] {
    let transparency = componentMaximum - Double(pixel[pixel.endIndex - 1])
    let color = pixel.dropLast().map { byte in
      let overWhite = Double(byte) + transparency
      return UInt8((componentMaximum - (componentMaximum - overWhite) * unchangedPixelStrength).rounded())
    }
    return color + [.max]
  }

  /// The pixels as a Core Graphics image in sRGB.
  ///
  /// - Returns: The image, or `nil` when Core Graphics cannot make it.
  private func cgImage() -> CGImage? {
    let bytesPerRow = width * Self.bytesPerPixel
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
      let provider = CGDataProvider(data: Data(bytes) as CFData)
    else { return nil }
    return CGImage(
      width: width, height: height, bitsPerComponent: Self.bitsPerComponent,
      bitsPerPixel: Self.bitsPerComponent * Self.bytesPerPixel, bytesPerRow: bytesPerRow,
      space: space, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
      provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
  }
}
