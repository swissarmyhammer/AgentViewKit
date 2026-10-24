import Foundation
import ImageIO
import Vision

/// The errors of ``SnapshotText``.
public enum SnapshotTextError: Error, Equatable {
  /// ImageIO cannot read the image file.
  case unreadableImage(path: String)
}

/// The text check of a recorded snapshot image (^zg9tysk).
///
/// Text that a view draws over other text, such as a banner over a row of
/// the transcript, cannot be read in the image: optical character
/// recognition reads mixed letters there, such as "Assistagtnt" for
/// "Assistant" under "tests-agent". A test gives the text that the view of
/// the image shows, and checks that the recognition of the image finds each
/// word of it, with ``missingWords(of:in:)``.
///
/// The check compares words, and not lines, because the recognition reads
/// one line of the image as one result, and a long text of the view wraps
/// to more than one line.
public enum SnapshotText {
  /// The factor by which ``recognizedWords(inImageAt:)`` scales the image up
  /// before the recognition.
  ///
  /// At the scale of a snapshot image, the recognizer reads a short word
  /// alone on a line as digits, such as "109" for "log", with every option of
  /// the request. At two times that scale, it reads the word.
  static let upscale = 2

  /// Reads the words in the image file at `url` with the Vision text
  /// recognizer, at the accurate level, with language correction, after
  /// the image is scaled up by ``upscale``.
  ///
  /// - Parameter url: The file URL of a PNG image.
  /// - Returns: The words of each recognized line, in the form of
  ///   ``words(of:)``.
  /// - Throws: ``SnapshotTextError/unreadableImage(path:)`` when ImageIO
  ///   cannot read or scale the image, or the error of the recognizer.
  public static func recognizedWords(inImageAt url: URL) throws -> [String] {
    let path = url.path(percentEncoded: false)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
      let scaled = scaledUp(image)
    else {
      throw SnapshotTextError.unreadableImage(path: path)
    }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    try VNImageRequestHandler(cgImage: scaled).perform([request])
    let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    return lines.flatMap(words(of:))
  }

  /// `image` scaled up by ``upscale``, with high-quality interpolation.
  ///
  /// - Parameter image: The image.
  /// - Returns: The scaled image, or `nil` when Core Graphics makes no
  ///   context or no image.
  static func scaledUp(_ image: CGImage) -> CGImage? {
    let width = image.width * upscale
    let height = image.height * upscale
    guard
      let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: image.bitsPerComponent, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()
  }

  /// The words of `text`: each run of letters and digits, in lowercase.
  ///
  /// Punctuation and symbols separate words and are not part of a word, so
  /// "sign-in" gives "sign" and "in".
  ///
  /// - Parameter text: The text.
  /// - Returns: The words, in the order of `text`.
  public static func words(of text: String) -> [String] {
    text.lowercased()
      .split { !($0.isLetter || $0.isNumber) }
      .map(String.init)
  }

  /// The words of `expected` that `recognized` does not hold, counting each
  /// repeat of a word.
  ///
  /// A word that `expected` holds two times must be in `recognized` at
  /// least two times.
  ///
  /// - Parameters:
  ///   - expected: The words that the image must show.
  ///   - recognized: The words that the recognizer read in the image.
  /// - Returns: Each missing word one time for each missing repeat, sorted.
  public static func missingWords(of expected: [String], in recognized: [String]) -> [String] {
    let found = Dictionary(recognized.map { ($0, 1) }, uniquingKeysWith: +)
    let wanted = Dictionary(expected.map { ($0, 1) }, uniquingKeysWith: +)
    return wanted.keys.sorted().flatMap { word in
      Array(repeating: word, count: max(0, (wanted[word] ?? 0) - (found[word] ?? 0)))
    }
  }
}
