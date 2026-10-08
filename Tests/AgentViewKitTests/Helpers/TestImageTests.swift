import AppKit
import Foundation
import Testing

/// The tests of the shared test image.
struct TestImageTests {
  /// The first eight bytes of each PNG file.
  static let pngSignature = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

  @Test func thePNGDataIsAPNGImageOfTheTestSide() throws {
    let data = try TestImage.makePNGData()

    #expect(data.starts(with: Self.pngSignature))
    let bitmap = try #require(NSBitmapImageRep(data: data))
    #expect(bitmap.pixelsWide == TestImage.side)
    #expect(bitmap.pixelsHigh == TestImage.side)
  }
}
