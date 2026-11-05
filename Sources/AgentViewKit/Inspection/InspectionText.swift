import EditorSwiftUI
import FoundationModelsACP
import FoundationModelsACPClient

/// The text that the inspector rows of the client models show for a value
/// that has no text of its own.
enum InspectionText {
  /// The separator between two text blocks of a message.
  private static let blockSeparator = "\n\n"

  /// The text of a message: its text blocks for the user, as the thread
  /// shows them, with a blank line between two blocks.
  ///
  /// - Parameter content: The content blocks of the message.
  /// - Returns: The text, or an empty text when the message has no text.
  static func text(of content: [FoundationModelsACP.ContentBlock]) -> String {
    ThreadExporter.texts(of: content).joined(separator: blockSeparator)
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
  /// - Parameter entry: The step.
  /// - Returns: The text, such as `In progress: Write the tests`.
  static func step(_ entry: PlanEntry) -> String {
    let status = EditorStatus(entry.status).summary
    return String(
      localized: "inspection.plan-step", defaultValue: "\(status): \(entry.content)", bundle: .module,
      comment: "A step of a plan in the inspector: its status, then its text.")
  }
}
