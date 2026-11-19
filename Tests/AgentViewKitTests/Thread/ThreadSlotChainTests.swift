import AgentViewKitTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// Tests that a host can give the side cards (D205) and the search hits
/// (TestudoApp D207 (f)) to one thread, in each order.
///
/// Each test lays out a thread view in an `NSHostingView` with no window, so
/// no test shows a window or takes the focus. The side card of each test is
/// a probe that keeps the search of the thread that shows it. The search
/// has the removal of the hits of the host only when the thread took the
/// hits.
@MainActor @Suite struct ThreadSlotChainTests {
  /// The search of the thread that the probe card sees.
  @MainActor final class SeenSearch {
    /// The search of the thread, or `nil` before the card shows.
    var search: TranscriptSearch?
  }

  /// A side card that keeps the search of the thread that shows it.
  struct ProbeCard: View {
    /// The box that gets the search of the thread.
    let seen: SeenSearch

    /// The search of the thread that shows the card.
    @Environment(\.transcriptSearch) private var search

    var body: some View {
      Color.clear
        .onChange(of: search.map(ObjectIdentifier.init), initial: true) {
          seen.search = search
        }
    }
  }

  /// The width of the thread of the tests.
  static let width: CGFloat = 900

  /// The height of the thread of the tests.
  static let height: CGFloat = 400

  /// The session of the thread of the tests.
  static func session() -> SessionModel {
    SessionModel.preview(transcript: [.user("Fix the test."), .agent("Done.")])
  }

  /// A production change that fails this test: a method of the two returns
  /// a view that does not have the other method, so this test does not
  /// compile, or the thread drops the cards or the hits.
  @Test func aThreadWithTheSideCardsThenTheHitsShowsTheCardsAndTakesTheHits() {
    let seen = SeenSearch()

    StyleViewHost.layOut(
      AgentThreadView(session: Self.session()) { EmptyView() }
        .sideCards { ProbeCard(seen: seen) }
        .transcriptSearchHits(.constant(TranscriptSearchHits([])))
        .frame(width: Self.width, height: Self.height))

    #expect(seen.search?.hostRemoval != nil)
  }

  /// A production change that fails this test: a method of the two returns
  /// a view that does not have the other method, so this test does not
  /// compile, or the thread drops the cards or the hits.
  @Test func aThreadWithTheHitsThenTheSideCardsShowsTheCardsAndTakesTheHits() {
    let seen = SeenSearch()

    StyleViewHost.layOut(
      AgentThreadView(session: Self.session()) { EmptyView() }
        .transcriptSearchHits(.constant(TranscriptSearchHits([])))
        .sideCards { ProbeCard(seen: seen) }
        .frame(width: Self.width, height: Self.height))

    #expect(seen.search?.hostRemoval != nil)
  }
}
