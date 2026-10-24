@testable import AgentViewKit
import AgentViewKitTestSupport
import SwiftUI
import Testing

/// Checks that the recorded `bottom-bar-buttons` images of
/// ``HostedSnapshotTests`` hold no text over other text (^zg9tysk).
///
/// A banner of a bar over a row of the transcript mixes the glyphs of the
/// two texts, and the recognizer of ``SnapshotText`` then misses words of
/// them. The test mounts the view of the image, takes the text of each
/// static text element of its accessibility tree, and expects the
/// recognizer to read each word of that text in the recorded image of each
/// ``SnapshotVariant``.
@Suite(.serialized, .hostedSerially) @MainActor struct HostedSnapshotTextTests {
  /// The accessibility role of a static text element.
  static let staticTextRole = "AXStaticText"

  /// The words of each static text element of `view`, at `size`.
  ///
  /// - Parameters:
  ///   - view: The view of the image.
  ///   - size: The size of the image, in points.
  /// - Returns: The words, in the form of ``SnapshotText/words(of:)``.
  static func shownWords(of view: some View, size: CGSize) -> [String] {
    let harness = HostedViewHarness(view, size: size)
    defer { harness.close() }
    harness.render()
    return harness.accessibilityElements()
      .filter { $0.role == staticTextRole }
      .compactMap(\.label)
      .flatMap(SnapshotText.words(of:))
  }

  @Test(arguments: SnapshotVariant.allCases)
  func eachWordOfTheBottomBarButtonsImageIsReadable(variant: SnapshotVariant) throws {
    let expected = Self.shownWords(of: SnapshotFixtures.bottomBarThread, size: SnapshotFixtures.threadSize)
    let image = try SnapshotStore(suite: "HostedSnapshotTests")
      .referenceURL(named: variant.name(of: "bottom-bar-buttons"))

    let recognized = try SnapshotText.recognizedWords(inImageAt: image)

    #expect(!expected.isEmpty)
    #expect(SnapshotText.missingWords(of: expected, in: recognized).isEmpty, "read \(recognized)")
  }
}
