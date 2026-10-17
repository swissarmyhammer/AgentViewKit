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
}
