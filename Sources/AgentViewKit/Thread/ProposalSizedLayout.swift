import SwiftUI

/// A layout whose size is the proposal, and that asks its child for no size
/// (task ^7q5zdsj).
///
/// The layout of `.safeAreaBar` asks its content for its minimum size on
/// each layout. When the content is a scroll view, that query measures the
/// lazy stack of the scroll view and the rows in it, on each frame of a
/// scroll. Put the content of a bar in this layout: the bar then gets the
/// size of the proposal and does not measure the content. The content
/// fills the space that the layout gets, so a flexible content, such as a
/// scroll view, keeps its frame.
///
/// An unspecified dimension of the proposal (`nil`) has the size zero. Thus
/// the minimum size and the ideal size of the layout are zero, and the
/// layout does not change the minimum size of a window.
struct ProposalSizedLayout: Layout {
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
    proposal.replacingUnspecifiedDimensions(by: .zero)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
    for subview in subviews {
      subview.place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(bounds.size))
    }
  }
}
