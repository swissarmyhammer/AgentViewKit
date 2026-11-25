import AppKit
import SwiftUI
import Testing

@testable import AgentViewKit

/// The size of a ``ProposalSizedLayout`` is the proposal, and the layout
/// asks its child for no size (task ^7q5zdsj).
@MainActor @Suite struct ProposalSizedLayoutTests {
  /// The proposed size of the layout.
  static let proposal = CGSize(width: 320, height: 240)

  /// The height of the probe in the layout, in points.
  static let probeHeight: CGFloat = 1000

  /// A layout around a probe of `record`.
  ///
  /// - Parameter record: The record of the probe.
  /// - Returns: The layout.
  static func layout(_ record: SizeQueryRecord) -> some View {
    ProposalSizedLayout { SizeQueryProbe(record: record, height: probeHeight) {} }
  }

  /// A production change that fails this test: the layout answers with the
  /// size of its child, as a `VStack` does.
  @Test func theSizeIsTheProposal() {
    let size = NSHostingController(rootView: Self.layout(SizeQueryRecord())).sizeThatFits(in: Self.proposal)

    #expect(size == Self.proposal)
  }

  /// A production change that fails this test: the layout asks its child
  /// for its size to answer its own size.
  @Test func aSizeQueryDoesNotAskTheChild() {
    let record = SizeQueryRecord()

    _ = NSHostingController(rootView: Self.layout(record)).sizeThatFits(in: Self.proposal)

    #expect(record.queryCount == 0)
  }

  /// A production change that fails this test: the layout answers an
  /// unspecified dimension with the size of its child. The fitting size of
  /// a host is the ideal size: a proposal with no width and no height.
  @Test func anUnspecifiedProposalHasTheSizeZero() {
    let size = NSHostingView(rootView: Self.layout(SizeQueryRecord())).fittingSize

    #expect(size == .zero)
  }
}
