import EditorTestSupport
import SwiftUI
import Testing

/// Tests for the pixel reads of ``RegionColors``, over a capture of
/// ``halves`` in a real window: ``drawn`` in the leading half and
/// ``notDrawn`` in the trailing half.
@Suite(.serialized, .hostedSerially) @MainActor struct RegionColorsTests {
  /// The size of the capture, in points.
  static let size = CGSize(width: 40, height: 20)

  /// The sRGB channels of the color of the leading half.
  static let drawnChannels = ResolvedColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1)

  /// The sRGB channels of the color of the trailing half: white.
  static let notDrawnChannels = ResolvedColor(red: 1, green: 1, blue: 1, alpha: 1)

  /// The color of the leading half.
  static let drawn = Color(red: drawnChannels.red, green: drawnChannels.green, blue: drawnChannels.blue)

  /// The color of the trailing half.
  static let notDrawn = Color(red: notDrawnChannels.red, green: notDrawnChannels.green, blue: notDrawnChannels.blue)

  /// The largest difference of one channel of a pixel from its color, from
  /// 0 to 1: the rounding of the color matching of the window server
  /// (`CapturedImage.colorTolerance`, in levels of a byte).
  static var channelTolerance: Double { Double(CapturedImage.colorTolerance) / Double(UInt8.max) }

  /// Whether `color` has the channels of `expected`, each within
  /// ``channelTolerance``.
  ///
  /// - Parameters:
  ///   - color: The color that a capture shows.
  ///   - expected: The color that the view draws.
  /// - Returns: `true` when each channel is close.
  static func isClose(_ color: ResolvedColor, to expected: ResolvedColor) -> Bool {
    [(color.red, expected.red), (color.green, expected.green), (color.blue, expected.blue)]
      .allSatisfy { abs($0 - $1) <= channelTolerance }
  }

  /// The leading half of the capture, in points.
  static let leadingHalf = CGRect(x: 0, y: 0, width: size.width / 2, height: size.height)

  /// The trailing half of the capture, in points.
  static let trailingHalf = leadingHalf.offsetBy(dx: leadingHalf.width, dy: 0)

  /// The size of one pixel of a capture, in points.
  static var onePixel: CGFloat { 1 / CaptureGeometry.scale }

  /// The view of the capture: ``drawn`` beside ``notDrawn``.
  static var halves: some View {
    HStack(spacing: 0) {
      drawn
      notDrawn
    }
  }

  /// The capture of ``halves``.
  ///
  /// - Returns: The image.
  /// - Throws: A `WindowCaptureError`, or the error of ScreenCaptureKit.
  static func capture() async throws -> CapturedImage {
    try await CapturedImage(showing: halves, size: size)
  }

  @Test func aRegionContainsTheColorThatItsPixelsHave() async throws {
    let image = try await Self.capture()

    #expect(try RegionColors.contains(CaptureGeometry.cgColor(of: Self.drawn), in: Self.leadingHalf, of: image))
  }

  @Test func aRegionDoesNotContainTheColorOfThePixelsOutsideIt() async throws {
    let image = try await Self.capture()

    #expect(try RegionColors.contains(CaptureGeometry.cgColor(of: Self.notDrawn), in: Self.trailingHalf, of: image))
    #expect(try !RegionColors.contains(CaptureGeometry.cgColor(of: Self.drawn), in: Self.trailingHalf, of: image))
  }

  @Test func theBackgroundIsTheMostCommonColorAndTheInkTheColorOfTheMostContrast() async throws {
    let image = try await Self.capture()
    let quarterOfTheTrailingHalf = CGRect(
      x: Self.trailingHalf.minX, y: 0, width: Self.trailingHalf.width / 2, height: Self.size.height)
    let mostlyDrawn = Self.leadingHalf.union(quarterOfTheTrailingHalf)

    let colors = try #require(try RegionColors(of: image, in: mostlyDrawn))

    #expect(Self.isClose(colors.background, to: Self.drawnChannels), "\(colors)")
    #expect(Self.isClose(colors.ink, to: Self.notDrawnChannels), "\(colors)")
  }

  @Test func theColumnsOfARegionAreOnePixelWideAndCoverTheRegion() async throws {
    let image = try await Self.capture()
    let region = Self.leadingHalf

    let columns = RegionColors.columns(of: image, in: region)

    #expect(columns.count == Int(region.width * CaptureGeometry.scale))
    #expect(columns.allSatisfy { $0.width == Self.onePixel && $0.height == region.height })
    #expect(columns.reduce(CGRect.null) { $0.union($1) } == region)
  }

  @Test func theColumnsOfARegionOutsideTheImageAreNone() async throws {
    let image = try await Self.capture()
    let outside = Self.leadingHalf.offsetBy(dx: 0, dy: Self.size.height)

    #expect(RegionColors.columns(of: image, in: outside).isEmpty)
  }
}
