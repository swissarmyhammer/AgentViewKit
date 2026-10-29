import EditorTestSupport
import Foundation
import Testing

/// Holds **one announcement path** (EditorKit ^gfv7042).
///
/// `VoiceOverAnnouncer` of the EditorKit `EditorCommandsUI` target is the one
/// place that posts a spoken announcement to the accessibility system. Each
/// view of the kit speaks through the `Announcer` that it reads from the
/// environment value `announcer`, and `.commandSystem(_:)` gives the same
/// announcer to jump mode. Thus a test records each announcement, and a host
/// sets the announcer in one place.
///
/// The guard scans the source lines of the EditorKit `SourceScanning` helpers
/// and finds each token as a whole word. No code line of the kit, of the demo
/// app, of the README snippets, or of their tests may post an announcement
/// itself or name `VoiceOverAnnouncer`. An injection point, a line that sets
/// the environment value `announcer`, can name `VoiceOverAnnouncer`. A `//`
/// comment line is not code, so the scan skips it. The package builds for
/// macOS only, so the scan does not look for the UIKit post.
@Suite struct AnnouncementPathScanTests {
  /// This package, found from this file with EditorKit's `PackageFiles`.
  static let package = PackageFiles()

  /// The directories that the scan reads, relative to the package root.
  static let scannedPaths = [
    "Sources", "Examples", "Tests/AgentViewKitTests", "Tests/AgentViewKitStyleTests", IntegrationPackage.testsPath,
  ]

  /// The tokens of a direct announcement: the SwiftUI post, the AppKit
  /// notification, and the announcer of EditorKit that posts them.
  static let announcementTokens = [
    "AccessibilityNotification.Announcement", "announcementRequested", "VoiceOverAnnouncer",
  ]

  @Test func noCodeOutsideAnInjectionPointPostsAnAnnouncement() throws {
    let found = try Self.violations(in: Self.scannedFiles())

    #expect(found.isEmpty, "Announce through the environment value `announcer`. Found:\n\(found.joined(separator: "\n"))")
  }

  @Test(arguments: scannedPaths)
  func theScanReadsTheSwiftFilesOfEachDirectory(_ path: String) throws {
    // A moved directory gives an empty scan, and an empty scan finds no
    // violation.
    #expect(!swiftFiles(under: try Self.package.file(path)).isEmpty)
  }

  @Test(
    arguments: [
      ("AccessibilityNotification.Announcement(text).post()", true),
      ("NSAccessibility.post(element: app, notification: .announcementRequested, userInfo: info)", true),
      ("let speaker = VoiceOverAnnouncer()", true),
      ("speaker.announce(message, priority: .high); _ = VoiceOverAnnouncer.self", true),
      (".environment(\\.announcer, VoiceOverAnnouncer())", false),
      ("announcer.announce(message, priority: .high)", false),
      ("@Environment(\\.announcer) private var announcer", false),
      ("// VoiceOverAnnouncer posts the announcement.", false),
      ("let record = RecordingAnnouncer.Announcement(message: message, priority: .high)", false),
      ("let notice = MyAccessibilityNotification.Announcements()", false),
    ]
  )
  func theScanFindsADirectAnnouncementOutsideAnInjectionPoint(_ line: String, _ isViolation: Bool) throws {
    let file = FileManager.default.temporaryDirectory
      .appending(path: "AnnouncementPathScan-\(UUID().uuidString).swift")
    try line.write(to: file, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: file) }

    let found = try Self.violations(in: [file])

    #expect(found.isEmpty == !isViolation, "\(found)")
  }

  // MARK: - Scanning

  /// The Swift files below each directory of ``scannedPaths``.
  ///
  /// - Returns: The files.
  /// - Throws: ``PackageFiles/PathOutsideRoot`` when a path is not in the
  ///   package.
  static func scannedFiles() throws -> [URL] {
    try scannedPaths.flatMap { swiftFiles(under: try package.file($0)) }
  }

  /// The pattern of a line that sets the environment value `announcer`.
  ///
  /// A `Regex` is not `Sendable`, so each call makes the value again.
  ///
  /// - Returns: The pattern.
  static func injectionPoint() -> Regex<Substring> {
    #/\.environment\(\s*\\\.announcer\s*,/#
  }

  /// Whether the scan reads `line`: a code line that is not an injection
  /// point.
  ///
  /// - Parameter line: One line of a source file.
  /// - Returns: `true` when the line can hold a violation.
  static func isScannedLine(_ line: Substring) -> Bool {
    isSourceCodeLine(line) && !line.contains(injectionPoint())
  }

  /// One violation for each scanned line of `files` and each token of
  /// ``announcementTokens`` that the line holds as a whole word.
  ///
  /// A `Regex` is slow on each of the many lines of the package, so a line
  /// that does not hold the token as text is not read with the pattern.
  ///
  /// - Parameter files: The files to read.
  /// - Returns: The violations, as `"<path>:<line>: <text>"`, in token order.
  /// - Throws: The error of a read when a file cannot be read.
  static func violations(in files: [URL]) throws -> [String] {
    try announcementTokens.flatMap { token in
      try sourceScanViolations(
        in: files, matching: Regex(WordPattern.wholeWord(token)),
        where: { $0.contains(token) && isScannedLine($0) }, format: packageScanViolation)
    }
  }

  /// One hit of the scan as `"<path>:<line>: <text>"`, with the path relative
  /// to the package root.
  ///
  /// - Parameters:
  ///   - file: The file that holds the hit.
  ///   - index: The zero-based line index of the hit.
  ///   - line: The line that holds the hit.
  /// - Returns: The one-line violation text.
  static func packageScanViolation(file: URL, index: Int, line: Substring) -> String {
    let path = (try? package.relativePath(of: file)) ?? file.path
    return "\(path):\(index + 1): \(line.trimmingCharacters(in: .whitespaces))"
  }
}
