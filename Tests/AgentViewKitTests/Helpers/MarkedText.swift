/// The text that each UTF-8 byte range of `ranges` covers in `text`.
///
/// The find mark tests use this function to read the marked words of an
/// EditorKit label mark or of an EditorKit mark decoration.
///
/// - Parameters:
///   - ranges: The half-open ranges of UTF-8 offsets in `text`, in order.
///   - text: The text that the ranges point into.
/// - Returns: The text of each range, in the order of `ranges`.
func markedText(of ranges: [Range<Int>], in text: String) -> [String] {
  let utf8 = Array(text.utf8)
  return ranges.map { String(decoding: utf8[$0], as: UTF8.self) }
}
