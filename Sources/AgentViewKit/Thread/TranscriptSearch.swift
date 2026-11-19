import FoundationModelsACPClient
import Observation
import SwiftUI

/// The search hits that a thread shows, the current hit, and the reveal of
/// a hit (TestudoApp D207 (f)).
///
/// ``AgentThreadView`` keeps one value. It gives each change of the hits of
/// the host to ``show(_:rowKeys:)``, and each change of the transcript to
/// ``transcriptChanged(rowKeys:)``. The value finds the entry of each hit by
/// the row key of the wire id of the hit (`TranscriptEntry.ID.wire`), and
/// skips a hit whose entry the transcript does not hold.
///
/// ``ConversationView`` takes each reveal with ``takeRevealRequest()`` and
/// scrolls to its row. Each row reads its mark with ``mark(forRowKey:)``.
@MainActor @Observable
final class TranscriptSearch {
  /// One hit whose entry the transcript holds.
  struct Hit: Hashable {
    /// The row key of the entry of the hit.
    let rowKey: String

    /// The position of the entry in the transcript.
    let position: Int

    /// The matched words of the hit, or an empty list for a hit that only
    /// the cosine search found.
    let terms: [String]
  }

  /// A request to scroll the list to the row of a hit.
  struct RevealRequest: Hashable {
    /// The row key of the entry of the hit.
    let rowKey: String

    /// The number of the request. Two requests for the same row are two
    /// different values, so each one is a change.
    let serial: Int
  }

  /// The hits whose entries the transcript holds, best first.
  private(set) var hits: [Hit] = []

  /// The index in ``hits`` of the current hit, or `nil` when there is no
  /// hit.
  private(set) var currentIndex: Int?

  /// The reveal that waits for the list, or `nil`.
  private(set) var revealRequest: RevealRequest?

  /// The hits of the host, or `nil` for no hits.
  @ObservationIgnored private var source: TranscriptSearchHits?

  /// `true` while the hits of the host wait for the first entry of a hit.
  @ObservationIgnored private var waitsForReveal = false

  /// The number of the last reveal request.
  @ObservationIgnored private var revealSerial = 0

  /// Makes a value with no hits.
  init() {}

  /// The current hit, or `nil` when there is no hit.
  var currentHit: Hit? {
    currentIndex.map { hits[$0] }
  }

  /// Shows new hits of the host. The first hit whose entry the transcript
  /// holds becomes current, and the list reveals it.
  ///
  /// When no hit has an entry yet, the value waits, and
  /// ``transcriptChanged(rowKeys:)`` reveals the first hit when its entry
  /// comes.
  ///
  /// - Parameters:
  ///   - newHits: The hits, best first, or `nil` for no hits.
  ///   - rowKeys: The row keys of the transcript, in order.
  func show(_ newHits: TranscriptSearchHits?, rowKeys: [String]) {
    source = newHits
    waitsForReveal = newHits != nil
    currentIndex = nil
    revealRequest = nil
    resolve(rowKeys: rowKeys)
  }

  /// Finds the entries of the hits again after a change of the transcript,
  /// and reveals the first hit when the hits wait for it.
  ///
  /// - Parameter rowKeys: The row keys of the transcript, in order.
  func transcriptChanged(rowKeys: [String]) {
    guard source != nil else { return }
    let current = currentHit?.rowKey
    resolve(rowKeys: rowKeys)
    if let current, !waitsForReveal {
      currentIndex = hits.firstIndex { $0.rowKey == current }
    }
  }

  /// Makes a hit current, and asks the list to reveal it.
  ///
  /// - Parameter index: The index of the hit in ``hits``. An index out of
  ///   ``hits`` changes nothing.
  func makeCurrent(_ index: Int) {
    guard hits.indices.contains(index) else { return }
    currentIndex = index
    revealSerial += 1
    revealRequest = RevealRequest(rowKey: hits[index].rowKey, serial: revealSerial)
  }

  /// Gives the reveal that waits for the list, and clears it, so that a list
  /// that mounts again does not reveal the hit again.
  ///
  /// - Returns: The reveal, or `nil` when no reveal waits.
  func takeRevealRequest() -> RevealRequest? {
    defer { revealRequest = nil }
    return revealRequest
  }

  /// The mark of the row of an entry.
  ///
  /// - Parameter rowKey: The row key of the entry.
  /// - Returns: The mark of the first hit of the entry, or `nil` when the
  ///   entry has no hit.
  func mark(forRowKey rowKey: String) -> TranscriptSearchMark? {
    guard let hit = hits.first(where: { $0.rowKey == rowKey }) else { return nil }
    return TranscriptSearchMark(terms: hit.terms, isCurrent: currentHit?.rowKey == rowKey)
  }

  /// Finds the entry of each hit of the host, and reveals the first hit
  /// when the hits wait for it.
  ///
  /// - Parameter rowKeys: The row keys of the transcript, in order.
  private func resolve(rowKeys: [String]) {
    hits = Self.hits(of: source, rowKeys: rowKeys)
    guard waitsForReveal, !hits.isEmpty else { return }
    waitsForReveal = false
    makeCurrent(0)
  }

  /// The hits whose entries the transcript holds.
  ///
  /// - Parameters:
  ///   - source: The hits of the host, or `nil`.
  ///   - rowKeys: The row keys of the transcript, in order.
  /// - Returns: One hit for each hit of the host whose wire id names an
  ///   entry of the transcript, best first.
  private static func hits(of source: TranscriptSearchHits?, rowKeys: [String]) -> [Hit] {
    guard let source else { return [] }
    let positions = Dictionary(rowKeys.enumerated().map { ($1, $0) }) { first, _ in first }
    return source.hits.compactMap { hit in
      let rowKey = TranscriptEntry.ID.wire(hit.entryID).rowKey
      return positions[rowKey].map { Hit(rowKey: rowKey, position: $0, terms: hit.terms) }
    }
  }
}

/// Gives the hits of the host and each change of the transcript to the
/// search of a thread, and opens the entry of the current hit
/// (TestudoApp D207 (f)).
///
/// The view draws nothing. ``AgentThreadView`` puts it in its background, so
/// that a change of the hits or of the transcript evaluates only this view.
/// The view reads the transcript only while the host gives hits.
struct TranscriptSearchDriver: View {
  /// The size of a transcript of a session, which changes when the
  /// transcript gets an entry or when the thread shows another session.
  private struct TranscriptShape: Hashable {
    /// The identity of the session model.
    let session: ObjectIdentifier

    /// The number of entries of the transcript.
    let count: Int
  }

  /// The session that the thread shows.
  let session: SessionModel

  /// The search of the thread.
  let search: TranscriptSearch

  /// The store of the expanded rows of the thread.
  let store: ExpandedBlocksStore

  /// The hits of the host (``AgentThreadView/transcriptSearchHits(_:)``), or
  /// `nil`.
  @Environment(\.transcriptSearchHits) private var hostHits

  var body: some View {
    let hits = hostHits?.wrappedValue
    Color.clear
      .accessibilityHidden(true)
      .onChange(of: hits, initial: true) {
        search.show(hits, rowKeys: rowKeys)
      }
      .onChange(of: hits.map { _ in shape }) {
        search.transcriptChanged(rowKeys: rowKeys)
      }
      .onChange(of: search.currentHit, initial: true) {
        Self.openCurrentHit(of: search, in: session.transcript, store: store)
      }
  }

  /// The size of the transcript of the session.
  private var shape: TranscriptShape {
    TranscriptShape(session: ObjectIdentifier(session), count: session.transcript.count)
  }

  /// The row keys of the transcript of the session, in order.
  private var rowKeys: [String] {
    session.transcript.map(\.rowKey)
  }

  /// Opens the entry of the current hit when it is a tool call or a
  /// thought, which a row can show collapsed, so that its marks show.
  ///
  /// - Parameters:
  ///   - search: The search of the thread.
  ///   - transcript: The transcript of the session.
  ///   - store: The store of the expanded rows of the thread.
  static func openCurrentHit(
    of search: TranscriptSearch, in transcript: [TranscriptEntry], store: ExpandedBlocksStore
  ) {
    guard let hit = search.currentHit, transcript.indices.contains(hit.position) else { return }
    let entry = transcript[hit.position]
    guard entry.rowKey == hit.rowKey, opensForHit(entry) else { return }
    store.expand(entry: entry)
  }

  /// Whether a row of an entry can show collapsed, and thus opens when its
  /// entry is the current hit.
  ///
  /// - Parameter entry: The entry.
  /// - Returns: `true` for a tool call and for a thought.
  private static func opensForHit(_ entry: TranscriptEntry) -> Bool {
    switch entry {
    case .toolCall, .thought: true
    case .userMessage, .agentMessage, .terminal, .plan, .unknown, .error, .compaction,
      .sessionMessage:
      false
    }
  }
}

extension EnvironmentValues {
  /// The search hits of the nearest ``AgentThreadView``, or `nil` outside a
  /// thread view.
  @Entry var transcriptSearch: TranscriptSearch? = nil
}
