import AppKit
import SwiftUI
import Testing

/// The layout expectations of a SwiftUI view in an `NSHostingController`.
///
/// A host such as a `NavigationSplitView` column gives the minimum size of
/// its content to the window. A view with a large minimum size then makes a
/// large window minimum size, and a changed minimum size can start a
/// constraint update loop in AppKit.
public enum HostedLayoutExpectations {
  /// Expects that the minimum height of `view` is not more than its height
  /// at `width`.
  ///
  /// The minimum height is the height that
  /// `NSHostingController.sizeThatFits(in: .zero)` gives. A wrapped text
  /// with `.fixedSize(horizontal: false, vertical: true)` gives its full
  /// wrapped height at width 0 as its minimum height, so a view with such a
  /// text fails this expectation.
  ///
  /// - Parameters:
  ///   - view: The view to measure.
  ///   - width: The usual width of the view, in points.
  ///   - sourceLocation: The location of the caller, for the failure report.
  public static func expectMinimumHeightFitsWidth(
    of view: some View,
    width: CGFloat,
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    let controller = NSHostingController(rootView: view)

    let minimumSize = controller.sizeThatFits(in: .zero)
    let sizeAtWidth = controller.sizeThatFits(in: CGSize(width: width, height: .infinity))

    #expect(minimumSize.height <= sizeAtWidth.height, sourceLocation: sourceLocation)
  }
}
