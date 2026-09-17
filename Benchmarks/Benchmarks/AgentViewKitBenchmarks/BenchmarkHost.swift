//
// BenchmarkHost: an off-screen window that renders a SwiftUI view, and the
// probe views that count body evaluations in a release build.
//
// `AgentViewKitTestSupport.HostedViewHarness` runs the run loop for a fixed
// time. A benchmark must measure the render alone, so this host drains the
// pending run loop work, lays out, and draws, and then returns at once.
//
// `BodyEvaluationCounter` of AgentViewKit exists only in debug builds, and
// the benchmark package builds in release mode. Thus a probe view reads the
// same observed value as a view of the kit, and counts its own body
// evaluations. SwiftUI evaluates the probe when it evaluates the kit view
// that reads the same value.
//

import AppKit
import SwiftUI

/// The fixed values of ``BenchmarkHost`` and ``EvaluationProbe``.
///
/// A generic type cannot hold a stored static property, so the values are in
/// this separate type.
private enum HostConstants {
  /// The largest number of run loop passes in one render.
  static let maximumRunLoopPasses = 64

  /// The time that one run loop pass waits for work, in seconds: no wait.
  static let runLoopWait: CFTimeInterval = 0

  /// The x and y coordinate of a window that is outside each screen.
  static let offScreenCoordinate: CGFloat = -20_000

  /// The width and the height of a probe view: no size.
  static let probeSize: CGFloat = 0
}

/// An off-screen window that renders a SwiftUI view.
@MainActor
final class BenchmarkHost<Content: View> {

  /// The off-screen window.
  private let window: NSWindow

  /// The hosting view that shows the content.
  private let hostingView: NSHostingView<Content>

  /// Mounts `content` in an off-screen window and renders it.
  ///
  /// - Parameters:
  ///   - content: The view to mount.
  ///   - size: The size of the content.
  init(_ content: Content, size: CGSize) {
    _ = NSApplication.shared
    let frame = NSRect(origin: .zero, size: size)
    hostingView = NSHostingView(rootView: content)
    hostingView.frame = frame
    // The window has a fixed size, as the window of an app has. The content
    // does not set the size limits of the window.
    hostingView.sizingOptions = []
    window = NSWindow(contentRect: frame, styleMask: [.titled], backing: .buffered, defer: false)
    // ARC owns the window. The default value would release it a second time.
    window.isReleasedWhenClosed = false
    window.contentView = hostingView
    window.setFrameOrigin(
      NSPoint(x: HostConstants.offScreenCoordinate, y: HostConstants.offScreenCoordinate))
    window.orderFront(nil)
    render()
  }

  /// Does the pending SwiftUI updates, lays out the view, and draws it.
  ///
  /// The function runs the main run loop with no wait until the loop has no
  /// more work, so that SwiftUI applies each pending change.
  func render() {
    for _ in 0..<HostConstants.maximumRunLoopPasses {
      let result = CFRunLoopRunInMode(.defaultMode, HostConstants.runLoopWait, true)
      guard result == .handledSource else { break }
    }
    hostingView.layoutSubtreeIfNeeded()
    hostingView.displayIfNeeded()
  }

  /// Removes the window from the screen list and closes it.
  func close() {
    window.orderOut(nil)
    window.close()
  }
}

/// A count of body evaluations.
@MainActor
final class EvaluationCount {
  /// The evaluations since the last ``take()``.
  private var value = 0

  /// Adds one evaluation.
  func note() {
    value += 1
  }

  /// Gives the count and sets it to zero.
  ///
  /// - Returns: The evaluations since the last call.
  func take() -> Int {
    defer { value = 0 }
    return value
  }
}

/// A view with no size that reads one observed value and counts its body
/// evaluations.
struct EvaluationProbe<Model: AnyObject>: View {
  /// The object that holds the observed value.
  let model: Model

  /// The observed value that the probe reads.
  let property: PartialKeyPath<Model>

  /// The count of the body evaluations.
  let count: EvaluationCount

  var body: some View {
    count.note()
    _ = model[keyPath: property]
    return Color.clear.frame(width: HostConstants.probeSize, height: HostConstants.probeSize)
  }
}
