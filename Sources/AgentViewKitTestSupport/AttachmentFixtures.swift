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
  public static func attachment(named name: String, in directory: TemporaryDirectory) throws
    -> AgentViewKit.Attachment
  {
    AgentViewKit.Attachment(url: try directory.file(named: name, contents: Data(fileText.utf8)))
  }

  /// The ids of each attachment verb, in the order of the verbs.
  ///
  /// This is the one definition of the verb ids for the attachment tests.
  public static var verbIDs: [CommandID] {
    AgentAttachmentVerb.allCases.map(\.id)
  }
}
