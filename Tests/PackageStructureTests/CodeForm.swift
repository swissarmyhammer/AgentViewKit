import Foundation
import Testing

/// A form of code that a structure suite finds with a pattern, such as a
/// forbidden call or a forbidden style.
///
/// Each structure suite has one enum of forms. The shared checks of the
/// protocols below read the forms of the enum, so each suite keeps only its
/// own data: the forms, the sample lines, the look-alike lines and the
/// fixtures.
protocol CodeForm: CaseIterable, Equatable {
  /// The pattern that finds the form in the code.
  var pattern: Regex<Substring> { get }
}

extension CodeForm {
  /// The forms whose pattern finds a match in a text.
  ///
  /// - Parameter text: The code, for example one line.
  /// - Returns: The forms, in the order of `allCases`.
  static func forms(in text: String) -> [Self] {
    allCases.filter { text.contains($0.pattern) }
  }
}

/// A ``CodeForm`` with sample lines and look-alike lines, which show that
/// each pattern finds its own form and nothing more.
protocol SampledCodeForm: CodeForm {
  /// A sample line of each form, with only that form on the line.
  static var sampleLines: [(form: Self, line: String)] { get }

  /// Lines that look like a form, but use none.
  static var lookAlikeLines: [String] { get }
}

extension SampledCodeForm {
  /// Expects that the patterns find only the form of each sample line.
  ///
  /// - Parameter sourceLocation: The place of the test, for the report of a
  ///   failure.
  static func expectEachSampleFindsOnlyItsOwnForm(sourceLocation: SourceLocation = #_sourceLocation) {
    for sample in sampleLines {
      #expect(forms(in: sample.line) == [sample.form], "\(sample.line)", sourceLocation: sourceLocation)
    }
  }

  /// Expects that no pattern finds a look-alike line.
  ///
  /// - Parameter sourceLocation: The place of the test, for the report of a
  ///   failure.
  static func expectNoFormFindsALookAlikeLine(sourceLocation: SourceLocation = #_sourceLocation) {
    for line in lookAlikeLines {
      #expect(forms(in: line).isEmpty, "\(line)", sourceLocation: sourceLocation)
    }
  }
}

/// The way a scan reads the code of each Swift file. Each way blanks the
/// comments and the string literals first, so a use in a comment or in a
/// string literal does not count.
enum CodeScan: Sendable {
  /// Reads the code one line at a time, so a match is on one line
  /// (``GlassPlacementTests/uses(of:inSwiftFilesBelow:relativeTo:allowing:)``).
  case lines

  /// Reads the code of each file as one text, so a match can continue on the
  /// next lines
  /// (``SourceLineScanner/codeMatchStarts(of:inSwiftFilesBelow:relativeTo:skipping:)``).
  case text

  /// Finds the uses of a pattern in the code of each Swift file below a
  /// directory.
  ///
  /// - Parameters:
  ///   - pattern: The pattern to find.
  ///   - directory: The directory to scan. The scan includes subdirectories.
  ///   - base: The directory that the file name of each use is relative to.
  /// - Returns: `<file>:<line>` for each use, with the line where the use
  ///   starts, in the order of the file paths, then in line order.
  /// - Throws: The error of the scanner.
  func uses(of pattern: Regex<Substring>, inSwiftFilesBelow directory: URL, relativeTo base: URL) throws
    -> [String]
  {
    switch self {
    case .lines: try GlassPlacementTests.uses(of: pattern, inSwiftFilesBelow: directory, relativeTo: base)
    case .text: try SourceLineScanner.codeMatchStarts(of: pattern, inSwiftFilesBelow: directory, relativeTo: base)
    }
  }
}

/// A ``CodeForm`` with a fixture directory, which shows that the scan of the
/// suite finds each form in code and in no other text.
protocol FixtureCodeForm: CodeForm {
  /// The fixture directory of the scan. Its ``CodeFormFixtures/clean``
  /// directory holds the forms only in comments and string literals.
  static var fixtures: URL { get throws }

  /// The way the scan of the suite reads the code.
  static var scan: CodeScan { get }
}

/// The names of the shared fixture directories of a ``FixtureCodeForm``.
enum CodeFormFixtures {
  /// The directory, relative to ``FixtureCodeForm/fixtures``, that holds the
  /// forms only in comments and string literals.
  static let clean = "Clean"
}

extension FixtureCodeForm {
  /// Finds the start of each use of a form in a fixture directory, with the
  /// scan of the suite.
  ///
  /// - Parameters:
  ///   - form: The form to find.
  ///   - directory: The fixture directory, relative to ``fixtures``.
  /// - Returns: `<file>:<line>` for each use, with the file relative to
  ///   ``fixtures``.
  /// - Throws: The error of ``CodeScan/uses(of:inSwiftFilesBelow:relativeTo:)``.
  static func fixtureUses(of form: Self, in directory: String) throws -> [String] {
    let root = try fixtures
    return try scan.uses(of: form.pattern, inSwiftFilesBelow: root.appending(path: directory), relativeTo: root)
  }

  /// Expects that the scan finds no use of the form in the clean fixture
  /// directory, where the form is only in comments and string literals.
  ///
  /// - Parameter sourceLocation: The place of the test, for the report of a
  ///   failure.
  /// - Throws: The error of ``fixtureUses(of:in:)``.
  func expectNoUseInTheCleanFixture(sourceLocation: SourceLocation = #_sourceLocation) throws {
    let found = try Self.fixtureUses(of: self, in: CodeFormFixtures.clean)

    #expect(found.isEmpty, "\(found)", sourceLocation: sourceLocation)
  }
}
