import EditorText
import Foundation
import os

/// The TextMate grammars that the kit ships for the languages that agents
/// write most (plan.md §4.1, §11 decision 13).
///
/// EditorKit links tree-sitter grammars for JSON and Markdown only. For the
/// languages in ``languageIDs``, the kit gives a `TextMateGrammarRegistry`.
///
/// ## Decision: research R2
///
/// - Languages: Swift, Python, TypeScript, JavaScript, Rust, Go, shell, YAML,
///   TOML, HTML, CSS, and SQL.
/// - Source: the JSON grammars of the npm package `tm-grammars` 1.32.20
///   (shikijs/textmate-grammars-themes, MIT). Each file is an unchanged copy.
///   `Resources/Grammars/LICENSES.md` gives the upstream URL, the commit, and
///   the license of each grammar. Each license is MIT or the permissive
///   TextMate bundle license.
/// - Size: the 12 files are approximately 1.1 MB, less than the 2 MB limit.
/// - Place: the kit bundles the grammars, not EditorKit. When EditorKit links
///   more grammars, the kit removes the grammars that EditorKit then has.
/// - Format: `TextMateGrammar(data:)` of EditorKit reads JSON data, keeps the
///   `repository`, and resolves each `include`. The kit gives it the bytes of
///   the file and adds nothing.
/// - Load: ``registry`` loads each grammar one time, at the first read.
public enum GrammarBundle {
  /// One bundled language.
  struct Language {
    /// The EditorKit id of the language.
    let id: LanguageID
    /// The fence tags, other than the id, that name the language.
    let fenceTags: [String]
  }

  /// The failures of a grammar load.
  enum LoadError: Error, Equatable {
    /// The bundle has no file for the grammar.
    case missingResource(String)
    /// The file of the grammar cannot be read.
    case unreadable(String)
    /// The file of the grammar is not a JSON object.
    case malformed(String)
  }

  /// The name of the resource folder in the module bundle.
  static let resourceFolderName = "Grammars"

  /// The file extension of each grammar file.
  static let grammarExtension = "json"

  /// The bundled languages. The name of each grammar file is the raw value
  /// of the language id.
  static let languages: [Language] = [
    Language(id: LanguageID("swift"), fenceTags: []),
    Language(id: LanguageID("python"), fenceTags: ["py", "python3"]),
    Language(
      id: LanguageID("typescript"), fenceTags: ["ts", "cts", "mts"]),
    Language(
      id: LanguageID("javascript"), fenceTags: ["js", "cjs", "mjs", "node"]),
    Language(id: LanguageID("rust"), fenceTags: ["rs"]),
    Language(id: LanguageID("go"), fenceTags: ["golang"]),
    Language(
      id: LanguageID("shell"), fenceTags: ["sh", "bash", "zsh", "shellscript"]),
    Language(id: LanguageID("yaml"), fenceTags: ["yml"]),
    Language(id: LanguageID("toml"), fenceTags: []),
    Language(id: LanguageID("html"), fenceTags: ["htm", "xhtml"]),
    Language(id: LanguageID("css"), fenceTags: []),
    Language(id: LanguageID("sql"), fenceTags: []),
  ]

  /// The ids of the bundled languages.
  public static var languageIDs: [LanguageID] {
    languages.map(\.id)
  }

  /// The registry with the grammar of each bundled language.
  ///
  /// The first read loads each grammar one time. A grammar that does not
  /// load is not in the registry, and the load writes an error to the log.
  public static let registry = TextMateGrammarRegistry(grammars: loadedGrammars())

  /// Loads the bundled grammars, if they are not loaded.
  ///
  /// The first code block in a bundled language loads them itself, because it
  /// reads ``registry``. A host calls this function at launch, so that the
  /// first code block does not wait for the load.
  public static func register() {
    _ = registry
  }

  /// The id of the bundled language that `tag` names, or `nil`.
  ///
  /// The match ignores case and the whitespace at the start and the end. The
  /// id of a language is also a tag of that language.
  ///
  /// - Parameter tag: The language tag of a Markdown code fence, such as `ts`.
  /// - Returns: The language id, or `nil` when no bundled language has the tag.
  public static func languageID(forFenceTag tag: String) -> LanguageID? {
    languageIDsByFenceTag[tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()]
  }

  /// The language id of each fence tag.
  private static let languageIDsByFenceTag: [String: LanguageID] = Dictionary(
    uniqueKeysWithValues: languages.flatMap { language in
      ([language.id.rawValue] + language.fenceTags).map { ($0, language.id) }
    })

  /// The URL of the resource folder in the module bundle, or `nil`.
  static var resourceFolder: URL? {
    Bundle.module.url(forResource: resourceFolderName, withExtension: nil)
  }

  /// The log of the grammar load.
  private static let logger = Logger(subsystem: "AgentViewKit", category: "GrammarBundle")

  /// Loads the grammar of each bundled language.
  ///
  /// - Returns: The grammars that loaded, by language id.
  private static func loadedGrammars() -> [LanguageID: TextMateGrammar] {
    languages.reduce(into: [:]) { grammars, language in
      do {
        grammars[language.id] = try grammar(of: language)
      } catch {
        assertionFailure("the bundled grammar \(language.id.rawValue) did not load: \(error)")
        logger.error(
          "The bundled grammar \(language.id.rawValue, privacy: .public) did not load: \(String(describing: error), privacy: .public). The language has no colors."
        )
      }
    }
  }

  /// Loads the grammar of one language from the module bundle.
  ///
  /// - Parameter language: The language.
  /// - Returns: The grammar, with its repository.
  /// - Throws: ``LoadError``.
  static func grammar(of language: Language) throws(LoadError) -> TextMateGrammar {
    guard
      let url = resourceFolder?.appendingPathComponent(language.id.rawValue)
        .appendingPathExtension(grammarExtension)
    else {
      throw .missingResource(language.id.rawValue)
    }
    return try grammar(at: url)
  }

  /// Loads the JSON TextMate grammar at `url`.
  ///
  /// - Parameter url: The URL of the grammar file.
  /// - Returns: The grammar, with its repository.
  /// - Throws: ``LoadError``.
  static func grammar(at url: URL) throws(LoadError) -> TextMateGrammar {
    let data: Data
    do {
      data = try Data(contentsOf: url)
    } catch {
      throw .unreadable(url.lastPathComponent)
    }
    do {
      return try TextMateGrammar(data: data)
    } catch {
      throw .malformed(url.lastPathComponent)
    }
  }
}
