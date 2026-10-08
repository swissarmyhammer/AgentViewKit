import Foundation
import PackageFileSupport
import Testing

/// Holds the documents in step with the ACP client kit scope
/// (`Docs/decisions/acp-client-kit.md`).
///
/// The record `acp-client-kit.md` gives the scope and the binding rule. The
/// dependency record lists only the direct dependencies of the kit. Each
/// record that the new scope replaces has one line that points to the new
/// record. `plan.md`, `README.md` and each current record name no removed part
/// of the kit. No file cites the deleted update plan.
@Suite struct DecisionRecordTests {
  /// The record of the scope, relative to the package root.
  static let clientKitRecordPath = "Docs/decisions/acp-client-kit.md"

  /// The title line of the scope record.
  static let clientKitTitle = "# AgentViewKit is an ACP client kit"

  /// The dependency record, relative to the package root.
  static let dependenciesRecordPath = "Docs/decisions/dependencies.md"

  /// The header row of the package table of the dependency record.
  static let dependencyTableHeader = "| Package | URL | Requirement | Products |"

  /// The package identity of each direct dependency of the kit.
  static let directDependencies: Set<String> = [
    "textual", "swiftui-math", "EditorKit", "FoundationModelsACP", "FoundationModelsACPClient",
  ]

  /// The packages that are not direct dependencies of the kit now.
  /// FoundationModelsExtras stays in the package graph only through
  /// FoundationModelsACPClient.
  static let removedDependencies = ["FoundationModelsRouter", "FoundationModelsExtras"]

  /// The line that marks a record as not current.
  static let notCurrentLine = "Not current. See `Docs/decisions/acp-client-kit.md`."

  /// The records that the scope of the ACP client kit replaces.
  static let notCurrentRecordPaths = [
    "Docs/decisions/subagent-source.md",
    "Docs/decisions/checkpoints.md",
    "Docs/decisions/usage-model.md",
    "Docs/decisions/branches.md",
    "Docs/decisions/compaction-ux.md",
    "Docs/decisions/required-thread-actions.md",
  ]

  /// The heading of the section of the scope record that names the host
  /// hooks.
  static let hostHooksHeading = "## Host hooks"

  /// The environment values that are the only host hooks of the kit. Each
  /// view binds to the client models, and the host gives only these.
  static let hostHooks = ["terminalAuthRunner", "agentReconnect"]

  /// The attachment type record, relative to the package root.
  static let attachmentTypesRecordPath = "Docs/decisions/attachment-types.md"

  /// The header row of the renderer table of the attachment type record.
  static let attachmentTableHeader = "| UTType | source support | default renderer |"

  /// The name of the removed source that no attachment row can name.
  static let removedSource = "Router"

  /// The heading of the section of the scope record that gives the binding
  /// rule of the views.
  static let bindingRuleHeading = "## Binding rule"

  /// The directory of the decision records, relative to the package root.
  static let decisionsPath = "Docs/decisions"

  /// The file extension of a decision record.
  static let recordExtension = "md"

  /// The documents that describe the kit as it is now, other than the
  /// current decision records.
  static let documentPaths = ["plan.md", "README.md"]

  /// The removed parts of the kit that no current document names as a word:
  /// the kit session model, the two removed targets, the kit turn grouping
  /// and the kit stream copy. The views bind to the client models directly.
  static let removedPartNames = [
    "AgentThread", "AgentViewKitRouter", "AgentViewKitFoundationModels", "TurnSummary", "StreamingMessage",
  ]

  /// The update plan that the documents task deleted. Its content is now in
  /// `plan.md` §3 and in the decision records.
  static let updatePlanPath = "update.md"

  /// The directories whose Swift files cite no deleted update plan.
  ///
  /// `Tests/PackageStructureTests` is not in the list, because this suite
  /// names the file in ``updatePlanPath``.
  static let updatePlanScanDirectories = RemovedVocabularyTests.swiftPaths + ["Benchmarks/Benchmarks"]

  /// The text files other than the documents and the records that cite no
  /// deleted update plan: the manifests, the scripts and the benchmark
  /// README.
  static let updatePlanScanFiles = [
    "Package.swift", "Benchmarks/Package.swift", "Benchmarks/README.md", "Scripts/check-benchmarks.sh",
    "Scripts/check-readme.sh", "Scripts/extract-readme-snippets.sh", "Scripts/test-examples.sh",
  ]

  /// The path of each decision record, relative to the package root, in name
  /// order.
  ///
  /// - Returns: The paths of the Markdown files in ``decisionsPath``.
  /// - Throws: The error of the read when the directory cannot be read.
  static func recordPaths() throws -> [String] {
    try FileManager.default.contentsOfDirectory(atPath: PackageFiles.file(decisionsPath).path(percentEncoded: false))
      .filter { $0.hasSuffix(".\(recordExtension)") }
      .sorted()
      .map { "\(decisionsPath)/\($0)" }
  }

  /// Tells whether a record is marked as not current.
  ///
  /// - Parameter path: The path of the record, relative to the package root.
  /// - Returns: `true` when a line of the record is ``notCurrentLine``.
  /// - Throws: The error of the read when the record cannot be read.
  static func isNotCurrent(_ path: String) throws -> Bool {
    try PackageFiles.text(of: path).split(separator: "\n").contains { $0 == notCurrentLine }
  }

  /// The documents that describe the kit as it is now: ``documentPaths`` and
  /// each decision record that is not marked as not current.
  ///
  /// - Returns: The paths, relative to the package root.
  /// - Throws: The error of the read when a record cannot be read.
  static func currentDocumentPaths() throws -> [String] {
    documentPaths + (try recordPaths().filter { !(try isNotCurrent($0)) })
  }

  /// The package identity in each row of the dependency table.
  ///
  /// - Returns: The first cell of each row, in file order.
  /// - Throws: The read error, or ``MarkdownTable/MissingTable`` when the
  ///   record has no package table.
  static func dependencyPackages() throws -> [String] {
    let text = try PackageFiles.text(of: dependenciesRecordPath)
    return try MarkdownTable.rows(in: text, header: dependencyTableHeader).map { $0.first ?? "" }
  }

  @Test func theClientKitRecordHasItsTitle() throws {
    let lines = try PackageFiles.text(of: Self.clientKitRecordPath).split(separator: "\n")

    #expect(lines.first.map(String.init) == Self.clientKitTitle)
  }

  @Test func theClientKitRecordNamesEachHostHook() throws {
    let text = try PackageFiles.text(of: Self.clientKitRecordPath)
    let section = try #require(
      text.components(separatedBy: "\n\(Self.hostHooksHeading)\n").dropFirst().first?
        .components(separatedBy: "\n## ").first)

    for hook in Self.hostHooks {
      #expect(section.contains("`\(hook)`"), "The host hook section does not name \(hook).")
    }
  }

  @Test(arguments: removedDependencies)
  func theDependencyTableHasNoRowFor(package: String) throws {
    #expect(!(try Self.dependencyPackages()).contains(package))
  }

  @Test func theDependencyTableListsEachDirectDependency() throws {
    #expect(Set(try Self.dependencyPackages()) == Self.directDependencies)
  }

  @Test(arguments: notCurrentRecordPaths)
  func theOldRecordHasTheNotCurrentLine(path: String) throws {
    #expect(try Self.isNotCurrent(path), "\(path) has no line \"\(Self.notCurrentLine)\"")
  }

  @Test func theAttachmentTableNamesNoRouterSource() throws {
    let text = try PackageFiles.text(of: Self.attachmentTypesRecordPath)
    let rows = try MarkdownTable.rows(in: text, header: Self.attachmentTableHeader)

    #expect(!rows.isEmpty)
    #expect(rows.allSatisfy { row in !row.contains { $0.contains(Self.removedSource) } })
  }

  @Test func theClientKitRecordHasTheBindingRuleSection() throws {
    let lines = try PackageFiles.text(of: Self.clientKitRecordPath).split(separator: "\n")

    #expect(lines.contains { $0 == Self.bindingRuleHeading })
  }

  @Test func theCurrentDocumentsIncludeTheScopeRecordAndSkipTheOldRecords() throws {
    let paths = try Self.currentDocumentPaths()

    #expect(paths.contains(Self.clientKitRecordPath))
    #expect(Set(paths).isDisjoint(with: Self.notCurrentRecordPaths), "\(paths)")
    #expect(Set(Self.documentPaths).isSubset(of: paths))
  }

  @Test func noCurrentDocumentNamesARemovedPart() throws {
    let found = try Self.currentDocumentPaths().flatMap { path in
      try RemovedVocabularyTests.uses(of: Self.removedPartNames, inFile: path)
    }

    #expect(found.isEmpty, "\(found)")
  }

  @Test func theUpdatePlanIsDeleted() throws {
    let path = try PackageFiles.file(Self.updatePlanPath).path(percentEncoded: false)

    #expect(!FileManager.default.fileExists(atPath: path))
  }

  @Test func noFileCitesTheDeletedUpdatePlan() throws {
    let textFiles = try Self.updatePlanScanFiles + Self.recordPaths() + Self.documentPaths
    let found =
      try RemovedVocabularyTests.uses(of: [Self.updatePlanPath], below: Self.updatePlanScanDirectories)
      + textFiles.flatMap { try RemovedVocabularyTests.uses(of: [Self.updatePlanPath], inFile: $0) }

    #expect(found.isEmpty, "\(found)")
  }
}
