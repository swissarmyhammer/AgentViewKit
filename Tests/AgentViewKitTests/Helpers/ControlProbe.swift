import AgentViewKitTestSupport
import AppKit
import EditorTestSupport
import EditorTheme
import EditorSwiftUI
import SwiftUI

/// Reads one accessibility element of a control of the kit, and the frame
/// of that element with and with no theme.
///
/// The probe puts the view in a window that is never ordered in, so the
/// element has a frame, and no test shows a window or takes the focus of the
/// screen. The theme of a theme read is ``EnlargedRoleTheme``: a control
/// that draws in the enlarged font role of the theme is larger with that
/// theme.
@MainActor enum ControlProbe {
  /// The width of the window of each read, in points: wide enough for the
  /// widest control of a probe.
  static let hostWidth: CGFloat = 480

  /// The height of the window of each read, in points: tall enough for the
  /// tallest control of a probe.
  static let hostHeight: CGFloat = 320

  /// The size of the window of each read.
  static let hostSize = CGSize(width: hostWidth, height: hostHeight)

  /// Reads the one element of `view` whose accessibility identifier is
  /// `identifier`.
  ///
  /// - Parameters:
  ///   - identifier: The accessibility identifier of the element.
  ///   - view: The view to lay out.
  ///   - read: The read of the element.
  /// - Returns: What `read` returns, or `nil` when no single element has the
  ///   identifier.
  static func read<Value>(
    _ identifier: String, in view: some View, _ read: (NSObject) -> Value
  ) async -> Value? {
    await host(view) { hosting in
      let elements = accessibilityElements(identifiedAs: identifier, under: hosting)
      return elements.count == 1 ? elements.first.map(read) : nil
    }
  }

  /// Lays out `view` in a window that is never ordered in, and reads the
  /// hosting view while the accessibility tree is built.
  ///
  /// - Parameters:
  ///   - view: The view to lay out.
  ///   - read: The read of the hosting view.
  /// - Returns: What `read` returns.
  private static func host<Value>(_ view: some View, _ read: (NSView) -> Value) async -> Value {
    let hosting = NSHostingView(rootView: view.frame(width: hostSize.width, height: hostSize.height))
    let window = NSWindow(
      contentRect: NSRect(origin: .zero, size: hostSize), styleMask: [.titled], backing: .buffered, defer: true)
    window.isReleasedWhenClosed = false
    window.contentView = hosting
    defer { window.close() }
    StyleViewHost.layOut(hosting)
    return await withAccessibilityTree { read(hosting) }
  }

  /// The accessibility labels of each element of `view`, with the elements
  /// in each container.
  ///
  /// - Parameter view: The view to lay out.
  /// - Returns: The label of each element that has one, in the order of the
  ///   tree.
  static func labels(in view: some View) async -> [String] {
    await host(view) { hosting in
      accessibilityNodes(of: hosting)
        .flatMap { accessibilitySubtree(of: $0) }
        .compactMap(accessibilityLabel(of:))
    }
  }

  /// The frame of the element `identifier` of `view` with no theme, and with
  /// a theme that enlarges `role`.
  ///
  /// - Parameters:
  ///   - identifier: The accessibility identifier of the element.
  ///   - view: The view to lay out.
  ///   - role: The font role that the theme enlarges.
  /// - Returns: The frame with no theme and the frame with the theme, or
  ///   `nil` when a layout has no single element with the identifier.
  static func frames(
    of identifier: String, in view: some View, enlarging role: FontRole
  ) async -> (plain: CGRect, themed: CGRect)? {
    guard
      let plain = await read(identifier, in: view, accessibilityFrame(of:)) ?? nil,
      let themed = await read(
        identifier, in: view.editorTheme(EnlargedRoleTheme(enlargedRole: role)), accessibilityFrame(of:)) ?? nil
    else { return nil }
    return (plain, themed)
  }
}
