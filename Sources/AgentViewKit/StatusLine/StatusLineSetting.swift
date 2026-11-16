import Foundation
import FoundationModelsACP
import os

/// A wrong value in the `statusline` setting (D194 (c)).
nonisolated public struct StatusLineProblem: Hashable, Sendable, CustomStringConvertible {
  /// The key path of the value, from `statusline`, such as
  /// `["statusline", "directory", "truncation_length"]`.
  public let keyPath: [String]

  /// What is wrong.
  public let message: String

  public init(keyPath: [String], message: String) {
    self.keyPath = keyPath
    self.message = message
  }

  public var description: String {
    "\(keyPath.joined(separator: ".")): \(message)"
  }
}

/// The status line of a setting: the definition, and the problems of the
/// setting.
nonisolated public struct StatusLineResolution: Hashable, Sendable {
  /// The definition to show.
  public let definition: StatusLineDefinition

  /// The wrong values of the setting. Each wrong value keeps the value of the
  /// preset.
  public let problems: [StatusLineProblem]

  public init(definition: StatusLineDefinition, problems: [StatusLineProblem]) {
    self.definition = definition
    self.problems = problems
  }
}

/// The decode of the `statusline` setting (D194 (b), (c)).
///
/// - `preset` selects a builtin preset by name (``StatusLines``). With no
///   preset, the setting changes the default preset.
/// - Each other key changes the preset key by key: an object changes the
///   keys that it has, and a list or a value replaces.
/// - An unknown key, or a wrong value, is a ``StatusLineProblem`` with its
///   key path. A wrong value keeps the value of the preset for that module,
///   and the function logs each problem.
nonisolated public enum StatusLineSetting {
  /// The key of the setting.
  public static let key = "statusline"

  /// The key of the preset name.
  public static let presetKey = "preset"

  private static let logger = Logger(subsystem: "AgentViewKit", category: "StatusLine")

  /// Decodes the value of the `statusline` setting.
  ///
  /// - Parameter value: The value of the setting, or `nil` when the settings
  ///   have no `statusline` key.
  /// - Returns: The definition and the problems.
  public static func resolve(_ value: JSONValue?) -> StatusLineResolution {
    var resolver = Resolver()
    let resolution = resolver.resolve(value)
    for problem in resolution.problems {
      logger.error("The status line setting has a problem: \(problem.description, privacy: .public)")
    }
    return resolution
  }

  /// The state of one decode.
  private struct Resolver {
    var problems: [StatusLineProblem] = []

    mutating func resolve(_ value: JSONValue?) -> StatusLineResolution {
      var definition = StatusLines.defaultDefinition
      guard let value, value != .null else {
        return StatusLineResolution(definition: definition, problems: [])
      }
      guard case .object(let members) = value else {
        problem([key], "The value must be an object with keys such as preset and format.")
        return StatusLineResolution(definition: definition, problems: problems)
      }
      if let preset = members[presetKey] {
        if case .string(let name) = preset, let named = StatusLines.named(name) {
          definition = named
        } else {
          let names = StatusLines.builtin.map(\.name).joined(separator: ", ")
          problem([key, presetKey], "The preset must be one of \(names).")
        }
      }
      for (name, member) in members.sorted(by: { $0.key < $1.key }) where name != presetKey {
        apply(name, member, to: &definition)
      }
      return StatusLineResolution(definition: definition, problems: problems)
    }

    /// Changes one key of the definition.
    private mutating func apply(_ name: String, _ value: JSONValue, to definition: inout StatusLineDefinition) {
      let path = [key, name]
      switch name {
      case StatusLineDefinition.CodingKeys.format.stringValue:
        if let format = decode(StatusLineFormat.self, from: value, at: path) {
          do {
            try format.validate(references: StatusLineDefinition.references)
            definition.format = format
          } catch {
            problem(path, "\(error)")
          }
        }
      case StatusLineModuleID.directory.rawValue: merge(value, into: &definition.directory, at: path)
      case StatusLineModuleID.gitBranch.rawValue: merge(value, into: &definition.gitBranch, at: path)
      case StatusLineModuleID.gitStatus.rawValue: merge(value, into: &definition.gitStatus, at: path)
      case StatusLineModuleID.gitState.rawValue: merge(value, into: &definition.gitState, at: path)
      case StatusLineModuleID.languages.rawValue: merge(value, into: &definition.languages, at: path)
      case StatusLineModuleID.session.rawValue: merge(value, into: &definition.session, at: path)
      case StatusLineModuleID.agent.rawValue: merge(value, into: &definition.agent, at: path)
      case StatusLineModuleID.model.rawValue: merge(value, into: &definition.model, at: path)
      case StatusLineModuleID.context.rawValue: merge(value, into: &definition.context, at: path)
      case StatusLineModuleID.time.rawValue: merge(value, into: &definition.time, at: path)
      default:
        problem(path, "The key is unknown.")
      }
    }

    /// Changes the options of a module key by key. A wrong value keeps the
    /// options of the preset.
    private mutating func merge<Module: StatusLineModuleOptions>(
      _ value: JSONValue, into module: inout Module, at path: [String]
    ) {
      guard case .object = value else {
        problem(path, "The value must be an object of the options of the module.")
        return
      }
      let known = removingUnknownKeys(from: value, schema: Module.schema, at: path)
      guard let base = encode(module) else { return }
      let merged = Self.merged(base, with: known)
      if let decoded = decode(Module.self, from: merged, at: path) {
        module = decoded
      }
    }

    /// Records each unknown key of `value`, and gives the value with no
    /// unknown key.
    private mutating func removingUnknownKeys(from value: JSONValue, schema: StatusLineSchema, at path: [String])
      -> JSONValue
    {
      switch (schema, value) {
      case (.object(let keys), .object(let members)):
        var kept: [String: JSONValue] = [:]
        for (name, member) in members.sorted(by: { $0.key < $1.key }) {
          guard let child = keys[name] else {
            problem(path + [name], "The key is unknown.")
            continue
          }
          kept[name] = removingUnknownKeys(from: member, schema: child, at: path + [name])
        }
        return .object(kept)
      case (.list(let element), .array(let items)):
        return .array(
          items.enumerated().map { index, item in
            removingUnknownKeys(from: item, schema: element, at: path + [String(index)])
          })
      default:
        return value
      }
    }

    /// Joins an override into a base: an object joins key by key, and a list
    /// or a value replaces.
    static func merged(_ base: JSONValue, with override: JSONValue) -> JSONValue {
      guard case .object(var members) = base, case .object(let changes) = override else { return override }
      for (name, change) in changes {
        members[name] = members[name].map { merged($0, with: change) } ?? change
      }
      return .object(members)
    }

    private mutating func decode<T: Decodable>(_ type: T.Type, from value: JSONValue, at path: [String]) -> T? {
      do {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
      } catch let error as DecodingError {
        let (codingPath, message) = Self.describe(error)
        problem(path + codingPath.map(Self.keyName), message)
      } catch {
        problem(path, "\(error)")
      }
      return nil
    }

    private mutating func encode<T: Encodable>(_ value: T) -> JSONValue? {
      do {
        return try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(value))
      } catch {
        problem([key], "The kit cannot encode the preset: \(error)")
        return nil
      }
    }

    private mutating func problem(_ path: [String], _ message: String) {
      problems.append(StatusLineProblem(keyPath: path, message: message))
    }

    private static func keyName(_ key: any CodingKey) -> String {
      key.intValue.map(String.init) ?? key.stringValue
    }

    private static func describe(_ error: DecodingError) -> ([any CodingKey], String) {
      switch error {
      case .typeMismatch(let type, let context):
        return (context.codingPath, "The value must be \(typeName(type)).")
      case .valueNotFound(let type, let context):
        return (context.codingPath, "The value must be \(typeName(type)).")
      case .keyNotFound(let key, let context):
        return (context.codingPath + [key], "The key is necessary.")
      case .dataCorrupted(let context):
        return (context.codingPath, context.debugDescription)
      @unknown default:
        return ([], "\(error)")
      }
    }

    private static func typeName(_ type: Any.Type) -> String {
      switch type {
      case is String.Type: "text"
      case is Int.Type, is Double.Type: "a number"
      case is Bool.Type: "true or false"
      default: "a value of type \(type)"
      }
    }
  }
}
