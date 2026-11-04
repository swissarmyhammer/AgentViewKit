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
    String(localized: "\(TaskListView.statusLabel(entry.status)): \(entry.content)", bundle: .module)
  }

  /// The text of the send state of a user message.
  ///
  /// - Parameter state: The send state.
  /// - Returns: The text, such as `Sent`.
  static func sendState(_ state: SendState) -> String {
    switch state {
    case .pending: String(localized: "Sending", bundle: .module)
    case .sent: String(localized: "Sent", bundle: .module)
    case .failed: String(localized: "Not sent", bundle: .module)
    }
  }

  /// The text of the state of a connection. A failed state tells its error.
  ///
  /// - Parameter state: The state.
  /// - Returns: The text, such as `Connected`.
  static func connectionState(_ state: ConnectionState) -> String {
    switch state {
    case .disconnected: String(localized: "Disconnected", bundle: .module)
    case .connecting: String(localized: "Connecting", bundle: .module)
    case .connected: String(localized: "Connected", bundle: .module)
    case .failed(let error): String(localized: "Failed: \(error.localizedDescription)", bundle: .module)
    }
  }
}
