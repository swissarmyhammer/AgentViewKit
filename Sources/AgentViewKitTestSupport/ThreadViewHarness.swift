import AgentViewKit
import AppKit
import SwiftUI

/// Mounts a thread view with the environment of a hosted test.
///
/// The harness gives `actions` to ``SwiftUI/EnvironmentValues/threadActions``
/// and `thread` to ``SwiftUI/EnvironmentValues/agentThread``, and turns the
/// animations off, so that a view that animates in shows at once.
///
/// - Parameters:
///   - size: The size of the content.
///   - actions: The actions that the view calls.
///   - thread: The thread of the environment, or `nil`.
///   - content: The builder of the view to mount.
/// - Returns: The harness.
public func threadViewHarness<Content: View>(
  size: CGSize = HostedViewHarness<Content>.defaultSize,
  actions: any AgentThreadActions,
  thread: AgentThread? = nil,
  @ViewBuilder content: () -> Content
) -> HostedViewHarness<some View> {
  HostedViewHarness(
    content()
      .threadActions(actions)
      .environment(\.agentThread, thread)
      .transaction { $0.disablesAnimations = true },
    size: size
  )
}

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
    Self.descendants(of: hostingView).lazy
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
    Self.descendants(of: hostingView).filter { $0.accessibilityIdentifier() == identifier }
  }

  /// Makes ``firstEditableTextView(of:)`` the first responder of the
  /// window, then pumps the run loop, so that typed keys go to it.
  ///
  /// - Parameter type: The class of the view to focus.
  /// - Returns: `true` when the harness found an editable view and it became
  ///   the first responder.
  @discardableResult
  public func focusFirstEditableTextView<Found: NSView>(of type: Found.Type = NSView.self) -> Bool {
    guard let view = firstEditableTextView(of: type) else { return false }
    let isFocused = window.makeFirstResponder(view)
    pump()
    return isFocused
  }

  /// Each view under `view`, in depth first order. The list does not have
  /// `view`.
  ///
  /// - Parameter view: The root of the search.
  /// - Returns: The flattened list of views.
  private static func descendants(of view: NSView) -> [NSView] {
    view.subviews.flatMap { [$0] + descendants(of: $0) }
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
