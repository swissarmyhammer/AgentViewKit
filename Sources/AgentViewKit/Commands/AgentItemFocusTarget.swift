import AppKit
import SwiftUI

/// The view behind one item of a thread that takes the keyboard focus of the
/// item (AVK-7d).
///
/// A `nav.*` move or a jump of EditorKit puts the focus on an item scope with
/// `GeometryRegistry.requestFocus(at:)`. That call gives the first responder
/// to the focusable view that holds the center of the scope. A message row
/// has no such view: its text views are smaller than the row. Thus
/// ``AgentItemScope`` puts this view behind the item, with the size of the
/// item, and the focus stays in the item that the move or the jump selects.
///
/// The view is not a click target and not a key view, so a click and the Tab
/// key work as before. It shows the focus ring of the system while it has
/// the focus.
struct AgentItemFocusTarget: NSViewRepresentable {
  func makeNSView(context: Context) -> AgentItemFocusView {
    AgentItemFocusView(frame: .zero)
  }

  func updateNSView(_ nsView: AgentItemFocusView, context: Context) {}
}

/// The responder of an ``AgentItemFocusTarget``.
final class AgentItemFocusView: NSView {
  override var acceptsFirstResponder: Bool { true }

  /// The view is not in the key view loop, so the Tab key does not stop on
  /// each item.
  override var canBecomeKeyView: Bool { false }

  /// The view is never a click target. A click goes to the content of the
  /// item in front of it.
  ///
  /// - Parameter point: The point to test, in the coordinates of the
  ///   superview.
  /// - Returns: `nil`, always.
  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override var focusRingMaskBounds: NSRect { bounds }

  override func drawFocusRingMask() {
    bounds.fill()
  }
}
