import CoreGraphics
import Testing

@testable import AgentViewKit

/// The collapse rule of the path, from widths and not from the number of
/// sessions, with no window.
@Suite struct BreadcrumbCollapseTests {
  /// The shape for a row with the widths of the tests.
  static func shape(crumbs: [CGFloat], available: CGFloat, agent: CGFloat = 100) -> BreadcrumbCollapse.Shape {
    BreadcrumbCollapse.shape(
      agentWidth: agent, crumbWidths: crumbs, overflowWidth: 20, separatorWidth: 10, available: available)
  }

  @Test func aPathThatFitsStaysWhole() {
    #expect(Self.shape(crumbs: [50, 50, 50], available: 400) == .full)
  }

  @Test func aPathThatDoesNotFitCollapsesItsMiddle() {
    // Full: 100 + 150 + 30 = 280. Collapsed: 100 + 100 + 20 + 30 = 250.
    #expect(Self.shape(crumbs: [50, 50, 50], available: 260) == .collapsed)
  }

  @Test func aPathThatDoesNotFitEvenCollapsedGetsTruncatedText() {
    #expect(Self.shape(crumbs: [50, 50, 50], available: 200) == .truncated)
  }

  @Test func aPathWithNoMiddleCrumbHasNothingToCollapse() {
    #expect(Self.shape(crumbs: [50, 50], available: 150) == .truncated)
    #expect(BreadcrumbCollapse.collapsedIndices(for: .truncated, count: 2).isEmpty)
  }

  @Test func theAgentSegmentKeepsItsWidthSoOnlyTheCrumbsGiveWay() {
    // A wide agent leaves little for the crumbs: the crumbs give way first.
    #expect(Self.shape(crumbs: [50, 50, 50], available: 300, agent: 200) == .truncated)
    #expect(Self.shape(crumbs: [50, 50, 50], available: 300, agent: 100) == .full)
  }

  @Test func theCollapsedShapeHoldsTheMiddleCrumbsInTheDropdown() {
    #expect(BreadcrumbCollapse.collapsedIndices(for: .collapsed, count: 5) == 1..<4)
    #expect(BreadcrumbCollapse.collapsedIndices(for: .full, count: 5).isEmpty)
  }

  @Test func aLongerPathNeedsNoOtherRule() {
    let widths = [CGFloat](repeating: 40, count: 9)

    #expect(Self.shape(crumbs: widths, available: 1000) == .full)
    #expect(Self.shape(crumbs: widths, available: 300) == .collapsed)
  }
}
