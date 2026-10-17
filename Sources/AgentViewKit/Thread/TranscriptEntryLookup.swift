import FoundationModelsACPClient

extension [TranscriptEntry] {
  /// The entry of the transcript with an id.
  ///
  /// - Parameter id: The identity of an entry.
  /// - Returns: The first entry with `id`, or `nil` when the transcript has
  ///   no entry with `id`.
  func entry(withID id: TranscriptEntry.ID) -> TranscriptEntry? {
    first { $0.id == id }
  }

  /// The position of the entry of the transcript with a row key.
  ///
  /// - Parameter key: The row key of an entry. See
  ///   ``FoundationModelsACPClient/TranscriptEntry/ID/rowKey``.
  /// - Returns: The position of the first entry with `key`, or `nil` when the
  ///   transcript has no entry with `key`.
  func position(ofRowKey key: String) -> Int? {
    firstIndex { $0.rowKey == key }
  }
}
