import FoundationModelsACP
import SwiftUI

/// One hit of a search of the session transcripts in one entry of the
/// transcript (TestudoApp D207 (f)).
///
/// The host gets the hits from the search of the server
/// (`searchSessions(session:)`), and gives them to the thread with
/// ``SwiftUI/View/transcriptSearchHits(_:)``.
public struct TranscriptSearchHit: Sendable, Hashable {
  /// The wire id of the entry of the hit.
  public let entryID: SessionEntry.ID

  /// The matched words of the hit. The thread marks each match of each word
  /// in the entry. An empty list is a hit that only the cosine search found:
  /// the thread then marks the whole entry.
  public let terms: [String]

  /// Makes one hit.
  ///
  /// - Parameters:
  ///   - entryID: The wire id of the entry of the hit.
  ///   - terms: The matched words, or an empty list for a hit that only the
  ///     cosine search found.
  public init(entryID: SessionEntry.ID, terms: [String]) {
    self.entryID = entryID
    self.terms = terms
  }
}

/// The hits of a search of the session transcripts in one transcript, best
/// first (TestudoApp D207 (f)).
public struct TranscriptSearchHits: Sendable, Hashable {
  /// The hits, best first. The thread reveals the first hit whose entry it
  /// has.
  public let hits: [TranscriptSearchHit]

  /// Makes the hits of one transcript.
  ///
  /// - Parameter hits: The hits, best first.
  public init(_ hits: [TranscriptSearchHit]) {
    self.hits = hits
  }
}

extension EnvironmentValues {
  /// The binding of the search hits that the host gave to the nearest
  /// ``AgentThreadView``, or `nil`. Set it with
  /// ``SwiftUI/View/transcriptSearchHits(_:)``.
  @Entry var transcriptSearchHits: Binding<TranscriptSearchHits?>? = nil
}

/// The search hit slot of the thread view.
extension View {
  /// Shows the hits of a search of the session transcripts in the thread
  /// views in this view (TestudoApp D207 (f)).
  ///
  /// The modifier sets an environment value that ``AgentThreadView`` reads.
  /// Thus it chains with the other modifiers of the thread, such as
  /// ``SwiftUI/View/sideCards(_:)``, in each order. Apply it on the thread
  /// view: each thread view in this view takes the hits.
  ///
  /// When the hits change, the thread scrolls to the entry of the first hit
  /// (the best hit). It loads the earlier pages when the row of that entry
  /// is not loaded, and it opens a collapsed tool call of that entry. The
  /// first hit becomes the current hit. Each hit is resolved as described on
  /// ``TranscriptSearch``. When the hits come before the entries,
  /// the thread reveals the first hit when its entry comes.
  ///
  /// In the entry of each hit, each match of a word of the
  /// ``TranscriptSearchHit/terms`` (no case, no diacritics, at the start of a
  /// word) has the find mark of EditorKit. A hit with no terms marks the
  /// whole entry with the same color at a low opacity. The current hit has
  /// the stronger mark.
  ///
  /// Find Next Hit (Command-G) and Find Previous Hit (Shift-Command-G) make
  /// the next or the previous entry with a hit current, in the order of the
  /// transcript, and reveal it. After the last hit they wrap, with the
  /// system beep. VoiceOver announces each current hit with its place and
  /// the author of its entry, such as "Hit 2 of 7, You". Esc in the thread
  /// sets the binding to `nil`. While a text input has the focus, these keys
  /// stay the keys of the text input.
  ///
  /// ```swift
  /// AgentThreadView(session: session)
  ///   .transcriptSearchHits($hits)
  /// ```
  ///
  /// - Parameter hits: The hits, or `nil` for no hits. The thread can set
  ///   the binding to `nil` to remove the hits.
  /// - Returns: A view whose thread views show the hits.
  public func transcriptSearchHits(_ hits: Binding<TranscriptSearchHits?>) -> some View {
    environment(\.transcriptSearchHits, hits)
  }
}
