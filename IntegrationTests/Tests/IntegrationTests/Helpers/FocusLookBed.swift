import AppKit
import EditorStyle
import EditorTestSupport
import QuartzCore
import SwiftUI
import Testing

@testable import EditorCommandsUI

/// The bed of a hosted test of the focus look of an item (EditorKit
/// style.md, "Selection and focus"): an accent that no other view of the
/// window draws, a reference fill of the focused fill color, and the reads of
/// the window that tell a fill and a ring.
///
/// The reads look at the layers and the views of the window, never at
/// pixels, as EditorKit's `SelectableItemHostedTests` does: a fill is the
/// color of a layer, and a ring is a layer with contents or a focus ring
/// view of SwiftUI.
@MainActor enum FocusLookBed {
  /// The red component of the theme accent of the bed.
  static let accentRed: CGFloat = 0.1

  /// The green component of that accent.
  static let accentGreen: CGFloat = 0.6

  /// The blue component of that accent.
  static let accentBlue: CGFloat = 0.3

  /// The theme accent of the bed.
  static let accent = Color(red: accentRed, green: accentGreen, blue: accentBlue)

  /// The fill of a focused item in a key window: the accent at the focused
  /// opacity of EditorKit.
  static let focusedFill = accent.opacity(EditorStyle.focusedSelectionOpacity)

  /// The side of the reference fill, which stands apart from the item.
  static let referenceSide: CGFloat = 12

  /// The largest difference of one component of a color that a layer holds.
  static let componentTolerance: CGFloat = 0.002

  /// The number of fills of the focused fill color in a window with one
  /// focused item: the reference fill and the fill of the item.
  static let focusedFillCount = 2

  /// The type name, with no module, of the view that SwiftUI adds to the
  /// window to draw the system focus ring of a focusable view while its focus
  /// effect is on.
  static let systemFocusRingTypeName = "_FocusRingView"

  /// Requires that the focusable view of an item, and not the beacon of a
  /// scope, holds the first responder of the window.
  ///
  /// - Parameter harness: The harness of the window.
  /// - Throws: An issue when no view, or the beacon of a scope, holds the
  ///   first responder.
  static func requireItemHoldsFocus(in harness: HostedViewHarness<some View>) throws {
    let responder = try #require(harness.window.firstResponder as? NSView)
    try #require(!(responder is GeometryProbeView), "the beacon of the scope holds the focus, not the item")
  }

  /// The number of fills of the window with the color of the reference fill.
  ///
  /// The reference fill is the last fill of that color in depth-first order,
  /// because the bed puts it below the item.
  ///
  /// - Parameter harness: The harness of the window.
  /// - Returns: The number of fills that agree with the reference fill.
  /// - Throws: An issue when the hosting view has no layer, a fill does not
  ///   convert to the sRGB space, or the window has no fill.
  static func referenceFillCount(in harness: HostedViewHarness<some View>) throws -> Int {
    let fills = try fillColors(in: harness)
    let reference = try #require(fills.last)
    return fills.filter { isSame($0, reference) }.count
  }

  /// The colors of the fills of the window, in the sRGB space, depth first.
  ///
  /// - Parameter harness: The harness of the window.
  /// - Returns: The red, green, blue and alpha components of each fill.
  /// - Throws: An issue when the hosting view has no layer, or when a fill
  ///   does not convert to the sRGB space.
  static func fillColors(in harness: HostedViewHarness<some View>) throws -> [[CGFloat]] {
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    return try layers(in: harness).flatMap(fills(of:)).map { color in
      let converted = try #require(color.converted(to: space, intent: .defaultIntent, options: nil))
      return try #require(converted.components)
    }
  }

  /// The number of layers of the window that draw content of their own, such
  /// as a text or a `Canvas`.
  ///
  /// - Parameter harness: The harness of the window.
  /// - Returns: The number of layers with contents.
  /// - Throws: An issue when the hosting view has no layer.
  static func contentLayerCount(in harness: HostedViewHarness<some View>) throws -> Int {
    try layers(in: harness).filter { $0.contents != nil }.count
  }

  /// Whether SwiftUI holds a view for the system focus ring in the window.
  ///
  /// SwiftUI adds the view for a focusable view whose focus effect is on, in
  /// a window that is key or not. AppKit draws the ring only in a key window,
  /// so the view, and not a pixel, tells that the ring would show.
  ///
  /// - Parameter harness: The harness of the window.
  /// - Returns: `true` when a view of the window draws the system focus ring.
  static func holdsSystemFocusRing(in harness: HostedViewHarness<some View>) -> Bool {
    views(below: harness.hostingView).contains {
      String(describing: type(of: $0)) == systemFocusRingTypeName
    }
  }

  /// Each layer of the hosting view of `harness`, depth first.
  ///
  /// - Parameter harness: The harness of the window.
  /// - Returns: The layers.
  /// - Throws: An issue when the hosting view has no layer.
  private static func layers(in harness: HostedViewHarness<some View>) throws -> [CALayer] {
    sublayers(of: try #require(harness.hostingView.layer))
  }

  /// `layer` and each layer below it, depth first.
  ///
  /// - Parameter layer: The root of the layers.
  /// - Returns: The layers.
  private static func sublayers(of layer: CALayer) -> [CALayer] {
    [layer] + (layer.sublayers ?? []).flatMap(sublayers(of:))
  }

  /// `view` and each view below it, depth first.
  ///
  /// - Parameter view: The root of the views.
  /// - Returns: The views.
  private static func views(below view: NSView) -> [NSView] {
    [view] + view.subviews.flatMap(views(below:))
  }

  /// The fill colors of `layer` itself: a background color, and the fill of
  /// a shape layer.
  ///
  /// - Parameter layer: A layer of the window.
  /// - Returns: The colors.
  private static func fills(of layer: CALayer) -> [CGColor] {
    [layer.backgroundColor, (layer as? CAShapeLayer)?.fillColor].compactMap { $0 }
  }

  /// Whether two colors agree.
  ///
  /// - Parameters:
  ///   - first: The components of a color.
  ///   - second: The components of the other color.
  /// - Returns: Whether each pair differs by at most the tolerance of the bed.
  private static func isSame(_ first: [CGFloat], _ second: [CGFloat]) -> Bool {
    first.count == second.count
      && zip(first, second).allSatisfy { abs($0 - $1) <= componentTolerance }
  }
}

extension View {
  /// Puts this item above the reference fill of ``FocusLookBed``, under the
  /// accent of the bed in a window that appears active.
  ///
  /// - Returns: The item and the reference fill.
  func focusLookBed() -> some View {
    VStack {
      self
      Rectangle()
        .fill(FocusLookBed.focusedFill)
        .frame(width: FocusLookBed.referenceSide, height: FocusLookBed.referenceSide)
    }
    .environment(\.themeAccent, FocusLookBed.accent)
    .environment(\.appearsActive, true)
  }
}
