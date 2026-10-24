import AgentViewKitTestSupport
import SwiftUI
import Testing

/// Tests for ``SnapshotText``, the text check of a recorded snapshot image
/// (^zg9tysk).
///
/// The recognition tests draw a short text with `ImageRenderer`, one time
/// alone and one time under a second text, write the image as a PNG file, and
/// read it back with the recognizer.
@Suite @MainActor struct SnapshotTextTests {
  /// The text that each recognition test draws.
  static let text = "The response stopped because of a failure"

  /// The text that the overlap test draws over ``text``.
  static let coveringText = "row that has no email address"

  /// The size of each drawn image, in points.
  static let size = CGSize(width: 420, height: 80)

  /// The size of the font of each drawn text, in points.
  static let fontSize: CGFloat = 17

  /// The vertical offset of ``coveringText`` from ``text``, in points: less
  /// than one line, so the glyphs of the two lines mix.
  static let overlapOffset: CGFloat = 4

  /// One line of `text` in black on white.
  ///
  /// - Parameter text: The text.
  /// - Returns: The line.
  static func line(_ text: String) -> some View {
    Text(verbatim: text).font(.system(size: fontSize)).foregroundStyle(.black)
  }

  /// Draws `view` over a white background, writes the image as a PNG file
  /// in `directory`, and reads its words.
  ///
  /// - Parameters:
  ///   - view: The view to draw.
  ///   - directory: The folder of the image file.
  /// - Returns: The recognized words.
  /// - Throws: An issue when the view gives no pixels, or the error of the
  ///   file write or of the recognizer.
  static func recognizedWords(of view: some View, in directory: TemporaryDirectory) throws -> [String] {
    let drawn = ZStack {
      Color.white
      view
    }
    let pixels = try #require(RenderedPixels(rendering: drawn, size: size))
    let file = try directory.file(named: "text.png", contents: try #require(pixels.pngData()))
    return try SnapshotText.recognizedWords(inImageAt: file)
  }

  @Test func theWordsOfATextAreItsLowercaseRunsOfLettersAndDigits() {
    #expect(SnapshotText.words(of: "Error -32603: Sign-in page.") == ["error", "32603", "sign", "in", "page"])
  }

  @Test func aWordThatTheImageDoesNotShowIsMissing() {
    let missing = SnapshotText.missingWords(of: ["sign", "in", "page"], in: ["sign", "page"])

    #expect(missing == ["in"])
  }

  @Test func eachRepeatOfAWordMustBeInTheImage() {
    let missing = SnapshotText.missingWords(of: ["the", "agent", "the"], in: ["the", "agent"])

    #expect(missing == ["the"])
  }

  @Test func theRecognizerReadsEachWordOfAClearText() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }

    let recognized = try Self.recognizedWords(of: Self.line(Self.text), in: directory)

    #expect(SnapshotText.missingWords(of: SnapshotText.words(of: Self.text), in: recognized).isEmpty)
  }

  @Test func theRecognizerMissesWordsOfATextUnderOtherText() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let overlap = ZStack {
      Self.line(Self.text)
      Self.line(Self.coveringText).offset(y: Self.overlapOffset)
    }

    let recognized = try Self.recognizedWords(of: overlap, in: directory)

    #expect(!SnapshotText.missingWords(of: SnapshotText.words(of: Self.text), in: recognized).isEmpty)
  }

  @Test func anUnreadableImageThrows() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let file = try directory.file(named: "text.png", contents: Data("not an image".utf8))

    #expect(throws: SnapshotTextError.unreadableImage(path: file.path(percentEncoded: false))) {
      try SnapshotText.recognizedWords(inImageAt: file)
    }
  }
}
