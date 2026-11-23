import FoundationModelsACPClient
import Observation

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

/// The position of each row key of the transcript of a session model (task
/// ^q1fy0n2, #scroll-perf).
///
/// The list reports its rows in view for each scroll step, and the view
/// finds the position of each row of the report. The linear lookup
/// (`position(ofRowKey:)`) reads each entry before the hit, and it makes the
/// row key of each one. The index makes all row keys one time, and then a
/// lookup reads one dictionary.
///
/// The index builds its dictionary at the first lookup. It then tracks the
/// `transcript` of the session model with `withObservationTracking`. An
/// append, a removal or a replacement of the transcript marks the
/// dictionary as stale, and the next lookup builds it again. A streamed
/// chunk changes an entry object and not the transcript, so it does not
/// make a build. A lookup in a different session model also builds the
/// dictionary again.
///
/// A view keeps the index in its state, as it keeps a ``ParseMemo``. The
/// index is not observable, so a build does not make the view evaluate its
/// body again.
///
/// In a debug build, each build adds one count to the
/// ``BodyEvaluationCounter`` key of the session model
/// (``counterKey(for:)``). Thus a test can count the builds.
@MainActor final class TranscriptRowIndex {
  /// The prefix of the counter key of the builds.
  private static let counterPrefix = "transcript-row-index-"

  /// The session model of the last build, or `nil` before the first build
  /// and after the release of the model.
  private weak var session: SessionModel?

  /// The position of the first entry with each row key, at the last build,
  /// or `nil` when the transcript changed after the last build.
  private var positions: [String: Int]?

  /// The position of the entry with a row key, in the transcript of a
  /// session model.
  ///
  /// - Parameters:
  ///   - key: The row key of an entry. See
  ///     ``FoundationModelsACPClient/TranscriptEntry/ID/rowKey``.
  ///   - session: The session model whose transcript has the entry.
  /// - Returns: The position of the first entry with `key`, or `nil` when
  ///   the transcript has no entry with `key`. The value is equal to the
  ///   value of `position(ofRowKey:)` on the transcript.
  func position(ofRowKey key: String, in session: SessionModel) -> Int? {
    positions(in: session)[key]
  }

  /// The ``BodyEvaluationCounter`` key of the builds of the index for a
  /// session model.
  ///
  /// - Parameter session: The session model.
  /// - Returns: The key.
  static func counterKey(for session: SessionModel) -> String {
    BodyEvaluationKey.make(prefix: counterPrefix, id: String(describing: ObjectIdentifier(session)))
  }

  /// The dictionary of the transcript of a session model. The function
  /// builds the dictionary when it is stale, or when it is for a different
  /// session model.
  ///
  /// - Parameter session: The session model.
  /// - Returns: The position of each row key.
  private func positions(in session: SessionModel) -> [String: Int] {
    if let positions, self.session === session {
      return positions
    }
    let built = build(for: session)
    self.session = session
    positions = built
    return built
  }

  /// Builds the dictionary of the transcript of a session model, and starts
  /// to track the transcript.
  ///
  /// The change callback of the tracking runs in the `willSet` of the
  /// transcript, before the next lookup can run. The session model is
  /// `@MainActor`, so the callback runs on the main actor.
  ///
  /// - Parameter session: The session model.
  /// - Returns: The position of the first entry with each row key.
  private func build(for session: SessionModel) -> [String: Int] {
    #if DEBUG
      BodyEvaluationCounter.note(Self.counterKey(for: session))
    #endif
    let tracked = ObjectIdentifier(session)
    let transcript = withObservationTracking {
      session.transcript
    } onChange: { [weak self] in
      MainActor.assumeIsolated { self?.transcriptDidChange(in: tracked) }
    }
    return Dictionary(
      zip(transcript.map(\.rowKey), transcript.indices), uniquingKeysWith: { first, _ in first })
  }

  /// Marks the dictionary as stale after a change of the transcript of the
  /// session model of the last build.
  ///
  /// - Parameter tracked: The identity of the session model whose
  ///   transcript changed. A change in an earlier session model does not
  ///   mark the dictionary.
  private func transcriptDidChange(in tracked: ObjectIdentifier) {
    guard let session, ObjectIdentifier(session) == tracked else { return }
    positions = nil
  }
}
