import PackageFileSupport
import Testing

/// Holds the decision records in step with the ACP client kit scope
/// (update.md §10, items 2, 4 and 7).
///
/// The record `acp-client-kit.md` gives the scope. The dependency record
/// lists only the direct dependencies of the kit. Each record that the new
/// scope replaces has one line that points to the new record.
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
    let lines = try PackageFiles.text(of: path).split(separator: "\n").map(String.init)

    #expect(lines.contains(Self.notCurrentLine), "\(path) has no line \"\(Self.notCurrentLine)\"")
  }

  @Test func theAttachmentTableNamesNoRouterSource() throws {
    let text = try PackageFiles.text(of: Self.attachmentTypesRecordPath)
    let rows = try MarkdownTable.rows(in: text, header: Self.attachmentTableHeader)

    #expect(!rows.isEmpty)
    #expect(rows.allSatisfy { row in !row.contains { $0.contains(Self.removedSource) } })
  }
}
