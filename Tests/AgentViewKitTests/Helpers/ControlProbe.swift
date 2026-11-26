import AgentViewKitTestSupport
import AppKit
import EditorStyle
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
  /// `identifier`. The search also reads the rows of a scroll area, such as
  /// the rows of a list.
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
      let elements = accessibilityElements(identifiedAs: identifier, under: hosting, includingScrollAreas: true)
      return elements.count == 1 ? elements.first.map(read) : nil
    }
  }

  /// The focus ring type of the outermost scroll view of `view`, and of each
  /// of its scrollers.
  ///
  /// EditorKit's `EditorScrollView` turns the system focus effect off for
  /// the scroll view, and sets the focus ring type `.none` on its scrollers,
  /// so neither draws the system focus ring. A SwiftUI `ScrollView`, and the
  /// scroll view of the table of a SwiftUI `List`, keep the default type.
  ///
  /// - Parameter view: The view to lay out.
  /// - Returns: The type of the scroll view, then the type of the vertical
  ///   scroller and of the horizontal scroller that the scroll view has, or
  ///   `nil` when the view lays out no scroll view.
  static func outerScrollRingTypes(in view: some View) async -> [NSFocusRingType]? {
    await host(view) { hosting in
      firstView(ofType: NSScrollView.self, in: hosting).map { scrollView in
        [scrollView.focusRingType]
          + [scrollView.verticalScroller, scrollView.horizontalScroller].compactMap { $0?.focusRingType }
      }
    }
  }

  /// Tells whether `view` lays out an AppKit table, the table of a SwiftUI
  /// `List`.
  ///
  /// - Parameter view: The view to lay out.
  /// - Returns: `true` when a view under the host is an `NSTableView`.
  static func laysOutATable(_ view: some View) async -> Bool {
    await host(view) { hosting in
      firstView(ofType: NSTableView.self, in: hosting) != nil
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
      nodes(under: hosting).compactMap(accessibilityLabel(of:))
    }
  }

  /// The names of the accessibility custom actions of each element of
  /// `view` that has a custom action, with the elements in each container.
  ///
  /// EditorKit's `ChoiceField` names each of its options as a custom action.
  /// A SwiftUI `Picker` has no custom action.
  ///
  /// - Parameter view: The view to lay out.
  /// - Returns: The action names of each element that has one or more, in
  ///   the order of the tree.
  static func customActionNames(in view: some View) async -> [[String]] {
    await host(view) { hosting in
      nodes(under: hosting).map(accessibilityCustomActionNames(of:)).filter { !$0.isEmpty }
    }
  }

  /// Each accessibility element under `hosting`, with the elements in each
  /// container, in the order of the tree.
  ///
  /// - Parameter hosting: The hosting view of the read.
  /// - Returns: The elements.
  private static func nodes(under hosting: NSView) -> [NSObject] {
    accessibilityNodes(of: hosting).flatMap { accessibilitySubtree(of: $0) }
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
    await frames(of: identifier, plain: view, themed: view.editorTheme(EnlargedRoleTheme(enlargedRole: role)))
  }

  /// The text style of the button captions of
  /// ``framesWithLargeButtonCaptions(of:in:)``: the largest system text
  /// style, much larger than the default `body` style of a caption.
  static let largeButtonCaptionStyle = Font.TextStyle.largeTitle

  /// The style tokens of ``framesWithLargeButtonCaptions(of:in:)``: the
  /// default tokens, with the button captions at ``largeButtonCaptionStyle``.
  static var largeButtonCaptionTokens: EditorStyle {
    var style = EditorStyle.default
    style.buttons.captionStyle = largeButtonCaptionStyle
    return style
  }

  /// The frame of the element `identifier` of `view` with the default style
  /// tokens, and with tokens that draw the caption of a button at
  /// ``largeButtonCaptionStyle``.
  ///
  /// A button of EditorKit draws its caption at the caption style of the
  /// button tokens of `\.editorStyle`, so it is larger with the second
  /// tokens. A system button does not read the tokens.
  ///
  /// - Parameters:
  ///   - identifier: The accessibility identifier of the element.
  ///   - view: The view to lay out.
  /// - Returns: The frame with the default tokens and the frame with the
  ///   large captions, or `nil` when a layout has no single element with the
  ///   identifier.
  static func framesWithLargeButtonCaptions(
    of identifier: String, in view: some View
  ) async -> (plain: CGRect, themed: CGRect)? {
    await frames(of: identifier, plain: view, themed: view.editorStyle(largeButtonCaptionTokens))
  }

  /// The frame of the element `identifier` in `plain` and in `themed`.
  ///
  /// - Parameters:
  ///   - identifier: The accessibility identifier of the element.
  ///   - plain: The view with no change of its look.
  ///   - themed: The same view with a changed look.
  /// - Returns: The two frames, or `nil` when a layout has no single element
  ///   with the identifier.
  private static func frames(
    of identifier: String, plain: some View, themed: some View
  ) async -> (plain: CGRect, themed: CGRect)? {
    guard
      let plainFrame = await read(identifier, in: plain, accessibilityFrame(of:)) ?? nil,
      let themedFrame = await read(identifier, in: themed, accessibilityFrame(of:)) ?? nil
    else { return nil }
    return (plainFrame, themedFrame)
  }
}
