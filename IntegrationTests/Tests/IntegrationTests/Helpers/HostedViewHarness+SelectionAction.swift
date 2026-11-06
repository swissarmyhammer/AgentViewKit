import EditorTestSupport
import SwiftUI

@testable import AgentViewKit

// The one way the AVK hosted suites change the file selection: the named
// accessibility action of a file view, Select, Add to Selection or Extend
// Selection, which does what a click, a Command-click and a Shift-click do.
extension HostedViewHarness {
  /// Runs the named accessibility action of `change` on the file view of
  /// `identifier`.
  ///
  /// - Parameters:
  ///   - change: The kind of the press.
  ///   - identifier: The accessibility identifier of the file view.
  /// - Throws: The error of the action.
  func performSelection(_ change: AttachmentSelectionChange, on identifier: String) throws {
    try perform(.custom(change.actionName), on: identifier)
  }
}
