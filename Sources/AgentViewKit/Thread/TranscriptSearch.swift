import AppKit
import EditorCommandsUI
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
///
/// Find Next Hit and Find Previous Hit call ``step(forward:)``. A step goes
/// through the entries with a hit in the order of the transcript, and an
/// entry with two hits is one stop. At the end, the step wraps and plays
/// the system beep (``beep``).
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
  ///
  /// Each request has its own identity. Thus two requests for the same row
  /// are two different values, and the list sees each one as a change.
  struct RevealRequest: Hashable, Identifiable {
    /// The row key of the entry of the hit.
    let rowKey: String

    /// The identity of the request: the number of the request.
    let id: Int
  }

  /// The hits whose entries the transcript holds, best first.
  private(set) var hits: [Hit] = []

  /// The index in ``hits`` of the current hit, or `nil` when there is no
  /// hit.
  private(set) var currentIndex: Int?

  /// The reveal that waits for the list, or `nil`.
  private(set) var revealRequest: RevealRequest?

  /// The number of the last reveal request. Each hit that becomes current
  /// adds one, so a view that reads the number sees each reveal, also a
  /// reveal of the same hit again.
  private(set) var revealSerial = 0

  /// Plays the sound of a step that wraps. The default plays the system
  /// beep. A test gives its own, so that no test makes a sound.
  @ObservationIgnored var beep: @MainActor () -> Void = { NSSound.beep() }

  /// Sets the hits of the host to `nil`, or `nil` when no host gave hits.
  /// ``TranscriptSearchDriver`` gives it from the binding of the host.
  @ObservationIgnored var hostRemoval: (@MainActor () -> Void)?

  /// The hits of the host, or `nil` for no hits.
  @ObservationIgnored private var source: TranscriptSearchHits?

  /// `true` while the hits of the host wait for the first entry of a hit.
  @ObservationIgnored private var waitsForReveal = false

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
    revealRequest = RevealRequest(rowKey: hits[index].rowKey, id: revealSerial)
  }

  /// The number of the entries with a hit. Two hits in one entry count as
  /// one.
  var hitCount: Int {
    stops.count
  }

  /// The place of the current hit in the order of the transcript, from 1,
  /// or `nil` when there is no current hit.
  var currentHitNumber: Int? {
    guard let current = currentHit else { return nil }
    return stops.firstIndex { hits[$0].position == current.position }.map { $0 + 1 }
  }

  /// Makes the next or the previous entry with a hit current, in the order
  /// of the transcript, and asks the list to reveal it.
  ///
  /// The step starts at the current hit. After the last entry, it goes to
  /// the first entry, and before the first entry, to the last entry. A step
  /// that wraps plays the ``beep``. With no current hit, the step goes to
  /// the first or the last entry with no beep. With no hits, it does
  /// nothing.
  ///
  /// - Parameter forward: `true` for the next hit, `false` for the previous
  ///   hit.
  func step(forward: Bool) {
    let stops = stops
    guard let first = stops.first, let last = stops.last else { return }
    let end = forward ? first : last
    guard let current = currentHit?.position else {
      makeCurrent(end)
      return
    }
    let neighbor =
      forward
      ? stops.first { hits[$0].position > current }
      : stops.last { hits[$0].position < current }
    if neighbor == nil {
      beep()
    }
    makeCurrent(neighbor ?? end)
  }

  /// Asks the host to remove its hits: Esc in the thread (TestudoApp
  /// D207 (f)). The host sets its binding to `nil`, and the change of the
  /// binding removes the hits of this value.
  func removeHits() {
    hostRemoval?()
  }

  /// The index in ``hits`` of the best hit of each entry with a hit, in the
  /// order of the transcript.
  private var stops: [Int] {
    let best = Dictionary(hits.indices.map { (hits[$0].position, $0) }, uniquingKeysWith: min)
    return best.keys.sorted().compactMap { best[$0] }
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
/// search of a thread, opens the entry of the current hit, and announces
/// each new current hit (TestudoApp D207 (f)).
///
/// The announcement tells the place of the hit and the author of its entry,
/// such as "Hit 2 of 7, You", through the announcer of the environment.
/// The view draws nothing. ``AgentThreadView`` puts it in its background, so
/// that a change of the hits or of the transcript evaluates only this view.
/// The view reads the transcript only while the host gives hits.
struct TranscriptSearchDriver: View {
  /// The session that the thread shows.
  let session: SessionModel

  /// The search of the thread.
  let search: TranscriptSearch

  /// The store of the expanded rows of the thread.
  let store: ExpandedBlocksStore

  /// The hits of the host (``AgentThreadView/transcriptSearchHits(_:)``), or
  /// `nil`.
  @Environment(\.transcriptSearchHits) private var hostHits

  /// The announcer that speaks each new current hit.
  @Environment(\.announcer) private var announcer

  /// The titles of the sessions that the host gives, for the author of a
  /// message from another session.
  @Environment(\.sessionTitles) private var titles

  var body: some View {
    let hits = hostHits?.wrappedValue
    Color.clear
      .accessibilityHidden(true)
      .onChange(of: hits, initial: true) {
        search.hostRemoval = hostHits.map(Self.removal(of:))
        search.show(hits, rowKeys: rowKeys)
      }
      .onChange(of: hits.map { _ in ObjectIdentifier(session) }) {
        search.transcriptChanged(rowKeys: rowKeys)
      }
      .onChange(of: hits.map { _ in session.transcript.count }) {
        search.transcriptChanged(rowKeys: rowKeys)
      }
      .onChange(of: search.currentHit, initial: true) {
        Self.openCurrentHit(of: search, in: session.transcript, store: store)
      }
      .onChange(of: search.revealSerial) {
        Self.announceCurrentHit(of: search, in: session.transcript, titles: titles, to: announcer)
      }
  }

  /// The removal of the hits of the host: it sets the binding to `nil`.
  ///
  /// - Parameter binding: The binding of the hits of the host.
  /// - Returns: The removal.
  private static func removal(of binding: Binding<TranscriptSearchHits?>) -> @MainActor () -> Void {
    { binding.wrappedValue = nil }
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

  /// Announces the current hit: its place in the order of the transcript
  /// and the author of its entry.
  ///
  /// - Parameters:
  ///   - search: The search of the thread.
  ///   - transcript: The transcript of the session.
  ///   - titles: The titles of the sessions that the host gives.
  ///   - announcer: The announcer that speaks the text.
  static func announceCurrentHit(
    of search: TranscriptSearch, in transcript: [TranscriptEntry], titles: SessionTitles,
    to announcer: any Announcer
  ) {
    guard let hit = search.currentHit, let number = search.currentHitNumber,
      transcript.indices.contains(hit.position)
    else { return }
    let author = author(of: transcript[hit.position], titles: titles)
    let text = announcement(number: number, count: search.hitCount, author: author)
    announcer.announce(text, priority: .medium)
  }

  /// The announcement of a current hit, such as "Hit 2 of 7, You".
  ///
  /// - Parameters:
  ///   - number: The place of the hit in the order of the transcript, from 1.
  ///   - count: The number of the entries with a hit.
  ///   - author: The author of the entry of the hit.
  /// - Returns: The text.
  static func announcement(number: Int, count: Int, author: String) -> String {
    String(
      localized: "Hit \(number) of \(count), \(author)", bundle: .module,
      comment: "VoiceOver announcement of the current search hit: its place, then its author.")
  }

  /// The author of an entry, as the thread names it: the user for a user
  /// message, the sender line for a message from another session, and the
  /// agent for each other entry.
  ///
  /// - Parameters:
  ///   - entry: The entry.
  ///   - titles: The titles of the sessions that the host gives.
  /// - Returns: The author.
  static func author(of entry: TranscriptEntry, titles: SessionTitles) -> String {
    switch entry {
    case .userMessage: MessageRole.user.title
    case .sessionMessage(let message):
      SessionMessageView.participantsText(
        sender: message.senderSessionId, recipient: message.recipientSessionId,
        message: SessionMessageView.sender(in: message.meta), titles: titles)
    case .agentMessage, .thought, .toolCall, .terminal, .plan, .unknown, .error, .compaction:
      MessageRole.assistant.title
    }
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
