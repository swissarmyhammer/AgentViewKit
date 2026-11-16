import Foundation

// The typed options of each module of the status line (D194 (g)). The keys
// are the keys of starship and of `sah statusline`, in snake case, so that a
// user who knows starship knows the keys. Each module has `format`, `style`
// and `disabled`. A key that a setting leaves out keeps the value of the
// preset.

/// The name of a module of the status line. The raw value is the key of the
/// module in a setting and its reference in the format of the line, such as
/// `$git_branch`.
nonisolated public enum StatusLineModuleID: String, CaseIterable, Hashable, Sendable, Codable {
  case directory
  case gitBranch = "git_branch"
  case gitStatus = "git_status"
  case gitState = "git_state"
  case languages
  case session
  case agent
  case model
  case context
  case time
}

/// The shape of the keys of a setting: the check of unknown keys
/// (``StatusLineSetting``) and ``StatusLineDefinition/settingsKeys`` read it.
nonisolated public indirect enum StatusLineSchema: Hashable, Sendable {
  /// A value with no keys of its own: text, a number, a flag.
  case value
  /// An object with these keys.
  case object([String: StatusLineSchema])
  /// A list of values of one shape.
  case list(StatusLineSchema)
}

/// The options of one module.
nonisolated public protocol StatusLineModuleOptions: Codable, Hashable, Sendable {
  /// The module.
  static var id: StatusLineModuleID { get }

  /// The references that the format of the module can use, such as
  /// `branch`.
  static var references: Set<String> { get }

  /// The keys of the module.
  static var schema: StatusLineSchema { get }

  /// The format of the module.
  var format: StatusLineFormat { get }

  /// The style of the module.
  var style: StatusLineStyle { get }

  /// `true` when the module shows nothing.
  var disabled: Bool { get }
}

/// A decoder helper: the value of a key, or the default when the key is
/// absent.
nonisolated extension KeyedDecodingContainer {
  fileprivate func value<T: Decodable>(_ key: Key, or fallback: T) throws -> T {
    try decodeIfPresent(T.self, forKey: key) ?? fallback
  }

  /// The format of a key, checked against the references that it can use.
  fileprivate func format(_ key: Key, or fallback: StatusLineFormat, references: Set<String>) throws
    -> StatusLineFormat
  {
    let format = try value(key, or: fallback)
    do {
      try format.validate(references: references)
    } catch let error as StatusLineFormat.ParseError {
      throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: error.description)
    }
    return format
  }
}

/// The schema of an object with value keys only.
nonisolated private func valueKeys<Key: CodingKey & CaseIterable>(_: Key.Type) -> [String: StatusLineSchema] {
  Dictionary(uniqueKeysWithValues: Key.allCases.map { ($0.stringValue, StatusLineSchema.value) })
}

// MARK: - directory

/// The options of the `directory` module: the working folder of the session.
///
/// The path has `~` (``homeSymbol``) for the home folder. With
/// ``truncateToRepo``, the folder of the git repository root is the first
/// part. The path keeps at most ``truncationLength`` parts, and each parent
/// part has ``fishStylePwdDirLength`` letters. The repository root shows in
/// ``repoRootStyle``.
nonisolated public struct DirectoryModule: StatusLineModuleOptions {
  /// One substitution of the path: the text `from` becomes `to`.
  public struct Substitution: Codable, Hashable, Sendable {
    /// The text to find.
    public var from: String
    /// The text that replaces it.
    public var to: String

    public init(from: String, to: String) {
      self.from = from
      self.to = to
    }
  }

  public static let id = StatusLineModuleID.directory
  public static let references: Set<String> = ["path"]
  public static var schema: StatusLineSchema {
    var keys = valueKeys(CodingKeys.self)
    keys[CodingKeys.substitutions.stringValue] = .list(.object(["from": .value, "to": .value]))
    return .object(keys)
  }

  public var format: StatusLineFormat = "$path"
  /// The path is bold text in the primary color of the theme, as a
  /// headline (the user, 2026-11-16).
  public var style: StatusLineStyle = "bold"
  public var disabled = false
  /// The most parts of the path that show, or 0 for no limit. The default
  /// shows the whole path: the fish-style parents keep it short.
  public var truncationLength = 0
  /// `true` to start the path at the folder of the git repository root. The
  /// default shows the path from `~` or `/`, so that it reads as a path
  /// (the user, 2026-11-16).
  public var truncateToRepo = false
  /// The text in front of a truncated path.
  public var truncationSymbol = ""
  /// The text for the home folder.
  public var homeSymbol = "~"
  /// The letters of each parent part, or 0 to keep each part whole.
  public var fishStylePwdDirLength = 1
  /// The substitutions of the path, in order.
  public var substitutions: [Substitution] = []
  /// The style of the repository root.
  public var repoRootStyle: StatusLineStyle = "bold"

  public init() {}

  enum CodingKeys: String, CodingKey, CaseIterable {
    case format, style, disabled, substitutions
    case truncationLength = "truncation_length"
    case truncateToRepo = "truncate_to_repo"
    case truncationSymbol = "truncation_symbol"
    case homeSymbol = "home_symbol"
    case fishStylePwdDirLength = "fish_style_pwd_dir_length"
    case repoRootStyle = "repo_root_style"
  }

  public init(from decoder: any Decoder) throws {
    let defaults = Self()
    let c = try decoder.container(keyedBy: CodingKeys.self)
    format = try c.format(.format, or: defaults.format, references: Self.references)
    style = try c.value(.style, or: defaults.style)
    disabled = try c.value(.disabled, or: defaults.disabled)
    truncationLength = try c.value(.truncationLength, or: defaults.truncationLength)
    truncateToRepo = try c.value(.truncateToRepo, or: defaults.truncateToRepo)
    truncationSymbol = try c.value(.truncationSymbol, or: defaults.truncationSymbol)
    homeSymbol = try c.value(.homeSymbol, or: defaults.homeSymbol)
    fishStylePwdDirLength = try c.value(.fishStylePwdDirLength, or: defaults.fishStylePwdDirLength)
    substitutions = try c.value(.substitutions, or: defaults.substitutions)
    repoRootStyle = try c.value(.repoRootStyle, or: defaults.repoRootStyle)
  }
}

// MARK: - git_branch

/// The options of the `git_branch` module: the branch, or the short commit
/// hash when the HEAD is detached.
nonisolated public struct GitBranchModule: StatusLineModuleOptions {
  public static let id = StatusLineModuleID.gitBranch
  public static let references: Set<String> = ["symbol", "branch"]
  public static var schema: StatusLineSchema {
    var keys = valueKeys(CodingKeys.self)
    keys[CodingKeys.ignoreBranches.stringValue] = .list(.value)
    return .object(keys)
  }

  public var format: StatusLineFormat = "$symbol $branch"
  public var style: StatusLineStyle = "purple"
  public var disabled = false
  /// The symbol in front of the branch.
  public var symbol: StatusLineSymbol = "sf:arrow.triangle.branch"
  /// The most characters of the branch name, or `nil` for no limit.
  public var truncationLength: Int?
  /// The text at the end of a truncated name.
  public var truncationSymbol = "…"
  /// `true` to show nothing when the HEAD is detached.
  public var onlyAttached = false
  /// The branches that show nothing.
  public var ignoreBranches: [String] = []

  public init() {}

  enum CodingKeys: String, CodingKey, CaseIterable {
    case format, style, disabled, symbol
    case truncationLength = "truncation_length"
    case truncationSymbol = "truncation_symbol"
    case onlyAttached = "only_attached"
    case ignoreBranches = "ignore_branches"
  }

  public init(from decoder: any Decoder) throws {
    let defaults = Self()
    let c = try decoder.container(keyedBy: CodingKeys.self)
    format = try c.format(.format, or: defaults.format, references: Self.references)
    style = try c.value(.style, or: defaults.style)
    disabled = try c.value(.disabled, or: defaults.disabled)
    symbol = try c.value(.symbol, or: defaults.symbol)
    truncationLength = try c.decodeIfPresent(Int.self, forKey: .truncationLength) ?? defaults.truncationLength
    truncationSymbol = try c.value(.truncationSymbol, or: defaults.truncationSymbol)
    onlyAttached = try c.value(.onlyAttached, or: defaults.onlyAttached)
    ignoreBranches = try c.value(.ignoreBranches, or: defaults.ignoreBranches)
  }
}

// MARK: - git_status

/// The options of the `git_status` module: the counts of the work tree and
/// the index, the stash, and ahead and behind.
///
/// Each count symbol is a format with `${count}`. The diverged symbol has
/// `${ahead_count}` and `${behind_count}`. `$all_status` is the counts in
/// the order conflicted, stashed, deleted, renamed, staged, modified,
/// untracked. A count of zero shows nothing.
nonisolated public struct GitStatusModule: StatusLineModuleOptions {
  public static let id = StatusLineModuleID.gitStatus
  public static let references: Set<String> = [
    "all_status", "ahead_behind", "conflicted", "stashed", "deleted", "renamed", "staged", "modified", "untracked",
  ]
  public static var schema: StatusLineSchema { .object(valueKeys(CodingKeys.self)) }

  /// The references of a count symbol.
  public static let countReferences: Set<String> = ["count"]

  /// The references of the diverged symbol.
  public static let divergedReferences: Set<String> = ["ahead_count", "behind_count"]

  public var format: StatusLineFormat = "$all_status$ahead_behind"
  public var style: StatusLineStyle = "red bold"
  public var disabled = false
  public var conflicted: StatusLineFormat = "=${count}"
  public var ahead: StatusLineFormat = "⇡${count}"
  public var behind: StatusLineFormat = "⇣${count}"
  public var diverged: StatusLineFormat = "⇕⇡${ahead_count}⇣${behind_count}"
  public var upToDate: StatusLineFormat = ""
  public var untracked: StatusLineFormat = "?${count}"
  public var stashed: StatusLineFormat = "\\$${count}"
  public var modified: StatusLineFormat = "!${count}"
  public var staged: StatusLineFormat = "+${count}"
  public var renamed: StatusLineFormat = "»${count}"
  public var deleted: StatusLineFormat = "✘${count}"
  /// `true` to leave changes in submodules out of the counts.
  public var ignoreSubmodules = false

  public init() {}

  enum CodingKeys: String, CodingKey, CaseIterable {
    case format, style, disabled, conflicted, ahead, behind, diverged, untracked, stashed, modified, staged,
      renamed, deleted
    case upToDate = "up_to_date"
    case ignoreSubmodules = "ignore_submodules"
  }

  public init(from decoder: any Decoder) throws {
    let defaults = Self()
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let counts = Self.countReferences
    format = try c.format(.format, or: defaults.format, references: Self.references)
    style = try c.value(.style, or: defaults.style)
    disabled = try c.value(.disabled, or: defaults.disabled)
    conflicted = try c.format(.conflicted, or: defaults.conflicted, references: counts)
    ahead = try c.format(.ahead, or: defaults.ahead, references: counts)
    behind = try c.format(.behind, or: defaults.behind, references: counts)
    diverged = try c.format(.diverged, or: defaults.diverged, references: Self.divergedReferences)
    upToDate = try c.format(.upToDate, or: defaults.upToDate, references: [])
    untracked = try c.format(.untracked, or: defaults.untracked, references: counts)
    stashed = try c.format(.stashed, or: defaults.stashed, references: counts)
    modified = try c.format(.modified, or: defaults.modified, references: counts)
    staged = try c.format(.staged, or: defaults.staged, references: counts)
    renamed = try c.format(.renamed, or: defaults.renamed, references: counts)
    deleted = try c.format(.deleted, or: defaults.deleted, references: counts)
    ignoreSubmodules = try c.value(.ignoreSubmodules, or: defaults.ignoreSubmodules)
  }
}

// MARK: - git_state

/// The options of the `git_state` module: a rebase, merge, cherry-pick,
/// revert, bisect or `am` in progress, with its progress when git records it.
nonisolated public struct GitStateModule: StatusLineModuleOptions {
  public static let id = StatusLineModuleID.gitState
  public static let references: Set<String> = ["state", "progress_current", "progress_total"]
  public static var schema: StatusLineSchema { .object(valueKeys(CodingKeys.self)) }

  public var format: StatusLineFormat = "($state( $progress_current/$progress_total))"
  public var style: StatusLineStyle = "yellow bold"
  public var disabled = false
  public var rebase = "REBASING"
  public var merge = "MERGING"
  public var revert = "REVERTING"
  public var cherryPick = "CHERRY-PICKING"
  public var bisect = "BISECTING"
  public var am = "AM"
  public var amOrRebase = "AM/REBASE"

  public init() {}

  enum CodingKeys: String, CodingKey, CaseIterable {
    case format, style, disabled, rebase, merge, revert, bisect, am
    case cherryPick = "cherry_pick"
    case amOrRebase = "am_or_rebase"
  }

  public init(from decoder: any Decoder) throws {
    let defaults = Self()
    let c = try decoder.container(keyedBy: CodingKeys.self)
    format = try c.format(.format, or: defaults.format, references: Self.references)
    style = try c.value(.style, or: defaults.style)
    disabled = try c.value(.disabled, or: defaults.disabled)
    rebase = try c.value(.rebase, or: defaults.rebase)
    merge = try c.value(.merge, or: defaults.merge)
    revert = try c.value(.revert, or: defaults.revert)
    cherryPick = try c.value(.cherryPick, or: defaults.cherryPick)
    bisect = try c.value(.bisect, or: defaults.bisect)
    am = try c.value(.am, or: defaults.am)
    amOrRebase = try c.value(.amOrRebase, or: defaults.amOrRebase)
  }
}

// MARK: - languages

/// The options of the `languages` module: one symbol for each language of
/// the code in the folder, the language with the most files first.
nonisolated public struct LanguagesModule: StatusLineModuleOptions {
  /// One language, as a language module of starship.
  public struct Language: Codable, Hashable, Sendable {
    /// The name of the language, such as `swift`.
    public var name: String
    /// The symbol of the language.
    public var symbol: StatusLineSymbol
    /// The file name extensions of the language, with no dot.
    public var detectExtensions: [String]
    /// The file names that mark the language, such as `Package.swift`.
    public var detectFiles: [String]
    /// The folder names that mark the language, such as `node_modules`.
    public var detectFolders: [String]
    /// `true` to leave the language out.
    public var disabled: Bool

    public init(
      name: String, symbol: StatusLineSymbol, detectExtensions: [String] = [], detectFiles: [String] = [],
      detectFolders: [String] = [], disabled: Bool = false
    ) {
      self.name = name
      self.symbol = symbol
      self.detectExtensions = detectExtensions
      self.detectFiles = detectFiles
      self.detectFolders = detectFolders
      self.disabled = disabled
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
      case name, symbol, disabled
      case detectExtensions = "detect_extensions"
      case detectFiles = "detect_files"
      case detectFolders = "detect_folders"
    }

    public init(from decoder: any Decoder) throws {
      let c = try decoder.container(keyedBy: CodingKeys.self)
      name = try c.decode(String.self, forKey: .name)
      symbol = try c.value(.symbol, or: .text(name))
      detectExtensions = try c.value(.detectExtensions, or: [])
      detectFiles = try c.value(.detectFiles, or: [])
      detectFolders = try c.value(.detectFolders, or: [])
      disabled = try c.value(.disabled, or: false)
    }

    static var schema: StatusLineSchema {
      var keys = valueKeys(CodingKeys.self)
      for key in [CodingKeys.detectExtensions, .detectFiles, .detectFolders] {
        keys[key.stringValue] = .list(.value)
      }
      return .object(keys)
    }
  }

  public static let id = StatusLineModuleID.languages
  public static let references: Set<String> = ["symbols"]
  public static var schema: StatusLineSchema {
    var keys = valueKeys(CodingKeys.self)
    keys[CodingKeys.languages.stringValue] = .list(Language.schema)
    return .object(keys)
  }

  public var format: StatusLineFormat = "$symbols"
  public var style: StatusLineStyle = "secondary"
  public var disabled = false
  /// The most languages that show.
  public var maximum = 4
  /// The fewest files of a language that show it.
  public var minimumFiles = 1
  /// The languages, in order. A list in a setting replaces this list.
  public var languages: [Language] = StatusLineLanguages.builtin

  public init() {}

  enum CodingKeys: String, CodingKey, CaseIterable {
    case format, style, disabled, maximum, languages
    case minimumFiles = "minimum_files"
  }

  public init(from decoder: any Decoder) throws {
    let defaults = Self()
    let c = try decoder.container(keyedBy: CodingKeys.self)
    format = try c.format(.format, or: defaults.format, references: Self.references)
    style = try c.value(.style, or: defaults.style)
    disabled = try c.value(.disabled, or: defaults.disabled)
    maximum = try c.value(.maximum, or: defaults.maximum)
    minimumFiles = try c.value(.minimumFiles, or: defaults.minimumFiles)
    languages = try c.value(.languages, or: defaults.languages)
  }
}

// MARK: - session

/// The options of the `session` module: the title of the session, and for a
/// child session the path of crumbs to it.
nonisolated public struct SessionModule: StatusLineModuleOptions {
  public static let id = StatusLineModuleID.session
  public static let references: Set<String> = ["title"]
  public static var schema: StatusLineSchema { .object(valueKeys(CodingKeys.self)) }

  public var format: StatusLineFormat = "$title"
  public var style: StatusLineStyle = "primary"
  public var disabled = false
  /// The most characters of a title, or `nil` for no limit.
  public var truncationLength: Int? = 40
  /// `true` to show the crumbs of the path to a child session.
  public var showsPath = true

  public init() {}

  enum CodingKeys: String, CodingKey, CaseIterable {
    case format, style, disabled
    case truncationLength = "truncation_length"
    case showsPath = "shows_path"
  }

  public init(from decoder: any Decoder) throws {
    let defaults = Self()
    let c = try decoder.container(keyedBy: CodingKeys.self)
    format = try c.format(.format, or: defaults.format, references: Self.references)
    style = try c.value(.style, or: defaults.style)
    disabled = try c.value(.disabled, or: defaults.disabled)
    truncationLength = try c.decodeIfPresent(Int.self, forKey: .truncationLength) ?? defaults.truncationLength
    showsPath = try c.value(.showsPath, or: defaults.showsPath)
  }
}

// MARK: - agent

/// The options of the `agent` module: the name and the version of the agent.
nonisolated public struct AgentModule: StatusLineModuleOptions {
  public static let id = StatusLineModuleID.agent
  public static let references: Set<String> = ["name", "version"]
  public static var schema: StatusLineSchema { .object(valueKeys(CodingKeys.self)) }

  public var format: StatusLineFormat = "$name( $version)"
  public var style: StatusLineStyle = "secondary"
  public var disabled = false

  public init() {}

  enum CodingKeys: String, CodingKey, CaseIterable {
    case format, style, disabled
  }

  public init(from decoder: any Decoder) throws {
    let defaults = Self()
    let c = try decoder.container(keyedBy: CodingKeys.self)
    format = try c.format(.format, or: defaults.format, references: Self.references)
    style = try c.value(.style, or: defaults.style)
    disabled = try c.value(.disabled, or: defaults.disabled)
  }
}

// MARK: - model

/// The options of the `model` module: the value of the model config option
/// of the session.
nonisolated public struct ModelModule: StatusLineModuleOptions {
  public static let id = StatusLineModuleID.model
  public static let references: Set<String> = ["symbol", "name"]
  public static var schema: StatusLineSchema { .object(valueKeys(CodingKeys.self)) }

  public var format: StatusLineFormat = "$symbol $name"
  public var style: StatusLineStyle = "green"
  public var disabled = false
  public var symbol: StatusLineSymbol = "sf:cpu"

  public init() {}

  enum CodingKeys: String, CodingKey, CaseIterable {
    case format, style, disabled, symbol
  }

  public init(from decoder: any Decoder) throws {
    let defaults = Self()
    let c = try decoder.container(keyedBy: CodingKeys.self)
    format = try c.format(.format, or: defaults.format, references: Self.references)
    style = try c.value(.style, or: defaults.style)
    disabled = try c.value(.disabled, or: defaults.disabled)
    symbol = try c.value(.symbol, or: defaults.symbol)
  }
}

// MARK: - context

/// The options of the `context` module: the use of the context window, from
/// the `usage` update of the session.
///
/// The style of the module is the style of the first threshold whose
/// `below` is more than the percentage, or ``style`` when no threshold
/// applies.
nonisolated public struct ContextModule: StatusLineModuleOptions {
  /// A style for a percentage below a limit.
  public struct Threshold: Codable, Hashable, Sendable {
    /// The limit, as a percentage.
    public var below: Int
    /// The style below the limit.
    public var style: StatusLineStyle

    public init(below: Int, style: StatusLineStyle) {
      self.below = below
      self.style = style
    }
  }

  public static let id = StatusLineModuleID.context
  public static let references: Set<String> = ["symbol", "percentage", "used", "size", "bar"]
  public static var schema: StatusLineSchema {
    var keys = valueKeys(CodingKeys.self)
    keys[CodingKeys.thresholds.stringValue] = .list(.object(["below": .value, "style": .value]))
    return .object(keys)
  }

  public var format: StatusLineFormat = "$symbol $percentage%"
  public var style: StatusLineStyle = "secondary"
  public var disabled = false
  public var symbol: StatusLineSymbol = "sf:gauge.with.needle"
  /// The characters of `$bar`.
  public var barWidth = 10
  /// The styles of the percentage, in order.
  public var thresholds: [Threshold] = [
    Threshold(below: 50, style: "green"),
    Threshold(below: 80, style: "yellow"),
    Threshold(below: 101, style: "red"),
  ]

  public init() {}

  enum CodingKeys: String, CodingKey, CaseIterable {
    case format, style, disabled, symbol, thresholds
    case barWidth = "bar_width"
  }

  public init(from decoder: any Decoder) throws {
    let defaults = Self()
    let c = try decoder.container(keyedBy: CodingKeys.self)
    format = try c.format(.format, or: defaults.format, references: Self.references)
    style = try c.value(.style, or: defaults.style)
    disabled = try c.value(.disabled, or: defaults.disabled)
    symbol = try c.value(.symbol, or: defaults.symbol)
    barWidth = try c.value(.barWidth, or: defaults.barWidth)
    thresholds = try c.value(.thresholds, or: defaults.thresholds)
  }
}

// MARK: - time

/// The options of the `time` module: the time of day.
nonisolated public struct TimeModule: StatusLineModuleOptions {
  public static let id = StatusLineModuleID.time
  public static let references: Set<String> = ["time"]
  public static var schema: StatusLineSchema { .object(valueKeys(CodingKeys.self)) }

  public var format: StatusLineFormat = "$time"
  public var style: StatusLineStyle = "secondary"
  public var disabled = false
  /// The date format pattern of the time, such as `HH:mm` (Unicode
  /// Technical Standard #35).
  public var timeFormat = "HH:mm"

  public init() {}

  enum CodingKeys: String, CodingKey, CaseIterable {
    case format, style, disabled
    case timeFormat = "time_format"
  }

  public init(from decoder: any Decoder) throws {
    let defaults = Self()
    let c = try decoder.container(keyedBy: CodingKeys.self)
    format = try c.format(.format, or: defaults.format, references: Self.references)
    style = try c.value(.style, or: defaults.style)
    disabled = try c.value(.disabled, or: defaults.disabled)
    timeFormat = try c.value(.timeFormat, or: defaults.timeFormat)
  }
}
