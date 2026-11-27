import AppKit
import SwiftUI

/// The difference of two bitmaps of a row (card ^9ync5h3): the mean
/// difference of a color component, and the part of the pixels with a large
/// difference, at the vertical shift of the second bitmap that gives the
/// smallest difference.
///
/// Each bitmap is drawn over one opaque background into a buffer of one
/// layout, so a clear pixel and a pixel of the background color are equal.
/// Two bitmaps of other pixel sizes are not compared: the compare throws.
/// The compare tries each vertical shift up to a tolerance, as the line
/// bands of ``InkBands`` match within a tolerance, and it reads the pixel
/// rows that both bitmaps hold at that shift.
struct RowPixelDifference: CustomStringConvertible {
  /// The mean absolute difference of a color component, from 0 to 255.
  let mean: Double

  /// The part of the pixels with a component difference of more than
  /// ``largeStep``.
  let largePart: Double

  /// The vertical shift of the second bitmap, in pixels, that gives the
  /// difference: a positive shift reads the second bitmap that many rows
  /// lower.
  let rowShift: Int

  /// The component difference of a pixel that counts as large: a quarter of
  /// the range.
  static let largeStep = 64

  /// The bytes of one pixel of the compare buffer: red, green, blue, alpha.
  private static let bytesPerPixel = 4

  /// The bits of one component of the compare buffer.
  private static let bitsPerComponent = 8

  var description: String { "mean \(mean), large part \(largePart), row shift \(rowShift)" }

  /// Tells if the difference is in the limits.
  ///
  /// - Parameters:
  ///   - meanLimit: The largest mean difference of a component.
  ///   - largePartLimit: The largest part of the pixels with a large
  ///     difference.
  /// - Returns: `true` when both numbers are in their limits.
  func isWithin(meanLimit: Double, largePartLimit: Double) -> Bool {
    mean <= meanLimit && largePart <= largePartLimit
  }

  /// The opaque background of the compare in `colorScheme`: white in light,
  /// black in dark.
  ///
  /// - Parameter colorScheme: The appearance of the bitmaps.
  /// - Returns: The color.
  static func background(of colorScheme: ColorScheme) -> CGColor {
    colorScheme == .dark ? CGColor(gray: .zero, alpha: 1) : CGColor(gray: 1, alpha: 1)
  }

  /// The smallest difference of `first` and `second`, each drawn over
  /// `background`, over each vertical shift of `second` up to
  /// `rowTolerance` pixels.
  ///
  /// - Parameters:
  ///   - first: One bitmap.
  ///   - second: The other bitmap.
  ///   - background: The opaque background.
  ///   - rowTolerance: The largest vertical shift, in pixels.
  /// - Returns: The difference with the fewest large pixels.
  static func between(
    _ first: NSBitmapImageRep, and second: NSBitmapImageRep, over background: CGColor, rowTolerance: Int
  ) throws -> RowPixelDifference {
    guard first.pixelsWide == second.pixelsWide, first.pixelsHigh == second.pixelsHigh else {
      throw RowPixelError.sizeMismatch(
        first: CGSize(width: first.pixelsWide, height: first.pixelsHigh),
        second: CGSize(width: second.pixelsWide, height: second.pixelsHigh))
    }
    let one = try pixels(of: first, over: background)
    let other = try pixels(of: second, over: background)
    let rowBytes = first.pixelsWide * bytesPerPixel
    let differences = (-rowTolerance...rowTolerance).map { shift in
      difference(between: one, and: other, rowBytes: rowBytes, rowShift: shift)
    }
    return differences.min { $0.largePart < $1.largePart } ?? difference(
      between: one, and: other, rowBytes: rowBytes, rowShift: .zero)
  }

  /// The difference of two pixel buffers of one layout, with the second
  /// buffer read `rowShift` rows lower, over the rows that both hold.
  ///
  /// - Parameters:
  ///   - one: The components of the first bitmap, from the top row.
  ///   - other: The components of the second bitmap, from the top row.
  ///   - rowBytes: The bytes of one pixel row.
  ///   - rowShift: The vertical shift of the second bitmap, in pixels.
  /// - Returns: The difference.
  private static func difference(
    between one: [UInt8], and other: [UInt8], rowBytes: Int, rowShift: Int
  ) -> RowPixelDifference {
    let shiftBytes = rowShift * rowBytes
    let range = max(.zero, -shiftBytes)..<min(one.count, one.count - shiftBytes)
    let steps = range.map { abs(Int(one[$0]) - Int(other[$0 + shiftBytes])) }
    let pixelCount = max(steps.count / bytesPerPixel, 1)
    let large = stride(from: 0, to: steps.count, by: bytesPerPixel).filter { pixel in
      steps[pixel..<(pixel + bytesPerPixel)].contains { $0 > largeStep }
    }.count
    return RowPixelDifference(
      mean: Double(steps.reduce(0, +)) / Double(max(steps.count, 1)),
      largePart: Double(large) / Double(pixelCount), rowShift: rowShift)
  }

  /// The pixels of `bitmap` drawn over `background` into a buffer of its
  /// pixel size.
  ///
  /// - Parameters:
  ///   - bitmap: The bitmap.
  ///   - background: The opaque background.
  /// - Returns: The components of the pixels, from the top row.
  private static func pixels(of bitmap: NSBitmapImageRep, over background: CGColor) throws -> [UInt8] {
    guard let image = bitmap.cgImage else { throw RowPixelError.noImage }
    var bytes = [UInt8](repeating: .zero, count: image.width * image.height * bytesPerPixel)
    try bytes.withUnsafeMutableBytes { buffer in
      guard let space = CGColorSpace(name: CGColorSpace.sRGB),
        let context = CGContext(
          data: buffer.baseAddress, width: image.width, height: image.height,
          bitsPerComponent: bitsPerComponent, bytesPerRow: image.width * bytesPerPixel, space: space,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      else { throw RowPixelError.noContext }
      let rect = CGRect(x: .zero, y: .zero, width: image.width, height: image.height)
      context.setFillColor(background)
      context.fill(rect)
      context.draw(image, in: rect)
    }
    return bytes
  }
}

/// The failure of a ``RowPixelDifference`` compare.
enum RowPixelError: Error {
  /// The bitmap gave no image.
  case noImage

  /// Core Graphics made no bitmap context.
  case noContext

  /// The two bitmaps have other pixel sizes.
  case sizeMismatch(first: CGSize, second: CGSize)
}
