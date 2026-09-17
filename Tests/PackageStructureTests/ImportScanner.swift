import Foundation
import PackageFileSupport

/// One forbidden `import` that the scanner found in a Swift source file.
struct ImportViolation: Equatable, CustomStringConvertible {
  /// The file that holds the import, relative to the scanned directory.
  let file: String
  /// The line number of the import. The first line is line 1.
  let line: Int
  /// The name of the forbidden module.
  let module: String

  var description: String {
    "\(file):\(line) imports \(module)"
  }
}

/// Reads the `import` declarations of Swift source files as text.
///
/// The scanner reads each line that starts with an `import` declaration. It
/// removes the attributes (`@testable`, `@preconcurrency`, `@_exported`), the
/// access modifiers (`public`, `package`, `internal`, `fileprivate`,
/// `private`), and the import kind (`struct`, `func`, and the other kinds). The
/// module name is the first part of the path that remains. A module name must
/// match a forbidden name exactly, so `FoundationModelsACP` does not match
/// `FoundationModels`.
enum ImportScanner {
  /// The words that can come before the module path in an `import`
  /// declaration and that are not the module path.
  private static let skippedWords: Set<String> = [
    "public", "package", "internal", "fileprivate", "private",
    "typealias", "struct", "class", "enum", "protocol", "let", "var", "func",
  ]

  /// Finds each forbidden import in the Swift files below a directory.
  ///
  /// - Parameters:
  ///   - directory: The directory to scan. The scan includes subdirectories.
  ///   - forbidden: The module names that the files must not import.
  /// - Returns: The violations, sorted by file and then by line.
  static func violations(in directory: URL, forbidden: Set<String>) throws -> [ImportViolation] {
    let files = try PackageFiles.swiftFiles(in: directory)
    let rootDepth = directory.standardizedFileURL.pathComponents.count
    return try files.flatMap { file in
      let relative = file.standardizedFileURL.pathComponents.dropFirst(rootDepth).joined(separator: "/")
      let text = try String(contentsOf: file, encoding: .utf8)
      return violations(inSource: text, file: relative, forbidden: forbidden)
    }
    .sorted { ($0.file, $0.line) < ($1.file, $1.line) }
  }

  /// Finds each forbidden import in the text of one Swift file.
  ///
  /// - Parameters:
  ///   - source: The text of the file.
  ///   - file: The name to write into each violation.
  ///   - forbidden: The module names that the file must not import.
  /// - Returns: The violations, in line order.
  static func violations(inSource source: String, file: String, forbidden: Set<String>) -> [ImportViolation] {
    source.split(separator: "\n", omittingEmptySubsequences: false)
      .enumerated()
      .compactMap { offset, line in
        guard let module = importedModule(in: line), forbidden.contains(module) else {
          return nil
        }
        return ImportViolation(file: file, line: offset + 1, module: module)
      }
  }

  /// The name of the module that one line imports.
  ///
  /// - Parameter line: One line of Swift source.
  /// - Returns: The module name, or `nil` when the line is not an `import`
  ///   declaration.
  static func importedModule(in line: Substring) -> String? {
    let words = line.split(whereSeparator: \.isWhitespace).map(String.init)
    let declaration = words.drop { $0.hasPrefix("@") || skippedWords.contains($0) }
    guard declaration.first == "import" else {
      return nil
    }
    let path = declaration.dropFirst().first { !skippedWords.contains($0) }
    return path?.split(separator: ".").first.map(String.init)
  }
}
