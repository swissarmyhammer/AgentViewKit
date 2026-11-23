import Foundation

/// The parts of the path of the `directory` module (D194 (f)).
///
/// The path shows the folders as Finder shows them in its path bar: each
/// folder has its whole display name, with ``separator`` between two
/// folders. The home folder is `~`. An iCloud Drive folder shows as
/// ``iCloudDriveName``, and the folder of an app container in iCloud Drive
/// shows as ``iCloudDriveName`` and the display name of the container. A
/// long path removes whole names from its middle and shows one ``ellipsis``
/// in their place.
nonisolated public enum StatusLineDirectory {
  /// The text between two folders: the separator of the path bar of Finder.
  public static let separator = " › "

  /// The text in place of the folders that a long path removes.
  public static let ellipsis = "…"

  /// The name of iCloud Drive, as Finder shows it.
  public static let iCloudDriveName = "iCloud Drive"

  /// The most characters of a path. A longer path removes folders from its
  /// middle.
  public static let lengthLimit = 60

  /// The count of the last folders that a long path always keeps.
  public static let keptLastFolders = 2

  /// The path of the folder of iCloud Drive, relative to the home folder.
  /// Each app container and the iCloud Drive folder itself are in it.
  static let mobileDocumentsFolder = "Library/Mobile Documents"

  /// The name of the container of the iCloud Drive folder itself.
  static let iCloudDriveContainer = "com~apple~CloudDocs"

  /// The name of the folder of an app container that holds the files that
  /// Finder shows.
  static let containerDocumentsFolder = "Documents"

  /// One part of the shown path. The separators are parts too.
  public struct Part: Hashable, Sendable {
    /// The text of the part.
    public var text: String
    /// `true` when the part is the folder of the repository root.
    public var isRepositoryRoot: Bool

    /// Makes a part.
    ///
    /// - Parameters:
    ///   - text: The text of the part.
    ///   - isRepositoryRoot: `true` for the folder of the repository root.
    public init(_ text: String, isRepositoryRoot: Bool = false) {
      self.text = text
      self.isRepositoryRoot = isRepositoryRoot
    }
  }

  /// One folder of the path, before it becomes a part.
  struct Component: Hashable {
    /// The text of the part.
    var text: String
    /// The folder that the part stands for, or `nil` when a substitution
    /// made the part.
    var path: String?
    /// The folder whose display name the part shows, or `nil` when the
    /// part keeps its text.
    var namePath: String?
    /// `true` when the part is never cut to `fish_style_pwd_dir_length`
    /// letters: the home symbol, iCloud Drive, the root folder and the
    /// ellipsis.
    var isFixed = false
    /// `true` when the part is the folder of the repository root.
    var isRepositoryRoot = false

    /// The part of a folder: its name, and its path for its display name.
    init(folder: String) {
      text = (folder as NSString).lastPathComponent
      path = folder
      namePath = folder
    }

    /// A part with a given text.
    init(text: String, path: String? = nil, namePath: String? = nil, isFixed: Bool = false) {
      self.text = text
      self.path = path
      self.namePath = namePath
      self.isFixed = isFixed
    }
  }

  /// The folders of a path, and whether the path starts at the root folder.
  struct Path {
    var components: [Component]
    var isAbsolute: Bool

    /// The path as text, with `/` between the folders.
    var text: String {
      (isAbsolute ? "/" : "") + components.map(\.text).joined(separator: "/")
    }
  }

  /// The parts of the shown path of a folder.
  ///
  /// 1. With `truncate_to_repo`, a folder in a repository starts at the
  ///    folder of the repository root. Otherwise the home folder becomes
  ///    `home_symbol`.
  /// 2. The substitutions change the path, in order.
  /// 3. An iCloud Drive folder below the home folder becomes
  ///    ``iCloudDriveName``, and the folder of an app container becomes
  ///    ``iCloudDriveName`` and the display name of the container.
  /// 4. The path keeps its last `truncation_length` parts, with
  ///    `truncation_symbol` in front when it loses parts.
  /// 5. Each folder shows its display name.
  /// 6. Each parent part other than the repository root and the home symbol
  ///    keeps `fish_style_pwd_dir_length` characters (and a leading `.`).
  ///    The default 0 keeps each part whole.
  /// 7. With no `truncation_length`, a path longer than ``lengthLimit``
  ///    characters keeps its first part and its last folders, and shows one
  ///    ``ellipsis`` in place of the folders between them.
  ///
  /// - Parameters:
  ///   - cwd: The folder.
  ///   - homeFolder: The home folder of the user.
  ///   - repositoryRoot: The root of the repository that holds the folder,
  ///     or `nil`.
  ///   - module: The options of the module.
  ///   - displayName: The display name of a folder, or `nil` for the name
  ///     of the folder. The model of the line reads the names with
  ///     ``finderDisplayName(of:)``.
  /// - Returns: The parts, with ``separator`` parts between the folder
  ///   parts.
  public static func parts(
    cwd: String, homeFolder: String, repositoryRoot: String?, module: DirectoryModule,
    displayName: (String) -> String? = { _ in nil }
  ) -> [Part] {
    let home = trimmed(homeFolder)
    let root = repositoryRoot.map(trimmed)
    let path = substituted(start(folder: trimmed(cwd), home: home, root: root, module: module), module.substitutions)
    let collapsed = iCloudCollapsed(path.components, home: home)
    let kept = truncated(collapsed, length: module.truncationLength)
    let isTruncated = kept.count < collapsed.count
    let rootFolder =
      path.isAbsolute && !isTruncated ? [Component(text: "/", path: "/", namePath: "/", isFixed: true)] : []
    let named = (rootFolder + kept).map { component in
      var component = component
      component.text = component.namePath.flatMap(displayName) ?? component.text
      component.isRepositoryRoot = root != nil && component.path == root
      return component
    }
    let styled = fishStyled(named, module: module)
    let components = module.truncationLength <= 0 ? elided(styled) : styled
    let symbol = isTruncated && !module.truncationSymbol.isEmpty ? [Part(module.truncationSymbol)] : []
    let folders = components.enumerated().flatMap { index, component in
      (index > 0 ? [Part(separator)] : []) + [Part(component.text, isRepositoryRoot: component.isRepositoryRoot)]
    }
    return symbol + folders
  }

  /// The display name of a folder, as Finder shows it.
  ///
  /// - Parameter path: The path of the folder.
  /// - Returns: The display name of `FileManager`: the localized name, and
  ///   the name of an app container.
  public static func finderDisplayName(of path: String) -> String {
    FileManager.default.displayName(atPath: path)
  }

  /// The folders that hold a folder, from the root folder to the folder
  /// itself.
  ///
  /// - Parameter folder: The path of the folder.
  /// - Returns: The paths: `/`, then each folder below it down to `folder`.
  static func folders(above folder: String) -> [String] {
    let names = trimmed(folder).split(separator: "/").map(String.init)
    return ["/"] + descendants(of: "/", names).compactMap(\.path)
  }

  // MARK: - Steps

  /// The folders of the path before the substitutions: from the repository
  /// root with `truncate_to_repo`, from the home folder, or from the root
  /// folder.
  private static func start(folder: String, home: String, root: String?, module: DirectoryModule) -> Path {
    if module.truncateToRepo, let root, let rest = relative(folder, to: root), root != "/" {
      return Path(components: [Component(folder: root)] + descendants(of: root, rest), isAbsolute: false)
    }
    if let rest = relative(folder, to: home), !home.isEmpty, home != "/" {
      let symbol = Component(text: module.homeSymbol, path: home, isFixed: true)
      return Path(components: [symbol] + descendants(of: home, rest), isAbsolute: false)
    }
    let names = folder.split(separator: "/").map(String.init)
    return Path(components: descendants(of: "/", names), isAbsolute: true)
  }

  /// The path after the substitutions. The parts at the end that the
  /// substitutions do not change keep their folders, so that they keep
  /// their display names and the repository root.
  private static func substituted(_ path: Path, _ substitutions: [DirectoryModule.Substitution]) -> Path {
    let text = path.text
    let changed = substitutions.filter { !$0.from.isEmpty }.reduce(text) { text, substitution in
      text.replacingOccurrences(of: substitution.from, with: substitution.to)
    }
    guard changed != text else { return path }
    let components = changed.split(separator: "/").map { Component(text: String($0)) }
    let unchangedCount = zip(components.reversed(), path.components.reversed()).prefix { $0.text == $1.text }.count
    return Path(
      components: Array(components.dropLast(unchangedCount) + path.components.suffix(unchangedCount)),
      isAbsolute: changed.hasPrefix("/"))
  }

  /// The parts with the folders of iCloud Drive as Finder shows them.
  ///
  /// `~/Library/Mobile Documents` and its `com~apple~CloudDocs` folder
  /// become ``iCloudDriveName``. An app container below it, and the
  /// `Documents` folder of the container, become ``iCloudDriveName`` and the
  /// part of the container, which shows the display name of the container.
  private static func iCloudCollapsed(_ components: [Component], home: String) -> [Component] {
    let mobileDocuments = (home as NSString).appendingPathComponent(mobileDocumentsFolder)
    let depth = mobileDocumentsFolder.split(separator: "/").count
    guard components.first?.path == home, components.count > depth, components[depth].path == mobileDocuments
    else { return components }
    let drive = Component(text: iCloudDriveName, path: mobileDocuments, isFixed: true)
    let containerIndex = depth + 1
    guard let container = components.dropFirst(containerIndex).first else { return [drive] }
    let below = components.dropFirst(containerIndex + 1)
    guard container.text != iCloudDriveContainer else {
      return [Component(text: iCloudDriveName, path: container.path, isFixed: true)] + below
    }
    let documents = below.first.flatMap { $0.text == containerDocumentsFolder ? $0 : nil }
    let part = Component(
      text: container.text, path: documents?.path ?? container.path, namePath: container.namePath,
      isFixed: container.isFixed)
    return [drive, part] + below.dropFirst(documents == nil ? 0 : 1)
  }

  /// The last `length` parts, or all the parts when `length` is 0 or less.
  private static func truncated(_ components: [Component], length: Int) -> [Component] {
    guard length > 0 else { return components }
    return Array(components.suffix(length))
  }

  /// The parts with each parent part cut to `fish_style_pwd_dir_length`
  /// letters, other than the last part, the repository root and the fixed
  /// parts.
  private static func fishStyled(_ components: [Component], module: DirectoryModule) -> [Component] {
    components.enumerated().map { index, component in
      var component = component
      let keepsText =
        index == components.count - 1 || component.isRepositoryRoot || component.isFixed
        || component.text == module.homeSymbol
      if !keepsText {
        component.text = fishStyle(component.text, length: module.fishStylePwdDirLength)
      }
      return component
    }
  }

  /// The parts of a long path: the first part, one ``ellipsis``, and the
  /// last folders that fit in ``lengthLimit`` characters. The path always
  /// keeps its last ``keptLastFolders`` folders whole.
  static func elided(_ components: [Component]) -> [Component] {
    guard components.count > keptLastFolders + 1, width(of: components) > lengthLimit else { return components }
    let head = [components[0], Component(text: ellipsis, isFixed: true)]
    // The tail starts after the first folder of the middle at the earliest,
    // so that the ellipsis stands for at least one folder. A tail that
    // starts later is narrower, thus the first start that fits is the
    // longest tail that fits.
    let latestStart = components.count - keptLastFolders
    let tailStart =
      (head.count..<latestStart).first { width(of: head + components[$0...]) <= lengthLimit } ?? latestStart
    return head + components[tailStart...]
  }

  /// The count of the characters of the shown parts, with the separators.
  private static func width(of components: [Component]) -> Int {
    components.reduce(0) { $0 + $1.text.count } + separator.count * (components.count - 1)
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

  // MARK: - Paths

  /// The parts of the folders below `base`, each with its path.
  private static func descendants(of base: String, _ names: [String]) -> [Component] {
    names.indices.map { index in
      Component(folder: names[...index].reduce(base) { ($0 as NSString).appendingPathComponent($1) })
    }
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
