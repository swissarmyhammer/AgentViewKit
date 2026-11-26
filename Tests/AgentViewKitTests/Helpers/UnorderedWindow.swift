import AppKit
import SwiftUI

/// A borderless window that is never ordered in, for a test that lays out a
/// view in a real window.
///
/// The window gives the view a window, so the views of EditorKit lay out as
/// they do in an app. No window shows, and no window takes the focus of the
/// screen. ARC is the one owner of the window.
@MainActor enum UnorderedWindow {
  /// Makes a window of `size` whose content view is `content`.
  ///
  /// - Parameters:
  ///   - content: The content view of the window.
  ///   - size: The size of the window, in points.
  /// - Returns: The window. The caller keeps it alive.
  static func make(holding content: NSView, size: CGSize) -> NSWindow {
    let window = NSWindow(
      contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: true)
    window.isReleasedWhenClosed = false
    window.contentView = content
    return window
  }

  /// Puts `root` in a hosting view, and puts the hosting view in a window of
  /// `size`.
  ///
  /// - Parameters:
  ///   - root: The root view of the hosting view.
  ///   - size: The size of the window, in points.
  /// - Returns: The hosting view and its window. The caller keeps both
  ///   alive, and closes the window with ``close(_:)``.
  static func mount<Root: View>(_ root: Root, size: CGSize) -> (hosting: NSHostingView<Root>, window: NSWindow) {
    let hosting = NSHostingView(rootView: root)
    return (hosting, make(holding: hosting, size: size))
  }

  /// Takes the content view out of `window`, and closes it.
  ///
  /// - Parameter window: The window.
  static func close(_ window: NSWindow) {
    window.contentView = nil
    window.close()
  }
}
