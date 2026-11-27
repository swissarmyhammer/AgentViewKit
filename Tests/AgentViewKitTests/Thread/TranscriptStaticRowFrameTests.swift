import AppKit
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// The queries that the frame of a row of a thread
/// (``TranscriptStaticRowFrame``) sends to the content of the row (card
/// ^9ync5h3).
///
/// Each query of the content of a row lays out its text again. The lazy
/// stack of a thread asks each row for its size many times in each frame
/// of a flick, so a static row with a known height must answer without its
/// content.
@MainActor @Suite struct TranscriptStaticRowFrameTests {
  /// The proposed size of the frame.
  static let proposal = CGSize(width: 320, height: 240)

  /// The height of the probe in the frame, in points.
  static let probeHeight: CGFloat = 1000

  /// The height of the static form of the row, in points.
  static let staticHeight: CGFloat = 96

  /// A frame around a probe of `record`.
  ///
  /// - Parameters:
  ///   - record: The record of the probe.
  ///   - knowsHeight: Whether the frame has a static height
  ///     (``staticHeight``), as a static row with a known height has.
  /// - Returns: The frame.
  static func frame(_ record: SizeQueryRecord, knowsHeight: Bool) -> some View {
    let knownHeight: TranscriptStaticRowFrame.Height = { _ in staticHeight }
    return TranscriptStaticRowFrame(id: .local(UUID()), staticHeight: knowsHeight ? knownHeight : nil) {
      SizeQueryProbe(record: record, height: probeHeight) {}
    }
  }

  /// The size of `root` at ``proposal``.
  ///
  /// - Parameter root: The root view.
  /// - Returns: The fitting size.
  static func size(of root: some View) -> CGSize {
    NSHostingController(rootView: root).sizeThatFits(in: proposal)
  }

  /// A production change that fails this test: the frame measures its
  /// content before it reads the known height of the static form, so each
  /// size query of a static row lays out the text of the row.
  @Test func aStaticRowWithAKnownHeightDoesNotMeasureItsContent() {
    let record = SizeQueryRecord()

    _ = Self.size(of: Self.frame(record, knowsHeight: true))

    #expect(record.queryCount == 0)
  }

  /// A production change that fails this test: the frame skips its content
  /// and gives a size that is not the proposed width and the known height.
  @Test func aStaticRowWithAKnownHeightHasTheProposedWidthAndThatHeight() {
    let size = Self.size(of: Self.frame(SizeQueryRecord(), knowsHeight: true))

    #expect(size == CGSize(width: Self.proposal.width, height: Self.staticHeight))
  }

  /// A production change that fails this test: the frame of a real row does
  /// not measure its content, so the real row has no height of its own.
  @Test func aRealRowHasTheHeightOfItsContent() {
    let size = Self.size(of: Self.frame(SizeQueryRecord(), knowsHeight: false))

    #expect(size.height == Self.probeHeight)
  }

  /// A production change that fails this test: the frame places the
  /// content of a static row with a known height at a proposal with no
  /// height, so the content measures itself at another proposal than the
  /// size of the row, and lays out its text again.
  @Test func aStaticRowWithAKnownHeightPlacesItsContentAtTheSizeOfTheRow() {
    let record = SizeQueryRecord()
    let knownHeight: TranscriptStaticRowFrame.Height = { _ in Self.staticHeight }
    // The probe holds a view, so SwiftUI places it.
    let root = TranscriptStaticRowFrame(id: .local(UUID()), staticHeight: knownHeight) {
      SizeQueryProbe(record: record, height: Self.probeHeight) { Color.clear }
    }
    .frame(width: Self.proposal.width)
      .fixedSize(horizontal: false, vertical: true)
    let (hosting, window) = UnorderedWindow.mount(root, size: Self.proposal)
    defer { UnorderedWindow.close(window) }

    hosting.layoutSubtreeIfNeeded()

    #expect(
      record.placements == [ProposedViewSize(width: Self.proposal.width, height: Self.staticHeight)],
      "\(record.placements)")
  }

  /// A production change that fails this test: the frame takes the default
  /// guides of `Layout`, which place the content and ask it for its guides.
  /// The scroll view of a thread asks for the guides of the rows for its
  /// bottom anchor, so each query lays out the rows again.
  @Test func anAlignmentQueryDoesNotAskTheContent() {
    let record = SizeQueryRecord()

    _ = Self.size(of: AlignmentQueryStack { Self.frame(record, knowsHeight: false) })

    #expect(record.alignmentQueryCount == 0)
  }
}
