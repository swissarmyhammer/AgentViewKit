import AppKit
import EditorTestSupport
import SwiftUI

extension HostedViewHarness {
  /// Whether the test process has the keyboard focus of the user: the AVK-12
  /// check that a hosted test takes no focus.
  ///
  /// The process has the focus when it is the active application, when AppKit
  /// gives it a key window, or when the harness window is the key window. A
  /// test of the AVK-12 rule expects `false`. EditorKit's harness never makes
  /// its window key and sets no activation policy, and neither does this
  /// check: it only reads the state.
  ///
  /// The property reads `NSApplication.keyWindow`, the window that AppKit
  /// sends key events to. It does not read the `isKeyWindow` value of each
  /// window in `NSApplication.windows`: AppKit makes private windows whose
  /// class overrides `isKeyWindow`. For example, a timer of
  /// `NSTextInputContext` makes `NSCampoLightweightUIHostWindow` for the
  /// Writing Tools affordance of a focused text view. That window has no size
  /// and is never visible, and the application has no key window, but its
  /// `isKeyWindow` is `true`. A check of each window then fails at times that
  /// the tests do not control (^y2wzhsz).
  public var testProcessHasFocus: Bool {
    let application = NSApplication.shared
    return application.isActive || application.keyWindow != nil || window.isKeyWindow
  }
}
