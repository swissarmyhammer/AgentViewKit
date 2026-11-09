#if DEBUG
  @testable import AgentViewKit
  import AppKit
  import EditorStyle
  import EditorTestSupport
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// Tests for the inset of the bars of a thread (^e0wdpmg, EditorKit
  /// `style.md`, rule 10).
  ///
  /// The thread puts no padding around its bars. The host pads them where it
  /// mounts the thread, with `.barInsets()`, which gives each bar the inset of
  /// the style (`EditorStyle.bar`). The tests read the frames that the views
  /// report to AppKit after one layout pass of the window: the screen frame of
  /// the hosting view, the accessibility frame of the header of the top bar,
  /// and the accessibility frame of a composer that fills the width of the
  /// bottom bar.
  @Suite(.serialized, .hostedSerially) @MainActor struct ThreadBarInsetsHostedTests {
    /// The largest difference, in points, between two distances that a test
    /// counts as the same. Layout rounds an edge to a pixel.
    static let tolerance: CGFloat = 0.5

    /// The accessibility identifier of the composer of the tests.
    static let composerIdentifier = "bar-insets-composer"

    /// The height of the composer of the tests, in points.
    static let composerHeight: CGFloat = 24

    /// The space between the edges of the hosting view and the header of the
    /// top bar and the composer of the bottom bar.
    struct BarEdges {
      /// The space from the leading edge to the header.
      let headerLeading: CGFloat
      /// The space from the top edge to the header.
      let headerTop: CGFloat
      /// The space from the leading edge to the composer.
      let composerLeading: CGFloat
      /// The space from the composer to the trailing edge.
      let composerTrailing: CGFloat
      /// The space from the composer to the bottom edge.
      let composerBottom: CGFloat
    }

    /// Mounts a thread with a header and a composer that fills the width of
    /// the bottom bar, with the bar inset of `insets`, and reads the space
    /// between the edges of the hosting view and the two bars.
    ///
    /// - Parameter insets: The bar inset that the host gives, or `nil` for a
    ///   host that writes no `.barInsets()`.
    /// - Returns: The spaces, in points.
    /// - Throws: An issue when the header or the composer is not there.
    static func barEdges(insets: EdgeInsets?) throws -> BarEdges {
      try BarInsetThreadMount.measure(insets: insets, size: ThreadFloatingControlsHostedTests.windowSize) {
        Color.clear
          .frame(maxWidth: .infinity)
          .frame(height: composerHeight)
          .accessibilityElement()
          .accessibilityIdentifier(composerIdentifier)
      } read: { frames in
        let view = frames.view
        let header = frames.header
        let composer = try frames.frame(identifier: composerIdentifier)
        // Screen points have y up: the top edge is the largest y.
        return BarEdges(
          headerLeading: frames.leading(of: header), headerTop: view.maxY - header.maxY,
          composerLeading: frames.leading(of: composer), composerTrailing: view.maxX - composer.maxX,
          composerBottom: composer.minY - view.minY)
      }
    }

    /// Requires that `actual` is `expected`, within ``tolerance``.
    ///
    /// - Parameters:
    ///   - actual: The measured space.
    ///   - expected: The space that the test expects.
    ///   - name: The name of the space, for the failure message.
    ///   - sourceLocation: The caller's location, for failure attribution.
    static func expectSpace(
      _ actual: CGFloat, is expected: CGFloat, _ name: String, sourceLocation: SourceLocation = #_sourceLocation
    ) {
      #expect(abs(actual - expected) <= tolerance, "\(name) \(actual), expected \(expected)", sourceLocation: sourceLocation)
    }

    /// With no `.barInsets()`, the bars have no inset: the header and the
    /// composer touch the edges of the thread.
    ///
    /// A production change that fails this test: a bar of the thread puts a
    /// padding of its own around its content.
    @Test func aHostWithNoBarInsetsGivesTheBarsNoInset() throws {
      let edges = try Self.barEdges(insets: nil)

      Self.expectSpace(edges.headerLeading, is: 0, "header leading")
      Self.expectSpace(edges.headerTop, is: 0, "header top")
      Self.expectSpace(edges.composerLeading, is: 0, "composer leading")
      Self.expectSpace(edges.composerTrailing, is: 0, "composer trailing")
      Self.expectSpace(edges.composerBottom, is: 0, "composer bottom")
    }

    /// With `.barInsets()`, the content of each bar stands at the bar inset of
    /// the style from the edges of the thread.
    ///
    /// A production change that fails this test: a bar of the thread does not
    /// read `\.barInsets`, or adds a padding of its own to it.
    @Test func theBarsStandAtTheBarInsetOfTheStyle() throws {
      let bar = EditorStyle.default.bar
      let edges = try Self.barEdges(insets: bar.insets)

      Self.expectSpace(edges.headerLeading, is: bar.horizontal, "header leading")
      Self.expectSpace(edges.headerTop, is: bar.vertical, "header top")
      Self.expectSpace(edges.composerLeading, is: bar.horizontal, "composer leading")
      Self.expectSpace(edges.composerTrailing, is: bar.horizontal, "composer trailing")
      Self.expectSpace(edges.composerBottom, is: bar.vertical, "composer bottom")
    }
  }
#endif
