@testable import AgentViewKit
import Foundation
import Testing

/// The decision of a Textual area to claim the selection when the first
/// responder of its window changes.
@Suite struct TextualSelectionProbeTests {
  /// The frame of the probe of the tests, in window coordinates.
  static let probe = CGRect(x: 20, y: 100, width: 300, height: 80)

  /// The type name of the Textual interaction view.
  static let interaction = TextualSelectionProbeView.interactionTypeName

  @Test func interactionViewWithTheFrameOfTheProbeClaims() {
    #expect(
      TextualSelectionProbeView.claims(
        responderTypeName: Self.interaction, responderFrame: Self.probe, probeFrame: Self.probe))
  }

  @Test func interactionViewInsideTheProbeClaims() {
    #expect(
      TextualSelectionProbeView.claims(
        responderTypeName: Self.interaction, responderFrame: Self.probe.insetBy(dx: 4, dy: 4),
        probeFrame: Self.probe))
  }

  @Test func frameThatIsLargerByLessThanTheToleranceClaims() {
    let frame = Self.probe.insetBy(dx: -0.5, dy: -0.5)
    #expect(
      TextualSelectionProbeView.claims(
        responderTypeName: Self.interaction, responderFrame: frame, probeFrame: Self.probe))
  }

  @Test func interactionViewOfADifferentAreaDoesNotClaim() {
    let below = Self.probe.offsetBy(dx: 0, dy: Self.probe.height + 8)
    #expect(
      !TextualSelectionProbeView.claims(
        responderTypeName: Self.interaction, responderFrame: below, probeFrame: Self.probe))
  }

  @Test func interactionViewThatIsLargerThanTheProbeDoesNotClaim() {
    let frame = Self.probe.insetBy(dx: -10, dy: -10)
    #expect(
      !TextualSelectionProbeView.claims(
        responderTypeName: Self.interaction, responderFrame: frame, probeFrame: Self.probe))
  }

  /// A code block in a paragraph is an EditorKit view in the frame of the
  /// paragraph. It claims for itself, so the paragraph does not claim.
  @Test func editorViewInsideTheProbeDoesNotClaim() {
    #expect(
      !TextualSelectionProbeView.claims(
        responderTypeName: "EditorTextView", responderFrame: Self.probe.insetBy(dx: 8, dy: 8),
        probeFrame: Self.probe))
  }

  @Test func emptyProbeDoesNotClaim() {
    #expect(
      !TextualSelectionProbeView.claims(
        responderTypeName: Self.interaction, responderFrame: .zero, probeFrame: .zero))
  }
}
