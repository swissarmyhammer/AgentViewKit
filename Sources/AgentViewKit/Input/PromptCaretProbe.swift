import AppKit
import SwiftUI

/// Finds the caret of the text view of an ``EditorKitPromptEditor``, so that
/// the menu of the editor starts at the caret (^8mv9xpj).
///
/// EditorKit gives no caret geometry to SwiftUI. The editor takes typing in
/// an `NSTextView`, and the text view knows where its caret is
/// (`NSTextInputClient.firstRect(forCharacterRange:actualRange:)`). The
/// locator holds the probe view behind the editor, and finds the text view
/// whose visible frame holds the center of the probe.
final class PromptCaretLocator {
  /// The probe view behind the editor, or `nil` before SwiftUI makes it.
  weak var probe: NSView?

  /// The horizontal offset of the caret from the leading edge of the editor.
  ///
  /// - Returns: The offset in points, or `nil` when the probe is not in a
  ///   window or no text view is under it.
  func caretOffset() -> CGFloat? {
    guard let probe, let window = probe.window, let textView = Self.textView(behind: probe) else {
      return nil
    }
    let caret = textView.firstRect(forCharacterRange: textView.selectedRange(), actualRange: nil)
    return probe.convert(window.convertFromScreen(caret), from: nil).minX
  }

  /// The text view of the editor: the first text view under an ancestor of
  /// the probe whose visible frame holds the center of the probe.
  ///
  /// - Parameter probe: The probe view behind the editor.
  /// - Returns: The text view, or `nil` when there is none.
  static func textView(behind probe: NSView) -> NSTextView? {
    let center = probe.convert(CGPoint(x: probe.bounds.midX, y: probe.bounds.midY), to: nil)
    var ancestor = probe.superview
    while let view = ancestor {
      if let textView = textView(in: view, holding: center) {
        return textView
      }
      ancestor = view.superview
    }
    return nil
  }

  /// The first text view in `view` and its descendants whose visible frame
  /// holds `point`, in depth first order.
  ///
  /// - Parameters:
  ///   - view: The view to search.
  ///   - point: A point in the coordinates of the window.
  /// - Returns: The text view, or `nil` when there is none.
  private static func textView(in view: NSView, holding point: CGPoint) -> NSTextView? {
    if let textView = view as? NSTextView, textView.convert(textView.visibleRect, to: nil).contains(point) {
      return textView
    }
    return view.subviews.lazy.compactMap { textView(in: $0, holding: point) }.first
  }
}

/// The view behind an ``EditorKitPromptEditor`` that gives its
/// ``PromptCaretLocator`` the probe view.
///
/// The probe view has the frame of the editor. It takes no click and is no
/// accessibility element.
struct PromptCaretProbe: NSViewRepresentable {
  /// The locator that gets the probe view.
  let locator: PromptCaretLocator

  func makeNSView(context: Context) -> PromptCaretProbeView {
    let probe = PromptCaretProbeView(frame: .zero)
    locator.probe = probe
    return probe
  }

  func updateNSView(_ probe: PromptCaretProbeView, context: Context) {
    locator.probe = probe
  }
}

/// The probe view of a ``PromptCaretProbe``: a view that a click goes
/// through.
final class PromptCaretProbeView: NSView {
  override func hitTest(_ point: NSPoint) -> NSView? {
    nil
  }
}
