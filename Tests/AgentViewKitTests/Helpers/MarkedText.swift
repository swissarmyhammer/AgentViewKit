/// The helper that reads the marked text of the find mark tests.
///
/// The find mark tests use this type to read the marked words of an
/// EditorKit label mark or of an EditorKit mark decoration.
enum MarkedText {
  /// The text that each UTF-8 byte range of `ranges` covers in `text`.
  ///
  /// - Parameters:
  ///   - ranges: The half-open ranges of UTF-8 offsets in `text`, in order.
  ///   - text: The text that the ranges point into.
  /// - Returns: The text of each range, in the order of `ranges`.
  static func of(_ ranges: [Range<Int>], in text: String) -> [String] {
    let utf8 = Array(text.utf8)
    return ranges.map { String(decoding: utf8[$0], as: UTF8.self) }
  }
}
