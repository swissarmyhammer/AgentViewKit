import AppKit
import EditorTestSupport
import SwiftUI
import Synchronization

@testable import AgentViewKit

/// A hover responder in the footer of a message row, which counts each hit
/// test that SwiftUI makes of it (card ^9ync5h3).
///
/// SwiftUI hit-tests a hover responder at the mouse location on each mouse
/// move. The hit test of a responder with a content shape asks the shape
/// for its path, so the number of path requests of the shape is the number
/// of hit tests. A draw of the row does not ask for the path. The footer
/// also holds a marker view of AppKit, so a test finds the place of the
/// responder in the window.
@MainActor final class HoverResponderProbe {
  /// The width of the responder, in points.
  static let width: CGFloat = 100

  /// The height of the responder, in points.
  static let height: CGFloat = 40

  /// The hit tests of the responder.
  let hitTests = HitTestCount()

  /// The footer of the message row, for ``StaticRowHost/messageFooter``:
  /// the marker view under a clear hover responder of the same size.
  var footer: ItemViewRenderer<MessageEntry> {
    let hitTests = hitTests
    return { _ in
      AnyView(
        ZStack {
          HoverProbeMarker()
          Color.clear
            .contentShape(CountingShape(hitTests: hitTests))
            .onContinuousHover { _ in }
        }
        .frame(width: Self.width, height: Self.height))
    }
  }

  /// The marker view of the responder in the view tree of `root`, or `nil`
  /// when the row shows no footer.
  ///
  /// - Parameter root: The view whose tree holds the footer.
  /// - Returns: The marker view.
  func marker(in root: NSView) -> NSView? {
    views(ofType: HoverProbeMarkerView.self, in: root).first
  }
}

/// A number of hit tests, which a shape counts off the main actor.
nonisolated final class HitTestCount: Sendable {
  /// The number of hit tests.
  private let count = Mutex(0)

  /// The number of hit tests so far.
  var value: Int {
    count.withLock { $0 }
  }

  /// Records one hit test.
  func note() {
    count.withLock { $0 += 1 }
  }

  /// Sets the number back to zero.
  func reset() {
    count.withLock { $0 = 0 }
  }
}

/// A rectangle that records each request of its path, as the hit test of
/// its responder makes it.
nonisolated struct CountingShape: Shape {
  /// The count of the path requests.
  let hitTests: HitTestCount

  /// Records the request, and gives the rectangle of `rect`.
  ///
  /// - Parameter rect: The frame of the shape.
  /// - Returns: The rectangle.
  func path(in rect: CGRect) -> Path {
    hitTests.note()
    return Path(rect)
  }
}

/// An AppKit view that marks the place of the hover responder of a
/// ``HoverResponderProbe`` in the window.
struct HoverProbeMarker: NSViewRepresentable {
  /// Makes the marker view.
  ///
  /// - Parameter context: The context of the representable.
  /// - Returns: The marker view.
  func makeNSView(context: Context) -> HoverProbeMarkerView {
    HoverProbeMarkerView()
  }

  /// Changes nothing: the marker has no state.
  ///
  /// - Parameters:
  ///   - nsView: The marker view.
  ///   - context: The context of the representable.
  func updateNSView(_ nsView: HoverProbeMarkerView, context: Context) {}
}

/// The view of a ``HoverProbeMarker``.
final class HoverProbeMarkerView: NSView {}
