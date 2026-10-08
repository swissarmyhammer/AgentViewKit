import Foundation
import FoundationModelsACP
import OSLog

nonisolated extension FoundationModelsACP.JSONValue {
  /// The indented JSON text of the value, with sorted object keys.
  ///
  /// The views show an ACP JSON value of a transcript entry with this text,
  /// such as the raw input of a tool call or the data of an error. The text is
  /// the same for equal values.
  ///
  /// A value from the wire always encodes. A value with a number that is not
  /// finite does not encode: that is a fault of the code that made it, so the
  /// property stops a debug build, records the fault, and gives `null`.
  var prettyPrinted: String {
    text(formatting: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
  }

  /// The compact JSON text of the value, with sorted object keys.
  ///
  /// The output has no whitespace and does not escape `/`. The demo agents
  /// write their frames with this text. A value with a number that is not
  /// finite gives `null`, as in ``prettyPrinted``.
  public var jsonString: String {
    text(formatting: [.sortedKeys, .withoutEscapingSlashes])
  }

  /// Encodes the value to JSON text.
  ///
  /// - Parameter formatting: The output format.
  /// - Returns: The JSON text, or `null` when the value does not encode.
  private func text(formatting: JSONEncoder.OutputFormatting) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = formatting
    do {
      return String(decoding: try encoder.encode(self), as: UTF8.self)
    } catch {
      assertionFailure("An ACP JSON value does not encode: \(error)")
      Self.textLogger.error("An ACP JSON value does not encode, so the view shows null: \(error, privacy: .public)")
      return Self.nullText
    }
  }

  /// The JSON text of `null`.
  private static let nullText = "null"

  /// The log of ``text(formatting:)``.
  private static let textLogger = Logger(subsystem: "AgentViewKit", category: "ACPJSONText")
}
