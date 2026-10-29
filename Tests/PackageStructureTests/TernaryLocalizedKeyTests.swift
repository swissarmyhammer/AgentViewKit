import EditorTestSupport
import Foundation
import RegexBuilder
import Testing

/// Holds the kit library free of ternary string literal keys.
///
/// SwiftUI reads `Button(isOn ? "Hide" : "Show")` as a `LocalizedStringKey`.
/// A `LocalizedStringKey` looks up the main bundle of the host app, not the
/// bundle of the kit, so the String Catalog of the kit does not translate the
/// text. Each branch must be a `String(localized:bundle: .module)` call. The
/// scan reads each Swift file of the kit as text, one line at a time.
@Suite struct TernaryLocalizedKeyTests {
  /// The pattern that finds a ternary string literal key: a SwiftUI call
  /// that takes a localized key, then a condition, then `?` and a string
  /// literal. The `?` must follow a space, so an optional chain and the
  /// `??` operator do not match.
  static var ternaryKeyPattern: some RegexComponent {
    Regex {
      Anchor.wordBoundary
      ChoiceOf {
        "Text("
        "Button("
        "Label("
        "Toggle("
        "TextField("
        "SecureField("
        "Picker("
        "Section("
        "Menu("
        "Link("
        "LabeledContent("
        "ContentUnavailableView("
        "DisclosureGroup("
        "Stepper("
        "DatePicker("
        "GroupBox("
        "navigationTitle("
        "help("
        "accessibilityLabel("
        "accessibilityHint("
        "accessibilityValue("
        "alert("
        "confirmationDialog("
      }
      ZeroOrMore(CharacterClass.anyOf("\"").inverted)
      One(.whitespace)
      "?"
      ZeroOrMore(.whitespace)
      "\""
    }
  }

  /// Finds the lines of a source that give a ternary string literal key.
  ///
  /// - Parameter line: One line of a Swift file.
  /// - Returns: `<file>:<line>` when the line gives a ternary string literal
  ///   key, or no result.
  static func ternaryKeyUses(on line: SourceLine) -> [String] {
    line.text.contains(ternaryKeyPattern) ? ["\(line.file):\(line.number)"] : []
  }

  @Test func theScanFindsATernaryOfStringLiteralsInALocalizedKey() {
    let source = """
      Button(isOn ? "Hide" : "Show", systemImage: symbol) {
      Text(flag ? "On" : "Off")
      .help(isOn ? "Hide" : "Show")
      Text(name ?? "Untitled")
      Button(isOn ? Self.hideTitle : Self.showTitle) {
      .accessibilityValue(item?.detail ?? "")
      let separator = isLast ? "" : ", "
      """

    let found = SourceLineScanner.matches(
      inSource: source, file: "A.swift", match: Self.ternaryKeyUses(on:))

    #expect(found == ["A.swift:1", "A.swift:2", "A.swift:3"])
  }

  @Test func noKitViewGivesATernaryStringLiteralKey() throws {
    let found = try KitSourceFiles.scanLibraryFiles { directory in
      try SourceLineScanner.matches(
        inSwiftFilesBelow: directory, relativeTo: PackageFiles().root, match: Self.ternaryKeyUses(on:))
    }

    #expect(found.isEmpty, "Give each branch as String(localized:bundle: .module): \(found)")
  }
}
