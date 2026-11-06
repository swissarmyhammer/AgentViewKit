import EditorInspector
import EditorSwiftUI
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// Checks the path rows of the inspections of the client models, and the
/// URL of each path, with no view.
@Suite @MainActor struct InspectionPathTests {
  /// The path of the folder of the tests.
  private static let folder = "/tmp/Project"

  /// The path of the file of the tests.
  private static let file = "/tmp/Project/Package.swift"

  /// The line of the location of the tests.
  private static let line: UInt32 = 12

  /// The kind of the field with `key` in the group with `group` of
  /// `inspection`, or `nil` when it has no such field.
  ///
  /// - Parameters:
  ///   - key: The field part of the scheme id of the row.
  ///   - group: The group part of the scheme id of the row.
  ///   - inspection: The inspection of a model.
  /// - Returns: The kind of the row.
  private static func kind<Object>(
    of key: String, in group: String, of inspection: Inspection<Object>
  ) -> InspectorFieldKind? {
    inspection.groups.first { $0.key == group }?.fields.first { $0.key == key }?.kind
  }

  @Test func theWorkingDirectoryOfATerminalIsAPathRow() {
    #expect(Self.kind(of: "working-directory", in: "terminal", of: TerminalEntry.inspection) == .path)
  }

  @Test func theWorkingDirectoryOfASessionIsAPathRow() {
    #expect(Self.kind(of: "working-directory", in: "session", of: SessionModel.inspection) == .path)
  }

  @Test func theLocationsOfAToolCallAreAPathsRow() {
    #expect(Self.kind(of: "locations", in: "tool-call", of: ToolCallEntry.inspection) == .paths)
  }

  @Test func theAdditionalDirectoriesOfASessionAreAPathsRow() {
    #expect(Self.kind(of: "additional-directories", in: "session", of: SessionModel.inspection) == .paths)
  }

  @Test func aFileHasTheDocumentSymbol() {
    let url = InspectionPath.file(AbsolutePath(rawValue: Self.file))

    #expect(EditorSymbol.FileKind(location: url) == .document)
  }

  @Test func aFileKeepsItsPath() {
    let url = InspectionPath.file(AbsolutePath(rawValue: Self.file))

    #expect(url.path(percentEncoded: false) == Self.file)
  }

  @Test func aLocationIsAtItsFile() {
    let location = ToolCallLocation(path: AbsolutePath(rawValue: Self.file))

    #expect(InspectionPath.location(location).url == InspectionPath.file(location.path))
  }

  @Test func aLocationWithALineKeepsItsLine() {
    let location = ToolCallLocation(path: AbsolutePath(rawValue: Self.file), line: LineNumber(rawValue: Self.line))

    #expect(InspectionPath.location(location).line == Int(Self.line))
  }

  @Test func aLocationWithNoLineHasNoLine() {
    let location = ToolCallLocation(path: AbsolutePath(rawValue: Self.file))

    #expect(InspectionPath.location(location).line == nil)
  }

  @Test func aFolderHasTheFolderSymbol() {
    let url = InspectionPath.folder(AbsolutePath(rawValue: Self.folder))

    #expect(EditorSymbol.FileKind(location: url) == .folder)
  }

  @Test func aFolderKeepsItsPath() {
    let url = InspectionPath.folder(AbsolutePath(rawValue: Self.folder))

    #expect(url.path(percentEncoded: false) == Self.folder + "/")
  }
}
