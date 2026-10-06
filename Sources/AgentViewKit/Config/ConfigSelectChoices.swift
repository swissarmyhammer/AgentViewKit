import Foundation
import FoundationModelsACP
import OSLog

/// The log of the config option reads.
private let configChoicesLogger = Logger(subsystem: "AgentViewKit", category: "ConfigOptions")

/// The values that the user can select for a select config option
/// (update.md §4.2 "Last-value state").
///
/// The ACP v2 `SessionConfigSelectOptions` is a flat list or a list of
/// groups. FoundationModelsACP gives it as a raw JSON value, so
/// ``FoundationModelsACP/SessionConfigSelect/choices`` reads the ACP values
/// from that JSON each time a view asks. The kit keeps no copy.
enum ConfigSelectChoices: Hashable {
  /// A list of values with no groups.
  case flat([SessionConfigSelectOption])

  /// A list of values in groups, each with a header.
  case grouped([SessionConfigSelectGroup])

  /// Each value that the user can select, in order. For grouped choices,
  /// the values of each group follow the values of the group before it.
  var options: [SessionConfigSelectOption] {
    switch self {
    case .flat(let options): options
    case .grouped(let groups): groups.flatMap(\.options)
    }
  }
}

extension SessionConfigSelect {
  /// The JSON key that only a group of values has.
  private static let groupKey = "groupId"

  /// The values of the select option, read from the JSON value of
  /// ``options``.
  ///
  /// A list is grouped when its first item has a `groupId`. An empty list is
  /// flat.
  ///
  /// - Returns: The choices, or `nil` when the JSON value has neither shape.
  ///   The log records the failure.
  var choices: ConfigSelectChoices? {
    guard case .array(let items) = options else {
      configChoicesLogger.error("The select options are not a JSON list.")
      return nil
    }
    do {
      let data = try JSONEncoder().encode(options)
      if case .object(let first)? = items.first, first[Self.groupKey] != nil {
        return .grouped(try JSONDecoder().decode([SessionConfigSelectGroup].self, from: data))
      }
      return .flat(try JSONDecoder().decode([SessionConfigSelectOption].self, from: data))
    } catch {
      configChoicesLogger.error("The select options do not decode: \(String(describing: error), privacy: .public)")
      return nil
    }
  }
}
