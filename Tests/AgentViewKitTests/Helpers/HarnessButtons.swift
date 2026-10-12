import AgentViewKitTestSupport
import AppKit
import SwiftUI
import Testing

extension HostedViewHarness {
  /// Expects that the element with `identifier` is a button with `label` as
  /// its label. The tests that give a text button an icon use it, because the
  /// button must keep its text as its label.
  ///
  /// - Parameters:
  ///   - identifier: The accessibility identifier of the button.
  ///   - label: The label that the button must have.
  ///   - sourceLocation: The location of the caller, for the failure report.
  func expectButton(
    identifier: String, label: String, sourceLocation: SourceLocation = #_sourceLocation
  ) {
    let button = element(identifier: identifier)
    #expect(button?.role == NSAccessibility.Role.button.rawValue, "\(identifier)", sourceLocation: sourceLocation)
    #expect(button?.label == label, "\(identifier)", sourceLocation: sourceLocation)
  }
}
