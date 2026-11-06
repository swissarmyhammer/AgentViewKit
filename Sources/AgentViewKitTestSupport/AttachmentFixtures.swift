import AgentViewKit
import EditorCommands
import Foundation

/// The attachment fixtures that the attachment command tests and the hosted
/// attachment tests share: the text of each temporary file, the attachment of
/// a written file, and the ids of the attachment verbs.
public enum AttachmentFixtures {
  /// The text that each temporary file holds.
  public static let fileText = "let answer = 42\n"

  /// Writes a file and makes its attachment.
  ///
  /// - Parameters:
  ///   - name: The file name, with its extension.
  ///   - directory: The directory of the file.
  /// - Returns: The attachment of the file.
  /// - Throws: The error of the write.
  public static func attachment(named name: String, in directory: TemporaryFolder) throws
    -> AgentViewKit.Attachment
  {
    AgentViewKit.Attachment(url: try directory.write(name, contents: Data(fileText.utf8)))
  }

  /// The ids of each attachment verb, in the order of the verbs.
  ///
  /// This is the one definition of the verb ids for the attachment tests.
  public static var verbIDs: [CommandID] {
    AgentAttachmentVerb.allCases.map(\.id)
  }

  /// The calls that a recording service gets from a run of `verb` on each
  /// of `files`, in order: one call for each file.
  ///
  /// - Parameters:
  ///   - verb: The verb of the run.
  ///   - files: The files of the run, in order.
  /// - Returns: The calls.
  public static func calls(
    of verb: AgentAttachmentVerb, on files: [AgentViewKit.Attachment]
  ) -> [RecordingAttachmentFileService.Call] {
    files.map { .init(verb: verb, attachment: $0) }
  }
}

/// Temporary files of several types for the tests of a selection of files:
/// the folder, and the attachment of each file, in the order of their names.
public struct AttachmentFileSet {
  /// The names of the three files of a selection test, each of another
  /// type, in transcript order.
  public static let selectionNames = ["first.bin", "second.txt", "third.swift"]

  /// The folder of the files.
  let directory: TemporaryFolder

  /// The attachments of the files, in the order of their names.
  public let files: [AgentViewKit.Attachment]

  /// Writes one file for each of `names` in a new temporary folder.
  ///
  /// - Parameter names: The file names, with their extensions. The default
  ///   is ``selectionNames``.
  /// - Throws: The error of a write.
  public init(named names: [String] = selectionNames) throws {
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    self.directory = directory
    files = try names.map { try AttachmentFixtures.attachment(named: $0, in: directory) }
  }

  /// Removes the folder and its files.
  public func remove() {
    directory.remove()
  }
}
