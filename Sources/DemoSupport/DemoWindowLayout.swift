import CoreGraphics

/// The sizes of the window of the demo app.
///
/// The app opens each new window at ``defaultSize``. With no default size,
/// SwiftUI gives the window the ideal size of its first content, and the
/// window of the ACP tab was 494 to 619 points high. While the in-memory
/// agent asks for a sign-in, the detail column needs more height than that:
/// the toolbar, the top bar of the thread, and a bottom bar with the state
/// banner, the sign-in card and the composer. The split view then made the
/// detail column taller than the window, and the thread list put its rows
/// out of view. Each show of the scroll-to-bottom pill changed the height of
/// the bottom bar again, and the layout of the window did not end (^66has33).
public enum DemoWindowLayout {
  /// The width of a new window, in points.
  public static let defaultWidth: CGFloat = 1100

  /// The height of a new window, in points. The detail column of the ACP tab
  /// then has room for its bars and for each row of the first turn.
  public static let defaultHeight: CGFloat = 900

  /// The size of a new window.
  public static let defaultSize = CGSize(width: defaultWidth, height: defaultHeight)

  /// The minimum width of the sidebar column of each tab, in points.
  public static let sidebarMinimumWidth: CGFloat = 200

  /// The ideal width of the sidebar column of each tab, in points.
  public static let sidebarIdealWidth: CGFloat = 240

  /// The frame of a window on the primary screen, in AppKit global
  /// coordinates (origin at the bottom-left corner of the primary screen, y
  /// up). The window has the default size, no larger than the visible frame,
  /// and stands at the top-left corner of the visible frame.
  ///
  /// The demo app uses this frame for `--primary-screen`
  /// (``DemoLaunchOptions/primaryScreenArgument``).
  ///
  /// - Parameter visibleFrame: The visible frame of the primary screen,
  ///   without the menu bar and the Dock, in AppKit global coordinates.
  /// - Returns: The frame of the window.
  public static func primaryScreenFrame(visibleFrame: CGRect) -> CGRect {
    let size = CGSize(
      width: min(defaultWidth, visibleFrame.width), height: min(defaultHeight, visibleFrame.height))
    return CGRect(
      origin: CGPoint(x: visibleFrame.minX, y: visibleFrame.maxY - size.height), size: size)
  }
}
