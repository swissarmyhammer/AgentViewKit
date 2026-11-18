import OSLog
import SwiftUI
import UniformTypeIdentifiers

/// Writes the result of a file exporter to the log.
///
/// The Save command of an attachment scope and ``MessageActions`` save files
/// through `fileExporter`, and both record a failed save in the same way.
enum FileExportLog {
  /// Writes an error entry when the save failed. A save that succeeded
  /// writes nothing.
  ///
  /// - Parameters:
  ///   - result: The result of the file exporter.
  ///   - name: The name of the saved file.
  ///   - logger: The log of the view that saved the file.
  static func record(_ result: Result<URL, any Error>, of name: String, to logger: Logger) {
    guard case .failure(let error) = result else { return }
    logger.error("The save of \(name, privacy: .private) failed: \(error)")
  }
}

/// A document that the file exporter writes and never reads.
///
/// A conforming type gives only ``FileDocument/fileWrapper(configuration:)``.
/// The read initializer always fails.
nonisolated protocol ExportOnlyDocument: FileDocument {}

nonisolated extension ExportOnlyDocument {
  /// The exporter never reads a document, so this initializer always
  /// fails.
  ///
  /// - Parameter configuration: The read configuration.
  /// - Throws: `CocoaError.featureUnsupported`.
  init(configuration: ReadConfiguration) throws {
    throw CocoaError(.featureUnsupported)
  }
}

/// Shows the save panel of a document that waits, through the `fileExporter`
/// of SwiftUI.
///
/// The Save command of an attachment scope and Export as Markdown… show
/// their save panels through this modifier, so that the two panels open,
/// close and log in the same way:
///
/// - The panel shows while `document` is not `nil`.
/// - The panel calls `close` when it closes, with a save or with a cancel.
/// - A save that fails goes to the log through ``FileExportLog``.
///
/// The caller reads the document from its observable presenter in its own
/// body, so that a new value evaluates the body again, and gives the value
/// to this modifier. A caller adds what only it needs after the modifier,
/// such as a default folder.
struct FileExportPresentation<Document: FileDocument>: ViewModifier {
  /// The document to save, or `nil` when no save panel shows.
  let document: Document?

  /// The type of the saved file.
  let contentType: UTType

  /// The default name of the file, or `nil` for the name of the system.
  let defaultFilename: String?

  /// Clears the document of the presenter after the panel closes.
  let close: () -> Void

  /// The log of a save that fails.
  let logger: Logger

  func body(content: Content) -> some View {
    content
      .fileExporter(
        isPresented: Binding(get: { document != nil }, set: { if !$0 { close() } }),
        document: document,
        contentType: contentType,
        defaultFilename: defaultFilename,
        onCompletion: { FileExportLog.record($0, of: defaultFilename ?? "", to: logger) }
      )
  }
}
