import EditorTestSupport
import Foundation
import Testing

/// A name that a test uses to show a view with Reduce Transparency or
/// Increase Contrast on: an environment key of SwiftUI or a high-contrast
/// appearance of AppKit.
///
/// The tests and the snapshots are light and dark only (EditorKit `style.md`
/// rule 9, the user decision of 2026-10-28). Each raw value is the name as a
/// whole word.
enum SystemSettingName: String, CaseIterable, CustomTestStringConvertible, Sendable {
  /// The private SwiftUI key that sets Reduce Transparency.
  case privateReduceTransparencyKey = "_accessibilityReduceTransparency"

  /// The SwiftUI key of Reduce Transparency.
  case reduceTransparencyKey = "accessibilityReduceTransparency"

  /// The private SwiftUI key that sets Increase Contrast.
  case privateContrastKey = "_colorSchemeContrast"

  /// The SwiftUI key of Increase Contrast.
  case contrastKey = "colorSchemeContrast"

  /// The light appearance of AppKit with Increase Contrast.
  case highContrastAqua = "accessibilityHighContrastAqua"

  /// The dark appearance of AppKit with Increase Contrast.
  case highContrastDarkAqua = "accessibilityHighContrastDarkAqua"

  /// The vibrant light appearance of AppKit with Increase Contrast.
  case highContrastVibrantLight = "accessibilityHighContrastVibrantLight"

  /// The vibrant dark appearance of AppKit with Increase Contrast.
  case highContrastVibrantDark = "accessibilityHighContrastVibrantDark"

  var testDescription: String { rawValue }

  /// The pattern that finds the name as a whole word.
  var pattern: Regex<Substring> {
    WordPattern.wholeWord(rawValue)
  }
}

/// The data of ``LightAndDarkOnlyTests`` for the shared form checks.
extension SystemSettingName: SampledCodeForm {
  static var sampleLines: [(form: SystemSettingName, line: String)] { LightAndDarkOnlyTests.sampleLines }

  static var lookAlikeLines: [String] { LightAndDarkOnlyTests.lookAlikeLines }
}

/// Holds the tests and the snapshots to light and dark only (EditorKit
/// `style.md` rule 9).
///
/// No test and no demo source sets Reduce Transparency or Increase Contrast.
/// The scan reads each code line of the test sources and of the demo app with
/// the `SourceScanning` helpers of EditorKit `EditorTestSupport`, and fails
/// when a line names a ``SystemSettingName`` as a whole word. A `//` comment
/// line is not code.
@Suite struct LightAndDarkOnlyTests {
  /// This package, found from this file with EditorKit's `PackageFiles`.
  static let package = PackageFiles()

  /// The directories of the test sources and of the demo app, with each of
  /// its Swift folders, relative to the package root.
  static let scannedPaths = [
    "Tests", "Sources/AgentViewKitTestSupport", "Examples/ReadmeSnippets", "Examples/AgentViewKitDemo",
  ]

  /// This file, relative to the package root. It names each setting in its
  /// patterns and its sample lines, so the scan skips it.
  static let scanFile = "Tests/PackageStructureTests/LightAndDarkOnlyTests.swift"

  /// A sample line of each name.
  static let sampleLines: [(form: SystemSettingName, line: String)] = [
    (.privateReduceTransparencyKey, #".environment(\._accessibilityReduceTransparency, true)"#),
    (.reduceTransparencyKey, #"@Environment(\.accessibilityReduceTransparency) private var reduces"#),
    (.privateContrastKey, #".environment(\._colorSchemeContrast, .increased)"#),
    (.contrastKey, #"@Environment(\.colorSchemeContrast) private var contrast"#),
    (.highContrastAqua, "window.appearance = NSAppearance(named: .accessibilityHighContrastAqua)"),
    (.highContrastDarkAqua, "let names: [NSAppearance.Name] = [.accessibilityHighContrastDarkAqua]"),
    (.highContrastVibrantLight, "view.appearance = NSAppearance(named: .accessibilityHighContrastVibrantLight)"),
    (.highContrastVibrantDark, "view.appearance = NSAppearance(named: .accessibilityHighContrastVibrantDark)"),
  ]

  /// Lines that look like a setting, but set none.
  static let lookAlikeLines = [
    #".environment(\._accessibilityReduceMotion, true)"#,
    #".environment(\.colorScheme, .dark)"#,
    "window.appearance = NSAppearance(named: .darkAqua)",
    "let colorSchemeContrastRatio = 4.5",
  ]

  @Test func eachPatternFindsOnlyItsOwnName() {
    SystemSettingName.expectEachSampleFindsOnlyItsOwnForm()
  }

  @Test func noPatternFindsALookAlikeLine() {
    SystemSettingName.expectNoFormFindsALookAlikeLine()
  }

  @Test func theScanReadsTheTestAndDemoSources() throws {
    let files = try Self.scannedFiles()
    let demo = try Self.package.file("Examples/AgentViewKitDemo/AgentViewKitDemoFeature/GalleryLook.swift")
      .standardizedFileURL
    #expect(!files.isEmpty)
    #expect(files.contains { $0.standardizedFileURL == demo })
  }

  @Test(arguments: SystemSettingName.allCases)
  func noTestOrDemoSourceSetsReduceTransparencyOrIncreaseContrast(name: SystemSettingName) throws {
    let found = try sourceScanViolations(
      in: Self.scannedFiles(), matching: Regex<AnyRegexOutput>(name.pattern), where: isSourceCodeLine
    ) { file, index, _ in
      "\(Self.relativePath(of: file)):\(index + 1)"
    }

    #expect(
      found.isEmpty, "The tests and the demo are light and dark only (EditorKit style.md rule 9). \(name) is in: \(found)")
  }

  /// The Swift files below ``scannedPaths``, except ``scanFile``.
  ///
  /// - Returns: The file URLs.
  /// - Throws: ``PathOutsideRoot`` when a path leaves the package root.
  static func scannedFiles() throws -> [URL] {
    let skipped = try package.file(scanFile).standardizedFileURL
    return try scannedPaths.flatMap { path in
      try swiftFiles(under: package.file(path))
    }
    .filter { $0.standardizedFileURL != skipped }
  }

  /// The path of `file` relative to the package root, or its full path when
  /// it is not below the root.
  ///
  /// - Parameter file: A scanned file.
  /// - Returns: The path for the report of a hit.
  static func relativePath(of file: URL) -> String {
    (try? package.relativePath(of: file)) ?? file.path
  }
}
