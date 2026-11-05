import Foundation
import Testing

@testable import AgentViewKit

/// A copy of the bundled template folder in a temporary folder, with one
/// template edited.
///
/// A test renders a site from the copy to show that the output comes from
/// the template file: an edit of the file changes the output, and no code
/// changes.
struct TemplateFolderCopy {
  /// The temporary folder of the copy.
  let folder: URL

  /// The templates of the copy.
  var templates: TextTemplates { TextTemplates(folder: folder) }

  /// Copies the bundled template folder, and replaces a text in one of its
  /// templates.
  ///
  /// - Parameters:
  ///   - template: The template to edit.
  ///   - original: The text to replace. It must be in the template.
  ///   - replacement: The new text.
  /// - Throws: The error of the copy, or of the read or the write of the
  ///   template.
  init(editing template: TextTemplate, replacing original: String, with replacement: String) throws {
    let bundled = try #require(TextTemplates.bundled.folder)
    folder = FileManager.default.temporaryDirectory.appending(path: "TextTemplates-\(UUID().uuidString)")
    try FileManager.default.copyItem(at: bundled, to: folder)
    let file = folder.appending(path: template.fileName)
    let text = try String(contentsOf: file, encoding: .utf8)
    try #require(text.contains(original))
    try text.replacingOccurrences(of: original, with: replacement).write(to: file, atomically: true, encoding: .utf8)
  }

  /// Deletes the temporary folder.
  func remove() {
    try? FileManager.default.removeItem(at: folder)
  }
}
