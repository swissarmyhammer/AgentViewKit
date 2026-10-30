@testable import AgentViewKit
import EditorTestSupport
import Foundation
import SwiftUI
import Testing

/// Checks that the recorded `bottom-bar-buttons` images of
/// ``HostedSnapshotTests`` hold no text over other text (^zg9tysk).
///
/// A banner of a bar over a row of the transcript mixes the glyphs of the
/// two texts, and the text recognizer of EditorKit (`CapturedImage`
/// `missingWords(of:)`) then misses words of them. The test mounts the view
/// of the image, takes the text of each static text element of its
/// accessibility tree, and expects the recognizer to read each word of that
/// text in the recorded image of each look.
@Suite(.serialized, .hostedSerially) @MainActor struct HostedSnapshotTextTests {
  /// The accessibility role of a static text element.
  static let staticTextRole = "AXStaticText"

  /// The text of each static text element of `view`, at `size`, one element
  /// after the other.
  ///
  /// - Parameters:
  ///   - view: The view of the image.
  ///   - size: The size of the image, in points.
  /// - Returns: The labels of the elements, joined by spaces.
  static func shownText(of view: some View, size: CGSize) -> String {
    let harness = HostedViewHarness(view, size: size)
    defer { harness.close() }
    harness.render()
    return harness.accessibilityElements()
      .filter { $0.role == staticTextRole }
      .compactMap(\.label)
      .joined(separator: " ")
  }

  @Test(arguments: ReviewAppearance.allCases)
  func eachWordOfTheBottomBarButtonsImageIsReadable(look: ReviewAppearance) async throws {
    let expected = Self.shownText(of: SnapshotFixtures.bottomBarThread, size: SnapshotFixtures.threadSize)
    let image = try await CaptureMount.capture(
      SnapshotFixtures.bottomBarThread, size: SnapshotFixtures.threadSize, appearance: look)

    let missing = try image.missingWords(of: expected)
    let recognized = try image.recognizedWords()

    #expect(!expected.isEmpty)
    #expect(missing.isEmpty, "missing \(missing), read \(recognized)")
  }
}
