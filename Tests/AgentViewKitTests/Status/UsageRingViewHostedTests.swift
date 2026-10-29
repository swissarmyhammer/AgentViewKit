import AgentViewKitTestSupport
import AppKit
import EditorTestSupport
import SwiftUI
import Testing

@testable import AgentViewKit

/// The size and the accessibility label of a hosted ``UsageRingView``.
@Suite(.serialized, .hostedSerially) @MainActor struct UsageRingViewHostedTests {
  /// The accessibility identifier that the tests give the ring.
  static let identifier = "usage-ring-under-test"

  /// The part of the whole of the ring of the tests.
  static let numerator = 1200

  /// The whole of the ring of the tests.
  static let denominator = 4000

  /// The caption of the token counts.
  static let caption = "tokens"

  /// The small font of the size test.
  static let smallFont = Font.caption

  /// The large font of the size test.
  static let largeFont = Font.largeTitle

  /// The ring of the tests, with the short text style.
  static var ring: UsageRingView {
    UsageRingView(numerator: numerator, denominator: denominator, caption: caption)
  }

  /// The width that `view` asks for.
  ///
  /// - Parameter view: The view to measure.
  /// - Returns: The fitting width of the view, in points.
  static func fittingWidth(of view: some View) -> CGFloat {
    NSHostingView(rootView: view).fittingSize.width
  }

  /// The width of the gauge of the ring at a font: the width of the ring
  /// view less the width of its text. The space between the gauge and the
  /// text does not change with the font.
  ///
  /// - Parameter font: The font of the ring view.
  /// - Returns: The width, in points.
  static func gaugeWidth(font: Font) -> CGFloat {
    let text = UsageRingView.percentText(numerator: numerator, denominator: denominator)
    return fittingWidth(of: ring.font(font)) - fittingWidth(of: Text(text).monospacedDigit().font(font))
  }

  @Test func theGaugeGrowsWithTheFont() {
    #expect(Self.gaugeWidth(font: Self.largeFont) > Self.gaugeWidth(font: Self.smallFont))
  }

  @Test func theRingHasAnAccessibilityLabel() {
    let harness = HostedViewHarness(Self.ring.accessibilityIdentifier(Self.identifier))
    defer { harness.close() }
    harness.render()

    #expect(harness.element(identifier: Self.identifier)?.label == UsageRingView.labelText)
  }
}
