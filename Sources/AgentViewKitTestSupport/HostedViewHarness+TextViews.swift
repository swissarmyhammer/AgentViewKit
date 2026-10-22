import AppKit
import SwiftUI

extension HostedViewHarness {
  /// The first editable text field or text view of `type` under the hosting
  /// view, in depth first order.
  ///
  /// A SwiftUI `TextField` shows an `NSTextField`, and a SwiftUI
  /// `TextEditor` shows an `NSTextView`. An EditorKit editor also shows an
  /// `NSTextView`, so pass `NSTextField.self` to find a text field in a view
  /// that also has an editor.
  ///
  /// - Parameter type: The class of the view to find. The default finds
  ///   each editable text field and text view.
  /// - Returns: The view, or `nil` when there is none.
  public func firstEditableTextView<Found: NSView>(of type: Found.Type = NSView.self) -> Found? {
    hostingView.descendants.lazy
      .filter(Self.isEditableText)
      .compactMap { $0 as? Found }
      .first
  }

  /// Each `NSView` under the hosting view whose accessibility identifier is
  /// `identifier`, in depth first order.
  ///
  /// An AppKit view in a representable can set its identifier with
  /// `NSView.setAccessibilityIdentifier(_:)`. That view is not always an
  /// element in the accessibility tree, so ``element(identifier:)`` cannot
  /// find it. For example, the EditorKit `DiffView` puts `editor.diff` on
  /// its AppKit views.
  ///
  /// - Parameter identifier: The accessibility identifier to find.
  /// - Returns: Each view with `identifier`, or an empty array.
  public func views(withAccessibilityIdentifier identifier: String) -> [NSView] {
    hostingView.descendants.filter { $0.accessibilityIdentifier() == identifier }
  }

  /// Each `NSView` of `type` under the hosting view, in depth first order.
  ///
  /// A test uses this function to read the frame of a view that has no
  /// accessibility identifier of its own. For example, the accessibility
  /// frame of a SwiftUI `ScrollView` leaves out its content insets, but the
  /// frame of its `NSScrollView` is the full frame of the list.
  ///
  /// - Parameter type: The class of the views to find.
  /// - Returns: Each view of `type`, or an empty array.
  public func views<Found: NSView>(of type: Found.Type) -> [Found] {
    hostingView.descendants.compactMap { $0 as? Found }
  }

  /// The frame of `view` in screen points, the coordinate space of
  /// ``frame(identifier:)``. The y axis goes up.
  ///
  /// - Parameter view: A view under the hosting view.
  /// - Returns: The frame of the view on the screen.
  public func screenFrame(of view: NSView) -> CGRect {
    window.convertToScreen(view.convert(view.bounds, to: nil))
  }

  /// Makes ``firstEditableTextView(of:)`` the first responder of the
  /// window, then makes a ``render()`` pass, so that typed keys go to it.
  ///
  /// - Parameter type: The class of the view to focus.
  /// - Returns: `true` when the harness found an editable view and it became
  ///   the first responder.
  @discardableResult
  public func focusFirstEditableTextView<Found: NSView>(of type: Found.Type = NSView.self) -> Bool {
    guard let view = firstEditableTextView(of: type) else { return false }
    let isFocused = window.makeFirstResponder(view)
    render()
    return isFocused
  }

  /// Whether `view` is an editable text field or text view.
  ///
  /// - Parameter view: The view to check.
  /// - Returns: `true` for an editable `NSTextField` or `NSTextView`.
  private static func isEditableText(_ view: NSView) -> Bool {
    switch view {
    case let field as NSTextField: field.isEditable
    case let textView as NSTextView: textView.isEditable
    default: false
    }
  }
}
