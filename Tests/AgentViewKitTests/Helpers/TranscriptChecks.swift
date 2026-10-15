import FoundationModelsACPClient

/// Checks on the transcript of a session model. The hosted suites that wait
/// for an error entry, and then check it, use them.
enum TranscriptChecks {
  /// Tells whether the transcript of a session model has an error entry.
  ///
  /// - Parameter model: The session model.
  /// - Returns: `true` when an entry of `transcript` is `.error`.
  static func hasErrorEntry(_ model: SessionModel) -> Bool {
    model.transcript.contains { entry in
      if case .error = entry { true } else { false }
    }
  }
}
