import Foundation

/// One run of the status line: text, an SF Symbol or a bundled icon, in a
/// style.
nonisolated public struct StatusLineSpan: Hashable, Sendable {
  /// What the run shows.
  public enum Content: Hashable, Sendable {
    case text(String)
    case sfSymbol(String)
    case icon(String)
  }

  public var content: Content
  public var style: StatusLineStyle

  public init(_ content: Content, style: StatusLineStyle) {
    self.content = content
    self.style = style
  }

  /// A text run.
  public static func text(_ text: String, _ style: StatusLineStyle) -> StatusLineSpan {
    StatusLineSpan(.text(text), style: style)
  }

  /// The run of a symbol.
  public static func symbol(_ symbol: StatusLineSymbol, _ style: StatusLineStyle) -> StatusLineSpan {
    switch symbol {
    case .text(let text): .text(text, style)
    case .sfSymbol(let name): StatusLineSpan(.sfSymbol(name), style: style)
    case .icon(let name): StatusLineSpan(.icon(name), style: style)
    }
  }

  /// The text of the run for VoiceOver and for a plain copy: the text, the
  /// name of an icon, and nothing for an SF Symbol.
  public var plainText: String {
    switch content {
    case .text(let text): text
    case .sfSymbol: ""
    case .icon(let name): name
    }
  }
}

/// One part of a rendered status line: the runs of one module, or literal
/// text of the format of the line.
nonisolated public struct StatusLinePiece: Hashable, Sendable {
  /// The module of the part, or `nil` for literal text.
  public var module: StatusLineModuleID?
  /// The runs of the part.
  public var spans: [StatusLineSpan]

  public init(module: StatusLineModuleID?, spans: [StatusLineSpan]) {
    self.module = module
    self.spans = spans
  }

  /// The plain text of the part.
  public var plainText: String {
    spans.map(\.plainText).joined()
  }
}

/// A rendered status line.
nonisolated public struct StatusLineRendering: Hashable, Sendable {
  /// The parts, in order.
  public var pieces: [StatusLinePiece]

  public init(pieces: [StatusLinePiece]) {
    self.pieces = pieces
  }

  /// The plain text of the line, with no double space.
  public var plainText: String {
    pieces.map(\.plainText).joined()
      .split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
  }

  /// The modules that show, in order.
  public var modules: [StatusLineModuleID] {
    pieces.compactMap(\.module)
  }

  /// The plain text of a module, or `nil` when it does not show.
  public func text(of module: StatusLineModuleID) -> String? {
    pieces.first { $0.module == module }?.plainText
  }
}

/// The data of the status line at one time.
nonisolated public struct StatusLineInput: Hashable, Sendable {
  /// The working folder of the session, or `nil`.
  public var cwd: String?
  /// The home folder of the user.
  public var homeFolder: String
  /// The git state of the working folder, or `nil` outside a repository.
  public var git: StatusLineGitSnapshot?
  /// The files of the working folder, relative to it, or `nil` before the
  /// probe reads them.
  public var files: [String]?
  /// The title of the session, or `nil`.
  public var sessionTitle: String?
  /// The name of the agent, or `nil`.
  public var agentName: String?
  /// The version of the agent, or `nil`.
  public var agentVersion: String?
  /// The name of the model of the session, or `nil`.
  public var modelName: String?
  /// The tokens in the context window, or `nil` with no `usage` update.
  public var contextUsed: Int?
  /// The size of the context window, or `nil`.
  public var contextSize: Int?
  /// The time of the `time` module.
  public var date: Date
  /// The time zone of the `time` module.
  public var timeZone: TimeZone

  public init(
    cwd: String? = nil, homeFolder: String = NSHomeDirectory(), git: StatusLineGitSnapshot? = nil,
    files: [String]? = nil, sessionTitle: String? = nil, agentName: String? = nil, agentVersion: String? = nil,
    modelName: String? = nil, contextUsed: Int? = nil, contextSize: Int? = nil, date: Date = Date(),
    timeZone: TimeZone = .current
  ) {
    self.cwd = cwd
    self.homeFolder = homeFolder
    self.git = git
    self.files = files
    self.sessionTitle = sessionTitle
    self.agentName = agentName
    self.agentVersion = agentVersion
    self.modelName = modelName
    self.contextUsed = contextUsed
    self.contextSize = contextSize
    self.date = date
    self.timeZone = timeZone
  }
}

/// Renders a status line definition with its data (D194 (e), (f)).
///
/// A module with no value (no git, no code, no usage), and a disabled
/// module, show nothing, and the line has no double space.
nonisolated public enum StatusLineRenderer {
  /// Renders a line.
  ///
  /// - Parameters:
  ///   - definition: The definition.
  ///   - input: The data.
  /// - Returns: The rendered line.
  public static func render(_ definition: StatusLineDefinition, input: StatusLineInput) -> StatusLineRendering {
    let output = definition.format.render { name -> StatusLinePiece? in
      guard let id = StatusLineModuleID(rawValue: name),
        let spans = moduleSpans(id, definition: definition, input: input), !spans.isEmpty
      else { return nil }
      return StatusLinePiece(module: id, spans: spans)
    }
    let pieces = StatusLineFormat.normalized(output).map { part -> StatusLinePiece in
      switch part {
      case .literal(let text): StatusLinePiece(module: nil, spans: [.text(text, .plain)])
      case .value(let piece): piece
      }
    }
    return StatusLineRendering(pieces: pieces)
  }

  /// The runs of one module, or `nil` when it shows nothing.
  public static func moduleSpans(_ id: StatusLineModuleID, definition: StatusLineDefinition, input: StatusLineInput)
    -> [StatusLineSpan]?
  {
    switch id {
    case .directory: directory(definition.directory, input: input)
    case .gitBranch: gitBranch(definition.gitBranch, git: input.git)
    case .gitStatus: gitStatus(definition.gitStatus, git: input.git)
    case .gitState: gitState(definition.gitState, git: input.git)
    case .languages: languages(definition.languages, files: input.files)
    case .session: session(definition.session, title: input.sessionTitle)
    case .agent: agent(definition.agent, input: input)
    case .model: model(definition.model, name: input.modelName)
    case .context: context(definition.context, used: input.contextUsed, size: input.contextSize)
    case .time: time(definition.time, input: input)
    }
  }

  // MARK: - Module format

  /// Renders the format of a module. Literal text takes the style of the
  /// module.
  private static func render(
    _ format: StatusLineFormat, style: StatusLineStyle, references: [String: [StatusLineSpan]]
  ) -> [StatusLineSpan]? {
    let output = format.render { name in references[name].flatMap { $0.isEmpty ? nil : $0 } }
    let hasValue = output.contains { if case .value = $0 { true } else { false } }
    guard hasValue else { return nil }
    return output.flatMap { part -> [StatusLineSpan] in
      switch part {
      case .literal(let text): [.text(text, style)]
      case .value(let spans): spans
      }
    }
  }

  /// A text, cut to a length with a symbol at its end.
  static func truncated(_ text: String, length: Int?, symbol: String) -> String {
    guard let length, length >= 0, text.count > length else { return text }
    return String(text.prefix(length)) + symbol
  }

  // MARK: - Modules

  private static func directory(_ module: DirectoryModule, input: StatusLineInput) -> [StatusLineSpan]? {
    guard !module.disabled, let cwd = input.cwd else { return nil }
    let parts = StatusLineDirectory.parts(
      cwd: cwd, homeFolder: input.homeFolder, repositoryRoot: input.git?.root, module: module)
    guard !parts.isEmpty else { return nil }
    let path = parts.map { part in StatusLineSpan.text(part.text, part.isRepositoryRoot ? module.repoRootStyle : module.style) }
    return render(module.format, style: module.style, references: ["path": path])
  }

  private static func gitBranch(_ module: GitBranchModule, git: StatusLineGitSnapshot?) -> [StatusLineSpan]? {
    guard !module.disabled, let git else { return nil }
    let name: String
    if let branch = git.branch {
      guard !module.ignoreBranches.contains(branch) else { return nil }
      name = truncated(branch, length: module.truncationLength, symbol: module.truncationSymbol)
    } else if let hash = git.detachedHash, !module.onlyAttached {
      name = hash
    } else {
      return nil
    }
    return render(
      module.format, style: module.style,
      references: [
        "symbol": module.symbol.isEmpty ? [] : [.symbol(module.symbol, module.style)],
        "branch": [.text(name, module.style)],
      ])
  }

  private static func gitStatus(_ module: GitStatusModule, git: StatusLineGitSnapshot?) -> [StatusLineSpan]? {
    guard !module.disabled, let git else { return nil }
    func count(_ format: StatusLineFormat, _ value: Int) -> String? {
      value > 0 ? format.renderText { $0 == "count" ? String(value) : nil }.nonEmpty : nil
    }
    let counts = git.counts
    let parts: [(String, String?)] = [
      ("conflicted", count(module.conflicted, counts.conflicted)),
      ("stashed", count(module.stashed, git.stashed)),
      ("deleted", count(module.deleted, counts.deleted)),
      ("renamed", count(module.renamed, counts.renamed)),
      ("staged", count(module.staged, counts.staged)),
      ("modified", count(module.modified, counts.modified)),
      ("untracked", count(module.untracked, counts.untracked)),
    ]
    var references: [String: [StatusLineSpan]] = [:]
    for (name, text) in parts {
      if let text { references[name] = [.text(text, module.style)] }
    }
    let all = parts.compactMap(\.1).joined()
    if !all.isEmpty { references["all_status"] = [.text(all, module.style)] }
    if let aheadBehind = aheadBehind(module, ahead: git.ahead, behind: git.behind) {
      references["ahead_behind"] = [.text(aheadBehind, module.style)]
    }
    return render(module.format, style: module.style, references: references)
  }

  private static func aheadBehind(_ module: GitStatusModule, ahead: Int?, behind: Int?) -> String? {
    guard let ahead, let behind else { return nil }
    let text: String
    if ahead > 0, behind > 0 {
      text = module.diverged.renderText { ["ahead_count": String(ahead), "behind_count": String(behind)][$0] }
    } else if ahead > 0 {
      text = module.ahead.renderText { $0 == "count" ? String(ahead) : nil }
    } else if behind > 0 {
      text = module.behind.renderText { $0 == "count" ? String(behind) : nil }
    } else {
      text = module.upToDate.renderText { _ in nil }
    }
    return text.nonEmpty
  }

  private static func gitState(_ module: GitStateModule, git: StatusLineGitSnapshot?) -> [StatusLineSpan]? {
    guard !module.disabled, let state = git?.state else { return nil }
    let label =
      switch state {
      case .rebase: module.rebase
      case .merge: module.merge
      case .revert: module.revert
      case .cherryPick: module.cherryPick
      case .bisect: module.bisect
      case .am: module.am
      case .amOrRebase: module.amOrRebase
      }
    var references: [String: [StatusLineSpan]] = ["state": [.text(label, module.style)]]
    if let progress = git?.progress {
      references["progress_current"] = [.text(String(progress.current), module.style)]
      references["progress_total"] = [.text(String(progress.total), module.style)]
    }
    return render(module.format, style: module.style, references: references)
  }

  private static func languages(_ module: LanguagesModule, files: [String]?) -> [StatusLineSpan]? {
    guard !module.disabled, let files else { return nil }
    let found = StatusLineLanguageDetector.languages(of: files, module: module)
    guard !found.isEmpty else { return nil }
    var symbols: [StatusLineSpan] = []
    for (index, language) in found.enumerated() {
      if index > 0 { symbols.append(.text(" ", module.style)) }
      symbols.append(.symbol(language.symbol, module.style))
    }
    return render(module.format, style: module.style, references: ["symbols": symbols])
  }

  private static func session(_ module: SessionModule, title: String?) -> [StatusLineSpan]? {
    guard !module.disabled, let title, !title.isEmpty else { return nil }
    let text = truncated(title, length: module.truncationLength, symbol: "…")
    return render(module.format, style: module.style, references: ["title": [.text(text, module.style)]])
  }

  private static func agent(_ module: AgentModule, input: StatusLineInput) -> [StatusLineSpan]? {
    guard !module.disabled, let name = input.agentName, !name.isEmpty else { return nil }
    var references: [String: [StatusLineSpan]] = ["name": [.text(name, module.style)]]
    if let version = input.agentVersion, !version.isEmpty {
      references["version"] = [.text(version, module.style)]
    }
    return render(module.format, style: module.style, references: references)
  }

  private static func model(_ module: ModelModule, name: String?) -> [StatusLineSpan]? {
    guard !module.disabled, let name, !name.isEmpty else { return nil }
    return render(
      module.format, style: module.style,
      references: [
        "symbol": module.symbol.isEmpty ? [] : [.symbol(module.symbol, module.style)],
        "name": [.text(name, module.style)],
      ])
  }

  /// The percentage of a context window, rounded.
  static func percentage(used: Int, size: Int) -> Int {
    Int((Double(used) * 100 / Double(size)).rounded())
  }

  private static func context(_ module: ContextModule, used: Int?, size: Int?) -> [StatusLineSpan]? {
    guard !module.disabled, let used, let size, size > 0 else { return nil }
    let percentage = percentage(used: used, size: size)
    let style = module.thresholds.first { percentage < $0.below }?.style ?? module.style
    let width = max(0, module.barWidth)
    let filled = min(width, Int((Double(min(used, size)) * Double(width) / Double(size)).rounded()))
    let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: width - filled)
    return render(
      module.format, style: style,
      references: [
        "symbol": module.symbol.isEmpty ? [] : [.symbol(module.symbol, style)],
        "percentage": [.text(String(percentage), style)],
        "used": [.text(String(used), style)],
        "size": [.text(String(size), style)],
        "bar": [.text(bar, style)],
      ])
  }

  private static func time(_ module: TimeModule, input: StatusLineInput) -> [StatusLineSpan]? {
    guard !module.disabled else { return nil }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = input.timeZone
    formatter.dateFormat = module.timeFormat
    let text = formatter.string(from: input.date)
    guard !text.isEmpty else { return nil }
    return render(module.format, style: module.style, references: ["time": [.text(text, module.style)]])
  }
}

/// The parts of the path of the `directory` module (D194 (f)).
nonisolated public enum StatusLineDirectory {
  /// One part of the shown path. The separators are parts too.
  public struct Part: Hashable, Sendable {
    public var text: String
    public var isRepositoryRoot: Bool

    public init(_ text: String, isRepositoryRoot: Bool = false) {
      self.text = text
      self.isRepositoryRoot = isRepositoryRoot
    }
  }

  /// The parts of the shown path of a folder.
  ///
  /// 1. With `truncate_to_repo`, a folder in a repository starts at the
  ///    folder of the repository root. Otherwise the home folder becomes
  ///    `home_symbol`.
  /// 2. The substitutions change the path, in order.
  /// 3. The path keeps its last `truncation_length` parts, with
  ///    `truncation_symbol` in front when it loses parts.
  /// 4. Each parent part other than the repository root and the home symbol
  ///    keeps `fish_style_pwd_dir_length` characters (and a leading `.`).
  ///
  /// - Parameters:
  ///   - cwd: The folder.
  ///   - homeFolder: The home folder of the user.
  ///   - repositoryRoot: The root of the repository that holds the folder,
  ///     or `nil`.
  ///   - module: The options of the module.
  /// - Returns: The parts, with `/` parts between the folder parts.
  public static func parts(cwd: String, homeFolder: String, repositoryRoot: String?, module: DirectoryModule)
    -> [Part]
  {
    let folder = trimmed(cwd)
    let home = trimmed(homeFolder)
    var components: [String]
    var isAbsolute = false
    var repositoryIndex: Int?
    if module.truncateToRepo, let root = repositoryRoot.map(trimmed), let rest = relative(folder, to: root),
      let rootName = root.split(separator: "/").last
    {
      components = [String(rootName)] + rest
      repositoryIndex = 0
    } else if let rest = relative(folder, to: home), !home.isEmpty, home != "/" {
      components = [module.homeSymbol] + rest
    } else {
      components = folder.split(separator: "/").map(String.init)
      isAbsolute = true
    }
    if !module.substitutions.isEmpty {
      let first = components.first
      var joined = (isAbsolute ? "/" : "") + components.joined(separator: "/")
      for substitution in module.substitutions where !substitution.from.isEmpty {
        joined = joined.replacingOccurrences(of: substitution.from, with: substitution.to)
      }
      isAbsolute = joined.hasPrefix("/")
      components = joined.split(separator: "/").map(String.init)
      if components.first != first { repositoryIndex = nil }
    }
    if components.isEmpty { return isAbsolute ? [Part("/")] : [] }
    var truncated = false
    let length = module.truncationLength
    if length > 0, components.count > length {
      let dropped = components.count - length
      components.removeFirst(dropped)
      repositoryIndex = repositoryIndex.flatMap { $0 >= dropped ? $0 - dropped : nil }
      truncated = true
    }
    var parts: [Part] = []
    if truncated, !module.truncationSymbol.isEmpty {
      parts.append(Part(module.truncationSymbol))
    } else if isAbsolute, !truncated {
      parts.append(Part("/"))
    }
    for (index, component) in components.enumerated() {
      if index > 0 { parts.append(Part("/")) }
      let isRoot = index == repositoryIndex
      let isLast = index == components.count - 1
      let text =
        isLast || isRoot || component == module.homeSymbol
        ? component : fishStyle(component, length: module.fishStylePwdDirLength)
      parts.append(Part(text, isRepositoryRoot: isRoot))
    }
    return parts
  }

  /// A part cut to `length` characters, and the leading `.` of a hidden
  /// folder.
  static func fishStyle(_ component: String, length: Int) -> String {
    guard length > 0 else { return component }
    if component.hasPrefix("."), component.count > 1 {
      return "." + component.dropFirst().prefix(length)
    }
    return String(component.prefix(length))
  }

  private static func trimmed(_ path: String) -> String {
    path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
  }

  /// The components of `folder` below `base`, or `nil` when `base` does not
  /// hold `folder`.
  private static func relative(_ folder: String, to base: String) -> [String]? {
    if folder == base { return [] }
    let prefix = base == "/" ? "/" : base + "/"
    guard folder.hasPrefix(prefix) else { return nil }
    return folder.dropFirst(prefix.count).split(separator: "/").map(String.init)
  }
}

nonisolated extension String {
  /// The text, or `nil` when it is empty.
  fileprivate var nonEmpty: String? {
    isEmpty ? nil : self
  }
}
