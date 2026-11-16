import Foundation

/// One status line: a format of module references and the options of each
/// module (D194 (b)).
///
/// A definition is a preset of ``StatusLines``, or a preset that a setting
/// changes key by key (``StatusLineSetting``). The Codable form has the keys
/// of a setting, in snake case.
nonisolated public struct StatusLineDefinition: Codable, Hashable, Sendable {
  /// The name of the definition, such as `default`.
  public var name: String

  /// What the definition shows.
  public var description: String

  /// The format of the line: module references such as `$directory`.
  public var format: StatusLineFormat

  public var directory = DirectoryModule()
  public var gitBranch = GitBranchModule()
  public var gitStatus = GitStatusModule()
  public var gitState = GitStateModule()
  public var languages = LanguagesModule()
  public var session = SessionModule()
  public var agent = AgentModule()
  public var model = ModelModule()
  public var context = ContextModule()
  public var time = TimeModule()

  /// The references that the format of the line can use: the module names.
  public static let references = Set(StatusLineModuleID.allCases.map(\.rawValue))

  /// Makes a definition with the default options of each module.
  ///
  /// - Parameters:
  ///   - name: The name.
  ///   - description: What the definition shows.
  ///   - format: The format of the line.
  public init(name: String, description: String, format: StatusLineFormat) {
    self.name = name
    self.description = description
    self.format = format
  }

  enum CodingKeys: String, CodingKey {
    case name, description, format, directory, languages, session, agent, model, context, time
    case gitBranch = "git_branch"
    case gitStatus = "git_status"
    case gitState = "git_state"
  }

  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
    description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
    let format = try c.decode(StatusLineFormat.self, forKey: .format)
    do {
      try format.validate(references: Self.references)
    } catch let error as StatusLineFormat.ParseError {
      throw DecodingError.dataCorruptedError(forKey: .format, in: c, debugDescription: error.description)
    }
    self.format = format
    directory = try c.decodeIfPresent(DirectoryModule.self, forKey: .directory) ?? DirectoryModule()
    gitBranch = try c.decodeIfPresent(GitBranchModule.self, forKey: .gitBranch) ?? GitBranchModule()
    gitStatus = try c.decodeIfPresent(GitStatusModule.self, forKey: .gitStatus) ?? GitStatusModule()
    gitState = try c.decodeIfPresent(GitStateModule.self, forKey: .gitState) ?? GitStateModule()
    languages = try c.decodeIfPresent(LanguagesModule.self, forKey: .languages) ?? LanguagesModule()
    session = try c.decodeIfPresent(SessionModule.self, forKey: .session) ?? SessionModule()
    agent = try c.decodeIfPresent(AgentModule.self, forKey: .agent) ?? AgentModule()
    model = try c.decodeIfPresent(ModelModule.self, forKey: .model) ?? ModelModule()
    context = try c.decodeIfPresent(ContextModule.self, forKey: .context) ?? ContextModule()
    time = try c.decodeIfPresent(TimeModule.self, forKey: .time) ?? TimeModule()
  }

  /// The keys of the `statusline` setting, as the settings store of an
  /// agent checks them for unknown keys (D194 (c)).
  ///
  /// Each entry is the key path of one key below `statusline`, such as
  /// `["directory", "truncation_length"]`. A step `*` is each element of a
  /// list, such as `["languages", "languages", "*", "symbol"]`. An object
  /// key and each key below it are entries.
  public static let settingsKeys: [[String]] = keyPaths(of: settingsSchema, prefix: []).sorted {
    $0.joined(separator: ".") < $1.joined(separator: ".")
  }

  /// The shape of the keys of the `statusline` setting.
  public static var settingsSchema: StatusLineSchema {
    .object([
      StatusLineSetting.presetKey: .value,
      CodingKeys.format.stringValue: .value,
      StatusLineModuleID.directory.rawValue: DirectoryModule.schema,
      StatusLineModuleID.gitBranch.rawValue: GitBranchModule.schema,
      StatusLineModuleID.gitStatus.rawValue: GitStatusModule.schema,
      StatusLineModuleID.gitState.rawValue: GitStateModule.schema,
      StatusLineModuleID.languages.rawValue: LanguagesModule.schema,
      StatusLineModuleID.session.rawValue: SessionModule.schema,
      StatusLineModuleID.agent.rawValue: AgentModule.schema,
      StatusLineModuleID.model.rawValue: ModelModule.schema,
      StatusLineModuleID.context.rawValue: ContextModule.schema,
      StatusLineModuleID.time.rawValue: TimeModule.schema,
    ])
  }

  private static func keyPaths(of schema: StatusLineSchema, prefix: [String]) -> [[String]] {
    switch schema {
    case .value:
      return []
    case .list(let element):
      return keyPaths(of: element, prefix: prefix + ["*"])
    case .object(let keys):
      return keys.flatMap { key, child in [prefix + [key]] + keyPaths(of: child, prefix: prefix + [key]) }
    }
  }
}

/// The builtin status lines, as the model profiles of Router (D194 (b),
/// (f)).
nonisolated public enum StatusLines {
  /// The name of the preset that a setting with no preset uses.
  public static let defaultName = "default"

  /// The builtin presets: `default`, `minimal` and `full`.
  public static let builtin: [StatusLineDefinition] = [
    StatusLineDefinition(
      name: defaultName,
      description: "The folder, the git branch and status, the languages of the code and the session.",
      format: "$directory $git_branch$git_status$git_state $languages $session"),
    StatusLineDefinition(
      name: "minimal",
      description: "The folder, the git branch and the session.",
      format: "$directory $git_branch $session"),
    StatusLineDefinition(
      name: "full",
      description: "The default line with the model, the use of the context window and the time.",
      format: "$directory $git_branch$git_status$git_state $languages $session $model $context $time"),
  ]

  /// The default preset.
  public static var defaultDefinition: StatusLineDefinition {
    builtin[0]
  }

  /// The builtin preset with a name.
  ///
  /// - Parameter name: The name, such as `minimal`.
  /// - Returns: The preset, or `nil` when no builtin preset has the name.
  public static func named(_ name: String) -> StatusLineDefinition? {
    builtin.first { $0.name == name }
  }
}
