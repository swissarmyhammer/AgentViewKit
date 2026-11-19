import AgentViewKitTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// Tests that a host can give the side cards (D205), the search hits
/// (TestudoApp D207 (f)), the header and the unavailable message (TestudoApp
/// D208 (i)) to one thread, in each order.
///
/// Each test lays out a thread view in an `NSHostingView` with no window, so
/// no test shows a window or takes the focus. The side card of each test is
/// a probe that keeps the search of the thread that shows it. The search
/// has the removal of the hits of the host only when the thread took the
/// hits. The side card of the order tests also keeps the command target of
/// the thread, which is unavailable only when the thread took the message.
@MainActor @Suite struct ThreadSlotChainTests {
  /// The parts of the thread that the probe card sees.
  @MainActor final class SeenScope {
    /// The search of the thread, or `nil` before the card shows.
    var search: TranscriptSearch?
    /// The command target of the thread, or `nil` before the card shows.
    var target: AgentCommandTarget?
  }

  /// A side card that keeps the search and the command target of the
  /// thread that shows it.
  struct ProbeCard: View {
    /// The box that gets the parts of the thread.
    let seen: SeenScope

    /// The search of the thread that shows the card.
    @Environment(\.transcriptSearch) private var search

    /// The command target of the thread that shows the card.
    @Environment(\.agentCommandTarget) private var target

    var body: some View {
      Color.clear
        .onChange(of: search.map(ObjectIdentifier.init), initial: true) {
          seen.search = search
        }
        .onChange(of: target.map(ObjectIdentifier.init), initial: true) {
          seen.target = target
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
    let seen = SeenScope()

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
    let seen = SeenScope()

    StyleViewHost.layOut(
      AgentThreadView(session: Self.session()) { EmptyView() }
        .transcriptSearchHits(.constant(TranscriptSearchHits([])))
        .sideCards { ProbeCard(seen: seen) }
        .frame(width: Self.width, height: Self.height))

    #expect(seen.search?.hostRemoval != nil)
  }

  // MARK: - Each order of the four modifiers

  /// A modifier of the thread that a host applies.
  enum Slot: CaseIterable, Sendable {
    /// ``SwiftUI/View/threadHeader(_:)``.
    case header
    /// ``SwiftUI/View/threadUnavailable(_:)``.
    case unavailable
    /// ``SwiftUI/View/sideCards(_:)``.
    case sideCards
    /// ``SwiftUI/View/transcriptSearchHits(_:)``.
    case hits
  }

  /// The probes of one order test.
  struct Probes {
    /// The record of the probe in the header.
    let header = SlotProbeRecord()
    /// The parts of the thread that the probe card sees.
    let seen = SeenScope()
  }

  /// Each order of the four modifiers.
  nonisolated static let orders: [[Slot]] = permutations(of: Slot.allCases)

  /// Each order of `slots`.
  ///
  /// - Parameter slots: The modifiers.
  /// - Returns: The permutations of `slots`. An empty list has one order,
  ///   the empty order.
  nonisolated static func permutations(of slots: [Slot]) -> [[Slot]] {
    if slots.isEmpty { return [[]] }
    return slots.indices.flatMap { index in
      var rest = slots
      let first = rest.remove(at: index)
      return permutations(of: rest).map { [first] + $0 }
    }
  }

  /// Applies one modifier with its probe to a thread.
  ///
  /// - Parameters:
  ///   - slot: The modifier.
  ///   - view: The thread with the modifiers before this one.
  ///   - probes: The probes of the test.
  /// - Returns: The thread with the modifier.
  static func apply(_ slot: Slot, to view: AnyView, probes: Probes) -> AnyView {
    switch slot {
    case .header: AnyView(view.threadHeader { SlotProbe(record: probes.header) })
    case .unavailable: AnyView(view.threadUnavailable(ThreadUnavailableTests.message))
    case .sideCards: AnyView(view.sideCards { ProbeCard(seen: probes.seen) })
    case .hits: AnyView(view.transcriptSearchHits(.constant(TranscriptSearchHits([]))))
    }
  }

  /// Lays out a thread with the four modifiers in `order`.
  ///
  /// - Parameter order: The order of the modifiers, the first nearest to
  ///   the thread.
  /// - Returns: The probes of the thread.
  static func layOut(_ order: [Slot]) -> Probes {
    let probes = Probes()
    let thread = order.reduce(AnyView(AgentThreadView(session: session()) { EmptyView() })) {
      apply($1, to: $0, probes: probes)
    }
    StyleViewHost.layOut(thread.frame(width: width, height: height))
    return probes
  }

  /// A production change that fails this test: a modifier returns a view
  /// that does not have the header modifier, or the thread drops the header.
  @Test(arguments: orders)
  func theThreadShowsTheHeaderInEachOrder(_ order: [Slot]) {
    #expect(Self.layOut(order).header.isShown)
  }

  /// A production change that fails this test: the thread does not give
  /// the unavailable message to its command target in this order.
  @Test(arguments: orders)
  func theThreadTakesTheUnavailableMessageInEachOrder(_ order: [Slot]) {
    #expect(Self.layOut(order).seen.target?.isSessionUnavailable == true)
  }

  /// A production change that fails this test: the thread drops the side
  /// cards or the hits in this order.
  @Test(arguments: orders)
  func theThreadShowsTheCardsAndTakesTheHitsInEachOrder(_ order: [Slot]) {
    #expect(Self.layOut(order).seen.search?.hostRemoval != nil)
  }
}
