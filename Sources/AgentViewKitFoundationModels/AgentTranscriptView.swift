import AgentViewKit
import FoundationModels
import SwiftUI

/// The view of a FoundationModels transcript value (plan.md §3.6).
///
/// The view makes an ``AgentThread`` from the transcript one time, with
/// ``TranscriptMapping``, and shows it in an ``AgentThreadView``. Use it for a
/// transcript that the host persisted. The view does not update: a change to
/// the transcript after the first body does not change the thread. To show a
/// different transcript, give the view a different identity, for example
/// with `.id(_:)`.
public struct AgentTranscriptView: View {
  /// The transcript to show.
  let transcript: Transcript

  /// The catalog that decodes the structured segments.
  let catalog: StructuredCatalog

  /// The store that keeps the thread for the identity of the view.
  @State private var store = SnapshotStore()

  /// Makes the view of a transcript.
  ///
  /// - Parameters:
  ///   - transcript: The transcript to show.
  ///   - catalog: The catalog that decodes the structured segments.
  public init(transcript: Transcript, catalog: StructuredCatalog = .standard) {
    self.transcript = transcript
    self.catalog = catalog
  }

  public var body: some View {
    AgentThreadView(thread: store.thread(for: transcript, catalog: catalog))
  }

  /// Makes a thread that holds the items of a transcript.
  ///
  /// - Parameters:
  ///   - transcript: The transcript to read.
  ///   - catalog: The catalog that decodes the structured segments.
  /// - Returns: A new thread, with one item for each mapped item, in order.
  public static func thread(for transcript: Transcript, catalog: StructuredCatalog = .standard) -> AgentThread {
    let thread = AgentThread()
    for item in TranscriptMapping.items(for: transcript, catalog: catalog) {
      thread.apply(.insert(item, after: nil))
    }
    return thread
  }
}

/// Keeps the thread of one ``AgentTranscriptView``.
///
/// The store makes the thread on the first request and gives the same thread
/// on each later request. Thus the view maps the transcript one time for each
/// identity, and a new value of the view struct does not map it again.
private final class SnapshotStore {
  /// The thread, or `nil` before the first request.
  private var snapshot: AgentThread?

  /// The thread of the view. The first call makes it.
  ///
  /// - Parameters:
  ///   - transcript: The transcript to read on the first call.
  ///   - catalog: The catalog to use on the first call.
  /// - Returns: The thread.
  func thread(for transcript: Transcript, catalog: StructuredCatalog) -> AgentThread {
    if let snapshot { return snapshot }
    let thread = AgentTranscriptView.thread(for: transcript, catalog: catalog)
    snapshot = thread
    return thread
  }
}
