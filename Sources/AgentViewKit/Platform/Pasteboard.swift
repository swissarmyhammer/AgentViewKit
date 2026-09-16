import AppKit
import SwiftUI

/// The pasteboard that the kit writes to when a user copies text.
///
/// A view gets a `Pasteboard` from its host, so that a test can give it a
/// recording fake. `NSPasteboard` conforms, and the host usually gives
/// `NSPasteboard.general`.
///
/// ApplicationServices also declares a type with the name `Pasteboard`. Code
/// that imports AppKit and this module writes `AgentViewKit.Pasteboard`.
public protocol Pasteboard: AnyObject {
  /// Replaces the contents of the pasteboard with `text`, as a plain string.
  ///
  /// - Parameter text: The text to copy.
  func copyText(_ text: String)
}

extension NSPasteboard: Pasteboard {
  /// Clears the pasteboard, then writes `text` as the `.string` type.
  ///
  /// - Parameter text: The text to copy.
  public func copyText(_ text: String) {
    clearContents()
    setString(text, forType: .string)
  }
}

extension EnvironmentValues {
  /// The pasteboard that a copy action of the kit writes to.
  ///
  /// The value is `NSPasteboard.general` until a host or a test sets a
  /// different pasteboard.
  @Entry public var pasteboard: any Pasteboard = NSPasteboard.general
}
