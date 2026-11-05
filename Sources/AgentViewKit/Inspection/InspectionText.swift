import EditorSwiftUI
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient

/// The text that the inspector rows of the client models show for a value
/// that has no text of its own.
enum InspectionText {
  /// The text of a message: its text blocks for the user, as the thread
  /// shows them, with a blank line between two blocks: the content form of
  /// `ThreadExporter.markdown(for:)`, which Copy gives.
  ///
  /// - Parameter content: The content blocks of the message.
  /// - Returns: The text, or an empty text when the message has no text.
  static func text(of content: [FoundationModelsACP.ContentBlock]) -> String {
    ThreadExporter.markdown(for: content)
  }

  /// The text of a location of a tool call: its path, then its line, as
  /// its location chip names it.
  ///
  /// - Parameter location: The location.
  /// - Returns: The text, such as `/tmp/Package.swift:12`.
  static func location(_ location: ToolCallLocation) -> String {
    ToolCallLocationChips.Location.text(path: location.path.rawValue, line: location.line.map { Int($0.rawValue) })
  }

  /// The text of a step of a plan: its status, then its content.
  ///
  /// - Parameters:
  ///   - entry: The step.
  ///   - locale: The locale of the text.
  /// - Returns: The text, such as `In progress: Write the tests`.
  static func step(_ entry: PlanEntry, locale: Locale = .autoupdatingCurrent) -> String {
    let status = EditorStatus(entry.status).summary
    return String(
      localized: "inspection.plan-step", defaultValue: "\(status): \(entry.content)", bundle: .module,
      locale: locale, comment: "A step of a plan in the inspector: its status, then its text.")
  }

  /// The text of the steps of a plan: the `plan-steps` template over the
  /// ``step(_:locale:)`` text of each step.
  ///
  /// - Parameters:
  ///   - entries: The steps, in plan order.
  ///   - templates: The templates of the text.
  ///   - locale: The locale of the text.
  /// - Returns: The text, one step on each line, or an empty text for a plan
  ///   with no step.
  static func steps(
    of entries: [PlanEntry], templates: TextTemplates = .bundled, locale: Locale = .autoupdatingCurrent
  ) -> String {
    templates.render(.planSteps, model: ["steps": entries.map { step($0, locale: locale) }])
  }
}
