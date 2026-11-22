import AgentViewKit
import Observation
import SwiftUI

/// The search hits of a test host, which a test changes outside a view
/// update.
@MainActor @Observable public final class HostSearchHits {
  /// The hits, or `nil` for no hits.
  public var hits: TranscriptSearchHits?

  /// Makes a host with no hits.
  public init() {}
}

/// A host view that gives its content the hits of a ``HostSearchHits`` with
/// `transcriptSearchHits(_:)`, as a host app does.
///
/// The view makes the binding in its body. `Binding(get:set:)` reads the
/// hits when it is made, so the body depends on the hits: a change of the
/// hits evaluates the body again and gives the thread a binding with the new
/// value. A binding that a test makes one time, outside a body, does not do
/// this. A view reads the value that a binding had when it was made, so the
/// thread never sees a change of the hits.
public struct TranscriptSearchHitsHost<Content: View>: View {
  /// The hits of the host.
  let host: HostSearchHits

  /// The view that gets the hits, such as a thread view.
  let content: Content

  /// Makes a host view.
  ///
  /// - Parameters:
  ///   - host: The hits of the host.
  ///   - content: The view that gets the hits.
  public init(host: HostSearchHits, @ViewBuilder content: () -> Content) {
    self.host = host
    self.content = content()
  }

  /// The content, with a binding to the hits of the host that the body
  /// makes on each evaluation.
  public var body: some View {
    content.transcriptSearchHits(Binding(get: { host.hits }, set: { host.hits = $0 }))
  }
}
