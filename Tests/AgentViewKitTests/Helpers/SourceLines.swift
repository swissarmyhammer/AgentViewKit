import Foundation
import PackageFileSupport

/// Finds the lines of source files that match a pattern. The tests that make
/// sure that no kit source declares a name use it.
enum SourceLines {
  /// The lines of `files` that contain a match of `pattern`.
  ///
  /// - Parameters:
  ///   - pattern: The pattern to find in each line.
  ///   - files: The files to read, as UTF-8 text.
  /// - Returns: Each line that matches, after the name of its file, in the
  ///   form `File.swift: line`.
  /// - Throws: The error of `String(contentsOf:encoding:)` when a file cannot
  ///   be read or is not UTF-8.
  static func matching(_ pattern: Regex<AnyRegexOutput>, in files: [URL]) throws -> [String] {
    try files.flatMap { file in
      try String(contentsOf: file, encoding: .utf8)
        .split(separator: "\n")
        .filter { $0.contains(pattern) }
        .map { "\(file.lastPathComponent): \($0)" }
    }
  }

  /// The lines of the package files at `paths` that contain a match of
  /// `pattern`.
  ///
  /// - Parameters:
  ///   - pattern: The pattern to find in each line.
  ///   - paths: The paths of the files, relative to the package root, such as
  ///     `Sources/AgentViewKit/Items/ErrorView.swift`.
  /// - Returns: Each line that matches, in the form of
  ///   ``matching(_:in:)``.
  /// - Throws: The error of `PackageFiles.file(_:)` for a path outside the
  ///   package, or the error of ``matching(_:in:)``.
  static func matching(_ pattern: Regex<AnyRegexOutput>, inPackageFiles paths: [String]) throws -> [String] {
    try matching(pattern, in: paths.map { try PackageFiles.file($0) })
  }
}
